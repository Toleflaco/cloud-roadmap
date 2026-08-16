# Sesión 11 — Remote state en S3 con locking nativo (parte 3 de la Sesión 5 oficial del roadmap)

**Fechas:** 15 agosto 2026 (tramo AM+PM) + 16 agosto 2026 (tramo B)
**Duración total:** ~3h30 repartidas en tres tramos:
- Tramo AM (15 ago): 09:30 – 11:30 (~2h, ventana ancha, cierre parcial por decisión de tiempo)
- Tramo PM (15 ago): 17:00 – 18:30 (~1h30, cierre por descubrimiento no planificado de `dynamodb_table` deprecated)
- Tramo B (16 ago): 07:00 – 08:15 (~1h15, cierre completo)
**Estado:** Completada. Migración de backend local a backend S3 con locking nativo (`use_lockfile`) validada empíricamente end-to-end. Descubrimiento no planificado durante la ejecución: `dynamodb_table` deprecated desde Terraform 1.11 en favor de S3 conditional writes. Ciclo completo `init → migrate-state → reconfigure → plan → apply → destroy` recorrido sobre backend remoto. Recursos AWS al cierre: idénticos al inicio salvo bucket S3 dedicado al state (vacío tras destroy).

## Objetivo pedagógico

Migrar el state file de Terraform del backend local (fichero en WSL) al backend S3 gestionado, activar mecanismo de locking para prevenir race conditions, y validar el ciclo apply+destroy completo sobre backend remoto. Cubrir siete bloques en secuencia:

1. Concepto de remote backend: cuatro problemas del backend local (divergencia, race condition, pérdida catastrófica, secretos en disco) y las cuatro features del backend S3 que los resuelven.
2. Creación del bucket S3 dedicado al state por consola (versioning + encryption + block public access + naming scope).
3. Creación de tabla DynamoDB para locking por consola (partition key `LockID`, on-demand, deletion protection).
4. Configuración del bloque `backend "s3"` en `versions.tf` (estructura HCL, atributos requeridos, tipado booleano).
5. `terraform init -migrate-state` — migración del state local al remoto, primer contacto con este flujo, verificación IAM previa.
6. Descubrimiento en ejecución: warning `dynamodb_table` deprecated → migración a `use_lockfile = true` con `init -reconfigure`.
7. Ciclo completo apply+destroy sobre backend remoto, verificación empírica del ciclo de vida del `.tflock` desde una segunda terminal en paralelo.

Sesión partida en tres tramos por dos razones distintas: el corte AM→PM del día 15 por respeto a la regla de 4h/día; el corte PM→B para digerir el descubrimiento no planificado de la deprecation con cabeza fresca al día siguiente.

## Bloque 1 — Concepto de remote backend

### Los cuatro problemas del backend local en equipo

Con backend local (fichero `terraform.tfstate` en disco del que ejecuta Terraform), un equipo de dos o más personas se encuentra con cuatro problemas:

1. **Divergencia de state**: cada máquina tiene su propia copia del state. Persona A crea un bucket → registrado en su state. Persona B ejecuta `plan` sin ese state → propone crear el mismo bucket → AWS rechaza por nombre duplicado o duplica infra silenciosamente.

2. **Race condition en apply simultáneo**: dos procesos leyendo y escribiendo el mismo state en paralelo lo corrompen. Aunque el state fuera compartido, sin mecanismo de exclusión mutua, ambos calcularían delta contra la misma foto y aplicarían cambios superpuestos.

3. **Pérdida catastrófica**: portátil roto = state perdido. HCL sobrevive en git, pero el state no. Terraform propondría crear todo desde cero. Recuperación: `terraform import` recurso a recurso, manualmente.

4. **Secretos en claro en disco**: `terraform.tfstate` guarda passwords de RDS, connection strings, tokens sin cifrar. Cualquier backup, robo o repositorio accidental compromete todos los secretos.

### Cómo el backend S3 resuelve los cuatro problemas

| Problema | Feature del backend S3 |
|---|---|
| Divergencia | State único en S3, todas las máquinas leen y escriben ahí |
| Race condition | Locking (originalmente DynamoDB, ahora S3 native con `use_lockfile`) |
| Pérdida | Versioning del bucket (versiones históricas recuperables) |
| Secretos en claro | Server-Side Encryption (SSE-S3 con AES256) |

### Distinción crítica: state compartido vs locking

Confusión inicial cazada durante la sesión: el bucket S3 y el mecanismo de locking son **dos servicios independientes cooperando**, no una feature integrada del backend S3.

- **S3** = dónde vive el state (fuente de verdad única).
- **Semáforo externo** (DynamoDB o S3 mismo con conditional writes) = coordina quién puede tocarlo en cada momento.

Necesarios ambos: sin state compartido no hay divergencia resuelta; sin locking, dos procesos podrían escribir el state compartido a la vez y corromperlo.

### Mecánica del lock (versión moderna con `use_lockfile`)

Ciclo completo desmenuzado:

1. Terraform ejecuta `apply` (o `plan`, `destroy`, `refresh`, `import`, etc.).
2. **Antes de leer el state**, Terraform intenta crear un objeto `<state-key>.tflock` en el bucket S3 con `PutObject` + header `If-None-Match: *`.
3. Si S3 responde éxito → el objeto acaba de nacer → Terraform tiene el lock.
4. Si S3 responde `PreconditionFailed` → el objeto ya existía → otro proceso tiene el lock → Terraform aborta con `Error acquiring the state lock`.
5. Terraform lee state, calcula plan, muestra prompt, espera `yes`, aplica cambios, escribe state actualizado.
6. Terraform ejecuta `DeleteObject` sobre `<state-key>.tflock` → lock liberado.
7. Fin del ciclo. Bucket queda solo con state, sin `.tflock`.

El `.tflock` contiene un JSON con metadata operacional: ID del lock, operación, usuario, hostname, versión de Terraform, timestamp, path del state protegido. Es a la vez el semáforo (por existir) y el aviso (por su contenido).

## Bloque 2 — Bucket S3 dedicado al state

### Decisión: bucket dedicado vs reutilizar bucket existente

Descartado meter el state en `toleflaco-task-manager-uploads-2026` (el bucket de uploads del task-manager) por dos razones:

1. **Higiene arquitectónica (separation of concerns)**: los dos buckets tienen requisitos opuestos en versioning, encryption, lifecycle, retention, monitorización, permisos. Compartirlos forzaría políticas mezcladas y por tanto rotas.

2. **Blast radius**: cualquier operación legítima sobre el bucket de uploads (limpieza con `aws s3 rm --recursive`, cambio de lifecycle, migración de región) sería un riesgo para el state si vive dentro. El bucket también tendría permisos concedidos al rol EC2 (`s3:PutObject`, `s3:DeleteObject`) que técnicamente podrían tocar el state. Bucket dedicado = radio de impacto contenido.

### Decisión: naming scope

Nombre elegido: **`toleflaco-terraform-state-2026`**, no `toleflaco-task-manager-state-2026`.

Justificación: el bucket va a alojar state de todos los proyectos Terraform del cloud-roadmap (futuros microservicios, experimentos, etc.), no solo del task-manager. Meter "task-manager" en el nombre lo hace mentira desde el momento en que se añada un segundo proyecto. **Un bucket, un propósito, y el propósito es "state de Terraform" en general.**

### Configuración final del bucket

| Campo | Valor | Justificación |
|---|---|---|
| Nombre | `toleflaco-terraform-state-2026` | Namespace global de S3; propósito genérico |
| Región | `eu-west-1` (Ireland) | Coherente con el resto de infra |
| Object Ownership | ACLs disabled | Recomendación AWS moderna |
| Block Public Access | All blocked | State nunca es público |
| Versioning | Enable | Paracaídas contra corrupción o borrado del state |
| Encryption | SSE-S3 (AES256) | Suficiente para uso individual; SSE-KMS reservado para compliance |
| Object Lock | Disable | WORM bloquearía updates del state; imposible operar |

Tags aplicados: `Project: cloud-roadmap`, `Purpose: terraform-state-storage`, `ManagedBy: manual-bootstrap`. El tag `ManagedBy: manual-bootstrap` documenta que este recurso NO está gestionado por Terraform (problema del huevo y la gallina).

## Bloque 3 — Tabla DynamoDB para locking (creada y luego eliminada)

### Contexto de decisión

Al planificar la sesión, la doctrina mainstream para locking de state en backend S3 era una tabla DynamoDB externa como semáforo. Se creó la tabla siguiendo esa doctrina, con la configuración siguiente:

| Campo | Valor | Justificación |
|---|---|---|
| Table name | `terraform-state-lock` | Nombre corto (DynamoDB scoped a cuenta+región, sin necesidad de prefijos globales) |
| Partition key | `LockID` (String) | Convención obligatoria de Terraform, no elegible |
| Sort key | (vacío) | Cada state file tiene un solo lock o ninguno |
| Capacity mode | On-demand | Tráfico bajo esporádico (~30 requests/día); Provisioned costaría $3/mes fijos innecesarios |
| Encryption | Owned by DynamoDB | Sin secretos en la tabla, cifrado gratis suficiente |
| Deletion protection | Enabled | Safety net gratis contra borrado accidental |
| PITR | Disabled | Contenido efímero (locks), sin datos recuperables valiosos |

Tags: `Project: cloud-roadmap`, `Purpose: terraform-state-lock`, `ManagedBy: manual-bootstrap`.

### Vocabulario de scope de naming en AWS (fijado)

Distinción cazada en este bloque:

| Recurso | Scope del nombre |
|---|---|
| S3 bucket | Global (único mundialmente) |
| DynamoDB table | Cuenta + región |
| IAM user/role | Cuenta |
| EC2/VPC/SG | ID autogenerado, tag `Name` cosmético |
| RDS instance | Cuenta + región |

**Regla operativa**: naming pesado con prefijos discriminantes solo donde el scope global lo exige (S3). Para el resto, nombres cortos y descriptivos.

### Confusión Región vs Availability Zone corregida

Error inicial al crear el bucket: escribí `eu-west-1a` (una AZ) en lugar de `eu-west-1` (una región). Corrección conceptual:

- **Región** = área geográfica con múltiples data centers (`eu-west-1`, `us-east-1`).
- **Availability Zone (AZ)** = un data center o cluster de data centers dentro de una región (`eu-west-1a`, `eu-west-1b`, `eu-west-1c`).
- **S3 y DynamoDB son regionales**: no viven en una AZ específica; AWS replica internamente entre las 3 AZs de la región para durabilidad.
- **EC2 y EBS son zonales**: viven en una AZ concreta; muere la AZ, muere la instancia.
- **IAM, Route 53, CloudFront son globales**.

### Eliminación posterior de la tabla

Tras el descubrimiento del bloque 5 (deprecation de `dynamodb_table`), la tabla quedó huérfana sin propósito. Eliminada por consola AWS al cierre de S11-B: desactivar Deletion Protection → Delete → confirm. Coste mientras vivió: cero (On-demand sin requests).

## Bloque 4 — Bloque `backend "s3"` en `versions.tf`

### Cinco atributos del bloque

Estructura del bloque `backend "s3"` inicialmente configurada con DynamoDB:

```hcl
backend "s3" {
  bucket         = "toleflaco-terraform-state-2026"
  key            = "envs/dev/terraform.tfstate"
  region         = "eu-west-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

### Decisión de `key`

`key` = path completo al objeto donde vive el state dentro del bucket, incluyendo nombre de fichero. **No es una carpeta**: debe terminar en el nombre del fichero.

Elegido `envs/dev/terraform.tfstate` sobre `task-manager/terraform.tfstate`:

- El eje "dev vs prod" es el que más probablemente va a hacer falta antes que "proyecto A vs proyecto B" en el roadmap actual.
- Mañana se puede añadir `envs/prod/terraform.tfstate` sin refactor.

### Correcciones sintácticas cazadas durante la escritura

Errores en la primera versión escrita:

1. **`s3 { }` como bloque top-level** en lugar de `backend "s3" { }` dentro de `terraform { }`. Corrección: `backend` es sub-bloque de `terraform { }`, no un tipo de bloque independiente. Es metadata de Terraform mismo (dónde guarda su state), por eso vive dentro del bloque `terraform`.

2. **`encrypt = "true"` con comillas** (string) en lugar de `encrypt = true` (booleano). HCL distingue tipos: valores no textuales van sin comillas.

3. **`key = "backendS3/"`** con barra final describiendo el mecanismo. Corrección: el `key` debe identificar QUÉ state se guarda, no CÓMO. Además debe terminar en el nombre del fichero, no en `/`.

### Distinción: `backend "s3"` como label reservado

Cazado durante la revisión: en `backend "s3"`, el label `"s3"` **no es libre** como sí lo son los labels de `resource`. Terraform tiene una lista cerrada de backends soportados (`local`, `s3`, `azurerm`, `gcs`, `remote`, `kubernetes`, etc.) y el label debe coincidir. Es análogo a una anotación `@Backend("s3")` en Java donde el string tiene que existir en el registro de implementaciones.

## Bloque 5 — Migración con `terraform init -migrate-state` + descubrimiento no planificado

### Preparación defensiva

Antes de ejecutar la migración, tres pasos de higiene:

1. **Backup manual del state local**:
   ```
   cp terraform.tfstate terraform.tfstate.pre-migration
   cp terraform.tfstate.backup terraform.tfstate.backup.pre-migration
   ```

2. **Verificación de permisos IAM con cinco comandos AWS CLI**:
   - `aws sts get-caller-identity` → usuario `tole` confirmado en cuenta `750392809244`.
   - `aws s3 ls s3://toleflaco-terraform-state-2026` → silencio = permiso OK sobre bucket vacío.
   - `echo "check" | aws s3 cp - s3://.../permission-check.txt` → `PutObject` OK.
   - `aws s3 rm s3://.../permission-check.txt` → `DeleteObject` OK.
   - `aws dynamodb describe-table --table-name terraform-state-lock` → tabla ACTIVE, PAY_PER_REQUEST, `LockID` HASH confirmado.

Enfoque: IAM es deny-by-default, la única forma fiable de verificar permisos es intentar la operación. Si funciona, había permiso; si `AccessDenied`, no.

### Ejecución del `init -migrate-state`

Resultado inesperado: **el prompt "Do you want to copy existing state to the new backend?" no apareció**. Terraform pasó directamente a `Successfully configured the backend "s3"!`.

Explicación empírica descubierta: Terraform inspeccionó el state local (`resources: []` post-destroy de S10) y decidió que no había nada útil que migrar. El prompt de copia aparece solo cuando hay recursos reales en el state local. Consecuencia: el `lineage` local (`6cbf80e6-43a8-03ec-bc73-e6eabacaf0c3`) quedó huérfano, y el próximo `apply` generó un `lineage` nuevo desde cero. Sin importancia en este contexto (proyecto de aprendizaje), pero conceptualmente relevante.

### Descubrimiento no planificado: warning de deprecation

Output del `init -migrate-state` incluyó un warning no esperado:

```
Warning: Deprecated Parameter
  The parameter "dynamodb_table" is deprecated. Use parameter "use_lockfile" instead.
```

**Contexto histórico investigado en la sesión** (frase para diario):

Terraform 1.10 (dic 2024) introdujo `use_lockfile` como feature experimental. Aprovecha que S3 recibió en 2024 dos primitivas que le faltaban:

1. **Conditional writes** (`If-None-Match: *`): "crea este objeto solo si no existe" como operación atómica.
2. **Strong read-after-write consistency** (completada tras 2020).

Antes de estas primitivas, S3 era inviable como semáforo: sin conditional writes, dos procesos podían crear el mismo lock silenciosamente; sin strong consistency, un "no existe" recién leído podía ser mentira.

**DynamoDB** siempre tuvo ambas primitivas: `PutItem` con `ConditionExpression: "attribute_not_exists(LockID)"` es atómico, y ofrece strong consistency configurable por request. Por eso Terraform delegaba en él.

Terraform 1.11 (2025) estabilizó `use_lockfile` y marcó `dynamodb_table` como deprecated. Terraform 1.15 (agosto 2026, la versión instalada) muestra el warning en cada `init`.

### Fichero C confirmado empíricamente

Durante la sesión se cazó un error en el modelo mental que se estaba enseñando: se afirmó que `.terraform/terraform.tfstate` (Fichero C, la cache de backend) "existe siempre". Verificación empírica del alumno demostró que **no existía** en su directorio antes del `init`. Corrección:

- Con backend implícito (local por default), no hay Fichero C porque no hay config de backend que cachear.
- El Fichero C se crea la **primera vez** que se configura un backend explícito con `init`.
- A partir de entonces, cualquier `init` posterior lo lee para detectar cambios de config.

Modelo corregido y confirmado con `ls -la .terraform/` antes y después del `init`.

## Bloque 6 — Migración a `use_lockfile` con `init -reconfigure`

### Reescritura del `versions.tf`

Sustitución limpia (opción A) sobre opción B (coexistencia temporal):

```hcl
backend "s3" {
  bucket       = "toleflaco-terraform-state-2026"
  key          = "envs/dev/terraform.tfstate"
  region       = "eu-west-1"
  use_lockfile = true
  encrypt      = true
}
```

Justificación: setup individual sin equipo ni CI que dependa de la tabla DynamoDB. La coexistencia temporal es feature para migraciones grandes coordinadas — meterla añade ruido conceptual sin beneficio.

### Distinción `init` vs `init -migrate-state` vs `init -reconfigure`

Cazado por Terraform en la primera ejecución sin flag:

```
Error: Backend configuration changed
```

Terraform obliga a elegir explícitamente:

- `init -migrate-state`: reinicializa backend + copia state entre backends. Aplicable en la migración de local a S3 (S11-A).
- `init -reconfigure`: reinicializa backend con nueva config, sin mover state. Aplicable en el cambio de mecanismo de locking dentro del mismo backend (S11-B).

Semáforo defensivo: evita que un cambio accidental de backend en el HCL pierda conexión con el state remoto sin darse cuenta.

### Verificación empírica post-reconfigure

Predicciones 4/4 correctas:

1. Cambió el Fichero C (`.terraform/terraform.tfstate`), no el `versions.tf`. Nuevo hash de config: `2420145517` (antes `3481222129`).
2. En el Fichero C: `"dynamodb_table": null`, `"use_lockfile": true`.
3. No apareció warning de deprecation (ya no hay `dynamodb_table` en el HCL).
4. No se creó ningún objeto en S3 durante `init` (init es local, no toca AWS).

Confirmación de la regla ⭐⭐⭐ de S10: **"init es local, plan es read-only en AWS, apply es write en AWS"**.

## Bloque 7 — Ciclo completo apply+destroy sobre backend remoto

### Setup: verificación del `.tflock` en vivo desde segunda terminal

Ejercicio empírico con dos terminales en paralelo:

- **Terminal 1**: `terraform apply`, dejar en el prompt `Enter a value:` sin escribir `yes`.
- **Terminal 2**: `aws s3 ls s3://toleflaco-terraform-state-2026/envs/dev/`.

Resultado observado en terminal 2:

```
2026-08-16 07:38:09        234 terraform.tfstate.tflock
```

**El `.tflock` existe en S3 durante todo el prompt**. Empíricamente demostrado que el lock se adquiere antes del prompt, no después del `yes`. Consecuencia: mientras la persona A duda en escribir `yes`, la persona B está bloqueada.

### Contenido del `.tflock` leído en vivo

```json
{
  "ID": "472db7b2-9280-e123-5e27-3117fd460b27",
  "Operation": "OperationTypeApply",
  "Info": "",
  "Who": "tole@TxM",
  "Version": "1.15.8",
  "Created": "2026-08-16T05:38:08.633393594Z",
  "Path": "toleflaco-terraform-state-2026/envs/dev/terraform.tfstate"
}
```

Este es el bloque `Lock Info` que vería en su terminal cualquier compañero intentando `apply` en paralelo. El `ID` UUID es el que se pasaría a `terraform force-unlock <ID>` si el lock quedara huérfano tras un `Ctrl+C` sucio.

**Detalle de timing observado**: `Created` en el JSON = `05:38:08.633` UTC, `ls` en local = `07:38:09`. Un segundo de delta = latency real de `PutObject` + visibility en `ListObjects` (offset +02:00 verano en Cantabria coherente).

### State real escrito a S3 tras `apply`

Post-`yes` y post-`Apply complete!`:

```
2026-08-16 07:40:19       3191 terraform.tfstate
```

El `.tflock` desapareció. Solo queda el state real. Contenido esperado y verificado:

- `"version": 4` (schema del state, distinto del `"version": 3` del Fichero C).
- `"serial": 1` (primer state escrito en este backend).
- `"lineage": "6d8b3dbd-a903-d71a-8fd9-e6d84798dde2"` (UUID nuevo, distinto del local residual `6cbf80e6-...`).
- `"resources"` con el bucket `terraform-test-toleflaco-2026` completo (ARN, atributos AWS, tags, encryption SSE-S3 por defecto, hosted_zone_id, etc.).
- `"outputs": {}`, `"check_results": null`.

**Regla mental fijada**: si el JSON tiene `"backend"` top-level, es Fichero C. Si tiene `"resources"` top-level, es state real. La estructura desambigua.

### Ciclo del `.tflock` en el `destroy`

Predicciones 4/4 correctas. `destroy` mostró exactamente el mismo ciclo del lock:

- `.tflock` apareció con nuevo UUID `7f5517f4-...` (los locks no se reutilizan, cada operación adquiere uno nuevo).
- Contenido del `.tflock`: `"Operation": "OperationTypeApply"` incluso durante un `destroy`. Terraform trata `destroy` internamente como una variante de `apply` (apply que solo destruye). Motor de ejecución compartido.
- Post-destroy: state cambia a `"resources": []` con `"serial": 2` y `"lineage"` idéntico (`6d8b3dbd-...`).
- Confirmación N-ésima: **Terraform NO borra el state file, solo lo reescribe con array vacío**.

### Distinción de categorías de operaciones (observación derivada durante la sesión)

Insight cazado al ver que el `.tflock` no aparece en `init` pero sí en `apply`/`destroy`:

- **Operaciones sobre configuración local**: `init`, `init -reconfigure`, `validate`, `fmt`, `providers`. Tocan solo el directorio local. No leen ni escriben state. **No adquieren lock.**
- **Operaciones sobre state**: `plan`, `apply`, `destroy`, `refresh`, `state *`, `import`, `taint`. Todas leen state. **Todas adquieren lock**, sin importar si el resultado es crear, modificar o destruir.

## Frases ⭐⭐⭐ locked

1. **"Un bucket, un propósito. Propósitos distintos implican políticas distintas, y políticas mezcladas son políticas rotas."** (higiene arquitectónica del bucket dedicado)

2. **"Cada recurso debe tener el blast radius más pequeño posible. Compartir buckets multiplica radios innecesariamente."** (razonamiento defensivo de diseño AWS)

3. **"S3 = dónde vive el state (compartido, versionado, cifrado). Semáforo externo = coordina quién puede tocarlo. Dos servicios independientes cooperando, no una feature integrada."** (mecánica remote backend)

4. **"Provisioned = capacidad reservada 24/7 (rentable en tráfico alto sostenido). On-Demand = pago por request (rentable en tráfico bajo o variable)."** (decisión de capacity mode DynamoDB)

5. **"S3 buckets son namespace global. Casi todo lo demás en AWS es scoped a cuenta+región. Naming pesado solo donde el scope lo exige."** (vocabulario operativo AWS)

6. **"SSE-S3 protege datos. SSE-KMS además audita accesos."** (tiers de encryption en S3)

7. **"KMS = servicio regional de gestión de claves. Cifra transparente + auditoría de cada uso en CloudTrail. Base de compliance en banca."** (introducción de KMS forzada por alumno)

8. **"Terraform sin bloque `backend` = backend local implícito. El default no se declara, se hereda."** (bloques de HCL)

9. **"Terraform lee todos los `.tf` del directorio como uno solo. Los nombres son convención, no semántica."** (estructura de proyecto Terraform)

10. **"En `backend "s3"`, el label no es libre — es una clave reservada que selecciona qué implementación de backend usa Terraform."** (distinción label libre vs reservado)

11. **"El `key` del backend S3 es un path al objeto, no una carpeta. Debe identificar QUÉ state se guarda, no CÓMO."** (naming del `key`)

12. **"El lock protege un state file, no un bucket. Múltiples states en el mismo bucket son múltiples locks independientes."** (granularidad del lock)

13. **"Terraform siempre tuvo locking. Lo que cambió es que S3 finalmente ganó conditional writes atómicas (2024) — DynamoDB era necesario porque S3 no las tenía."** (contexto histórico de la deprecation)

14. **"`.tflock` = objeto efímero, su existencia ES el lock, su ausencia = libre. `PutObject` con `If-None-Match` es 'adquirir', `DeleteObject` es 'liberar'."** (mecánica del lockfile)

15. **"`init -reconfigure` = reinicializa backend, no mueve state. `init -migrate-state` = reinicializa + copia state entre backends. Terraform obliga a elegir uno cuando detecta cambio de config."** (flags de `init`)

16. **"Dos JSONs, dos schemas, mismo nombre. Fichero C tiene `backend`. State real tiene `resources`. La estructura desambigua."** (distinción Fichero A / Fichero C)

17. **"El `.tflock` es un JSON con metadata operacional: quién, qué operación, qué path, cuándo. Es a la vez el semáforo (por existir) y el aviso (por su contenido)."** (naturaleza del lockfile)

18. **"Timestamp del JSON = cuándo Terraform decidió crear el lock. Timestamp del `ls` = cuándo S3 hizo visible el objeto. Delta = latency real de la operación."** (observación empírica de timing)

19. **"Backend nuevo = lineage nuevo. Migrar de local a remoto sin copiar rompe la continuidad, no es error si el state local estaba vacío."** (semántica del lineage)

20. **"Terraform lockea el state, no los recursos. Cualquier operación que abra el state adquiere lock — apply, destroy, refresh, taint. `init` no lo hace porque no toca state."** (categorías de operaciones)

21. **"Terraform escribe ficheros. No los borra. El borrado siempre es acción humana explícita."** (heredada de S10, reforzada empíricamente tres veces en S11: destroy, migrate-state, destroy final)

22. **"El material técnico caduca entre planificación y ejecución. En stacks vivos, adopta la advertencia del compilador o del CLI como señal — no como ruido."** (lección meta sobre la deprecation cazada en vivo)

## Estado de recursos AWS

**Al inicio de la sesión (15 ago 09:30)**: idéntico al cierre de S10. Bucket de uploads vivo, EC2/RDS parados, VPC/VPC Endpoint/SGs vivos, MongoDB Atlas M0 vivo, Terraform con state local vacío tras destroy de S10.

**Durante la sesión**:
- Creado: bucket S3 `toleflaco-terraform-state-2026` (state remoto, vacío inicial).
- Creado: tabla DynamoDB `terraform-state-lock` (locking, luego huérfana tras migración a `use_lockfile`).
- Creado y destruido en el ciclo empírico: bucket `terraform-test-toleflaco-2026` (recurso de prueba de `main.tf` heredado de S10).
- Eliminado al cierre: tabla DynamoDB `terraform-state-lock` (huérfana sin propósito tras la migración).

**Al cierre (16 ago 08:15)**:
- Bucket state `toleflaco-terraform-state-2026` vivo con un solo objeto: `envs/dev/terraform.tfstate` (state vacío tras el destroy, `resources: []`, `serial: 2`).
- Tabla DynamoDB eliminada.
- Resto de infra: idéntico al inicio.
- Coste incurrido durante la sesión: prácticamente cero (bucket vacío = céntimos de fracción por requests; tabla DynamoDB On-demand con ~50 requests totales = fracción de céntimo).

## Cambios en el repo

Commits pusheados a `origin/main`:

1. `b219b8e` — `feat(infra): configure S3 backend with DynamoDB locking` (S11-A, cierre parcial con deuda anotada de migrar a `use_lockfile`).
2. `<pendiente_S11B>` — `refactor(infra): migrate to S3 native locking with use_lockfile` + bitácora completa (S11-B, cierre definitivo).

Ficheros modificados:
- `infra/versions.tf`: añadido bloque `backend "s3"`, sustituido `dynamodb_table` por `use_lockfile = true`.
- `infra/main.tf`: vaciado del bloque `resource` de prueba, dejado placeholder para S12.
- `bitacora/Sesion11-AWS-Diario.md`: nuevo.

Ficheros locales borrados como cierre de limpieza (todos gitignored, nunca commiteados):
- `terraform.tfstate`, `terraform.tfstate.backup` (residuo del backend local).
- `terraform.tfstate.pre-migration`, `terraform.tfstate.backup.pre-migration` (backups defensivos pre-migración).

## Lecciones operativas nuevas

1. **Material técnico caduca entre planificación y ejecución**. El plan de S11 se hizo con documentación mainstream (DynamoDB para locking) que llevaba años siendo la práctica correcta. En la ejecución, Terraform 1.15 mostró warning de deprecation en cada `init`. Regla derivada: **adoptar la señal del CLI o del compilador como parte del aprendizaje, no como ruido**. Ignorarla habría cimentado un patrón deprecated en el portafolio. Cazarla en vivo y migrar convirtió la sesión en aprendizaje real de "cómo lidiar con evolución de tecnologías vivas".

2. **Vocabulario nuevo sin introducción explícita cazado por el alumno**. Utilicé "KMS" tres veces antes de haberlo presentado; el alumno paró y pidió definición. Regla operativa reforzada (heredada de S10): **cuando se introduce un término técnico por primera vez, dedicar bloque explícito antes de asumirlo conocido**. Sigue siendo mi fallo recurrente, sigue siendo pushback correcto del alumno.

3. **Pushback conceptual del alumno cazó tres errores míos**. Cazadas:
   - "`s3 { }` como bloque top-level" en su primera reescritura del `versions.tf` — mi ejemplo previo no había explicitado la anidación dentro de `terraform { }`.
   - "no tengo Fichero C" empíricamente contra mi afirmación teórica de que "existía siempre" — modelo mental corregido con evidencia de su directorio.
   - "s3 en `backend "s3"` es una etiqueta como en `resource`, ¿no?" — obligó a distinguir labels libres vs labels reservados.
   
   Regla derivada: **el pushback conceptual del alumno es señal de método sano funcionando, no de fricción a suavizar**. Corregir sin dilación y agradecer implícitamente al alumno por parar.

4. **Ratio de predicciones acertadas heterogéneo revela zonas de dominio**. En S11-B: warmup 1/3 (state persistente, DynamoDB necesario, ciclo del `.tflock`) — modelo mental de "state persistente" sigue fallando por tercera vez consecutiva. En cambio, predicciones de ejecución 4/4 correctas en apply, 4/4 en destroy. **Patrón detectado**: dominio operativo sólido, dominio conceptual sobre persistencia de state todavía frágil. Requiere refuerzo directo, no analogía.

5. **Sesión partida en tres tramos por dos razones distintas — ambas correctas**. Corte AM→PM del día 15 por respeto a regla de 4h/día. Corte PM→B del día 15 por descubrimiento no planificado que merecía cabeza fresca al día siguiente. **Ambos cortes preservaron pedagogía, ninguno degradó calidad**. Regla derivada: cuando aparece un descubrimiento no planificado que cambia el plan de sesión, la respuesta correcta suele ser cortar y digerir, no acelerar para "cerrar hoy".

6. **Verificación empírica en dos terminales convirtió abstracto en tangible**. El ejercicio "abrir segunda terminal y ejecutar `aws s3 ls` mientras el `apply` espera `yes`" transformó "el `.tflock` es un objeto efímero" (concepto abstracto) en "acabo de ver aparecer un fichero de 234 bytes en el bucket con mis propios ojos" (evidencia empírica). Regla derivada: **cuando un mecanismo tenga ciclo de vida efímero (locks, session tokens, presigned URLs), diseñar ejercicio que permita observarlo en el momento intermedio**.

7. **Verificación IAM previa con AWS CLI evita fallos crípticos durante Terraform**. Cinco comandos ejecutados antes del `init` confirmaron: identidad, ListBucket, PutObject, DeleteObject, DescribeTable. Si alguno hubiera fallado, se habría añadido policy antes de lanzar Terraform en lugar de debuggear un `terraform init` fallido con error de permisos ambiguo. Regla operativa: **antes de operaciones sensibles con permisos AWS, verificar cada permiso individual con AWS CLI directo**.

## Deuda arrastrada actualizada

### Deuda nueva (Sesión 11)

- **Bitácora Sesión 11 pendiente** — cerrada al escribirla.
- **Deuda pedagógica sobre modelo mental de persistencia del state**: patrón detectado (fallo 3 veces en warmup + predicciones), requiere refuerzo directo antes de S12.
- **Sesión 12 tendrá contexto sobre `terraform import` sobre backend remoto**: refactor de VPC/EC2/RDS/S3 uploads existentes con state ya en S3. Camino explícito.

### Deuda arrastrada de sesiones anteriores (siguen abiertas)

- **README de portfolio pendiente actualizar** con S3 integration + presigned URLs + VPC Endpoint. Acumulada desde S6-S8.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2**. Elastic IP fija o Atlas VPC Peering.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location**. Deuda REST menor.
- **`postgresql-client` en EC2 en v16 vs server v18**.
- **Billing access para IAM user `tole`** — activar desde root.
- **Verificación empírica del tráfico por VPC Endpoint** — postpuesta al módulo Observabilidad.
- **Concepto de `tags_all` y `default_tags` a nivel provider** anticipado pero no ejercitado — programado para S12 o módulos.

### Deudas cerradas hoy

- **Remote state en S3 + locking**: completo end-to-end. `init -migrate-state` ejecutado, `use_lockfile` adoptado en lugar del DynamoDB deprecated, ciclo apply+destroy validado sobre backend remoto.
- **Diferencia entre Fichero A (state real, con `resources`) y Fichero C (backend cache, con `backend`)**: fijada empíricamente al inspeccionar ambos en el mismo directorio.
- **Vocabulario "región vs Availability Zone" en AWS**: corregido con evidencia visual en la consola.
- **Vocabulario "namespace global vs scoped a cuenta+región" en AWS**: fijado con tabla comparativa.
- **Ciclo de vida del `.tflock`**: observado empíricamente en apply y en destroy, con timestamps propios.
- **Distinción `use_lockfile` (flag persistente en config) vs `.tflock` (objeto efímero en S3)**: fijada tras corrección de vocabulario del alumno.

## Para retomar en Sesión 12

**Warmup (~10 min)**: predicciones cortas sin abrir el diario:

1. Diferencia funcional entre `dynamodb_table` y `use_lockfile = true` en el backend S3. ¿Por qué se hizo la transición?
2. Al ejecutar `terraform apply`, ¿en qué momento exacto (antes/durante/después del prompt) se adquiere el lock? ¿Por qué en ese momento y no en otro?
3. Si haces `Ctrl+C` limpio en el prompt `yes` de un `apply`, ¿qué pasa con el `.tflock`? ¿Y si haces `kill -9` al proceso?
4. Qué esperas ver en el bucket S3 del state (`envs/dev/`) si asomas la cabeza justo mientras un compañero está ejecutando `terraform plan` en su máquina.
5. En un `terraform destroy` exitoso, ¿cuál es el `serial` post-destroy y por qué? ¿Se borra el objeto `terraform.tfstate` del bucket S3?

**Sesión 12 — Refactor de infra existente con `terraform import` (parte 4 de la Sesión 5 oficial)**:

1. Concepto: adopción brownfield vs greenfield. Cuándo tiene sentido `terraform import`.
2. Anatomía del comando `terraform import`. Sintaxis, prerequisitos, limitaciones.
3. Import del VPC custom `task-manager-vpc` (recurso simple, sin dependencias hacia adentro).
4. Import de las subnets, IGW, Route Tables asociadas (grafo de dependencias).
5. Import del bucket `toleflaco-task-manager-uploads-2026` con su configuración completa (versioning, policies).
6. Import del Security Group `sg-ec2-task-manager` con reglas.
7. Import de EC2 `task-manager-ec2` + Instance Profile + Role.
8. Import de RDS `task-manager-db` con deletion protection.
9. Verificación empírica: `terraform plan` debe mostrar `No changes` para cada recurso importado (si el HCL corresponde al estado real).
10. Commit + push + bitácora `Sesion12-AWS-Diario.md`.

**Refuerzo pedagógico obligatorio antes de arrancar S12**: revisar con notas delante los tres fallos de "persistencia del state" cazados en el warmup y a lo largo de S11. Modelo mental correcto: **Terraform escribe ficheros. No los borra. Ni en destroy, ni en migrate-state, ni en reconfigure. Ni siquiera cuando el state queda vacío. El borrado es siempre acción humana explícita**.

**Alternativa vespertina ligera**: sesión guiada de repaso de los conceptos de S11 sin material nuevo, verificando que las 22 frases ⭐⭐⭐ están consolidadas mediante preguntas socráticas.

## Meta-observaciones de método

- **Sesión partida en tres tramos por dos causas distintas — ambas legítimas y correctamente diagnosticadas**. Corte AM→PM del 15 por regla operativa de 4h/día (mecánica). Corte PM→B del 15 por descubrimiento no planificado que exigía cabeza fresca (cognitiva). Ambos cortes preservaron pedagogía.

- **Ratio de predicciones acertadas heterogéneo por bloque**: warmup 1/3 (persistencia state, DynamoDB, `.tflock`), reconfigure 4/4, apply 4/4, destroy 4/4. **Patrón detectado**: dominio operativo sólido, dominio conceptual sobre state persistente frágil. El fallo se corrigió cada vez pero volvió a aparecer — señal de que necesita refuerzo directo (no analogía) al inicio de S12.

- **Tres cazadas del alumno resultaron catalizadoras**: (a) `s3 { }` como bloque top-level obligó a explicar la anidación de `backend` dentro de `terraform { }`; (b) "no tengo Fichero C" empíricamente contra mi afirmación teórica desmontó un modelo mental erróneo; (c) "`s3` es una etiqueta, ¿no?" obligó a distinguir labels libres vs labels reservados. Confirma regla de S10: las preguntas espontáneas mejoran la explicación planificada.

- **Corrección propia sin softening aplicada tres veces**: (a) "KMS sin introducir" cazado por alumno, corregido con bloque explícito; (b) "prompt de copia aparecerá" en la predicción de `init -migrate-state` — falló, corregido con explicación de por qué; (c) "Fichero C existe siempre" — cazado empíricamente, corregido con modelo refinado. Efecto observado: refuerza confianza en el método, no la daña.

- **Descubrimiento no planificado gestionado correctamente**: el warning de deprecation de `dynamodb_table` no aparecía en el plan de sesión. Respuesta correcta: pausar, investigar contexto histórico completo (por qué existía DynamoDB, qué cambió en 2024, por qué ahora `use_lockfile` es superior), documentar como aprendizaje. La alternativa (ignorar el warning y seguir con la práctica deprecated) habría cimentado deuda técnica en el portafolio.

- **Ejercicio empírico de dos terminales fue el momento más didáctico de la sesión**. La captura del `.tflock` en vivo con `aws s3 cp <lockfile> -` mostró contenido real, no abstracto. Timestamps observados (`Created` UTC vs `ls` local) permitieron cazar detalle secundario de latencia. Regla derivada para IaC: cuando un mecanismo tenga ciclo de vida efímero, siempre diseñar ejercicio que permita observarlo en el momento intermedio.

- **Deuda nueva hoy: 1 pedagógica (patrón de fallo en persistencia state) + 0 conceptuales técnicas**. Todas las deudas conceptuales anticipadas de S10 quedaron cerradas: remote backend ✓, mecanismo de locking ✓, migración de state ✓. Ratio deuda/entregado excelente.

- **Estimación de contexto al cierre**: ~55-65% del chat consumido tras 3h30 acumuladas repartidas en tres tramos + escritura de bitácora completa. Generación de prompt de continuación recomendada al arrancar Sesión 12.
