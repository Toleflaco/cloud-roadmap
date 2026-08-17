# Sesión 12-A — Adopción brownfield con `terraform import` (parte 4 de la Sesión 5 oficial del roadmap)

**Fecha:** 17 agosto 2026
**Duración:** ~2h15 (~09:00 – 11:15, ventana única)
**Estado:** Parcial. Cierre S12-A con VPC importada al state y `terraform plan` = `No changes` verificado. Recursos pendientes de importar: 4 subnets (descubiertas hoy — no 2 como asumía el prompt de continuación de S11), IGW, ≥2 Route Tables + associations + routes, 2 Security Groups + reglas, S3 bucket de uploads + sub-recursos, IAM Role + Instance Profile, EC2, RDS, VPC Endpoint Gateway. Recalibración de estimación: adopción brownfield con `terraform import` clásico requiere 30-40 min por recurso, no 20. Total realista pendiente en S12-B (y probablemente S12-C): ~4h. Cierre S12-A justificado por respeto a la regla operativa de 2h y para evitar corte de método por fatiga.

## Objetivo pedagógico

Iniciar la adopción brownfield sistemática de la infra manual creada en S1-S8, importándola al control de Terraform sin destruir ni interrumpir servicio. Cubrir en orden:

1. Concepto de adopción brownfield vs greenfield. Cuándo tiene sentido `terraform import` vs recrear desde cero.
2. Anatomía del comando `terraform import`. Sintaxis, prerequisitos, limitaciones.
3. Vocabulario de schema del provider: Required / Optional / Computed y consecuencias operativas.
4. Peligro de defaults implícitos en HCL y cómo protegerse con las tres capas (version pinning, lectura del plan, policy engines).
5. Import práctico del VPC custom `task-manager-vpc` como recurso raíz sin dependencias hacia adentro. Verificación empírica del `.tflock` en segunda terminal, y de `terraform plan` = `No changes`.

Sesión cortada tras el paso 5 con solo 1 recurso importado. La estimación original (~2h para 9 pasos) resultó mal calibrada. El cierre respeta la regla operativa de 4h/día y evita degradar método.

## Bloque 1 — Warmup: repaso de conceptos de S11

Cinco preguntas de predicción antes de arrancar contenido nuevo, sin abrir diario de S11.

### Preguntas y desempeño

| # | Tema | Predicción del alumno | Realidad | Correcto |
|---|------|----------------------|----------|----------|
| 1 | `dynamodb_table` vs `use_lockfile` — cuándo | "Diciembre 2024, versión no la recuerdo" | Conditional writes S3 nov 2024, Terraform 1.11 (feb-mar 2025) marca deprecated | Parcial |
| 1 | `dynamodb_table` vs `use_lockfile` — dónde vive el lock | "En dynamodb tenemos el semáforo en una tabla, con `use_lockfile` lo tenemos en el `versions.tf`" | El lock físico es un objeto S3 `.tflock` en el mismo path que el state, NO la línea de config en `versions.tf` | Incorrecto |
| 2 | Momento de adquisición del lock en `apply` | "Antes del prompt, para tenerlo bloqueado antes de leer todo el plan y poder confirmar" | Correcto y bien razonado | Correcto |
| 3 | `.tflock` tras `Ctrl+C` vs `kill -9` | "Está bloqueado, tendríamos que desbloquearlo forzosamente con su UUID" | Solo cierto para `kill -9`. `Ctrl+C` limpio libera lock via handler `SIGINT` | Parcial |
| 4 | Contenido del bucket state durante plan ajeno | "El `use_lockfile = true`, antes de que confirme el prompt" | Verías `terraform.tfstate` (siempre) + `terraform.tfstate.tflock` (mientras dure la operación) — NO la línea de config | Incorrecto |
| 5 | Serial post-destroy + destino del state + destino del .tflock | ".tflock se borra, state no se borra solo se vacía de recursos. Serial: no lo recuerdo bien" | Todo correcto excepto serial: NO es el mismo, INCREMENTA porque `destroy` es una mutación | Parcial correcto en lo crítico |

### Resultado global del warmup

**1.5 aciertos limpios de 5**. Aciertos limpios en P2 y la parte crítica de P5 (persistencia del state — el fallo obsesivo cazado 3 veces en S11 QUEDÓ arreglado).

Errores nuevos identificados:
- **Confusión "config del mecanismo" vs "objeto físico del lock"**: el alumno equipara `use_lockfile = true` (la línea que activa el mecanismo) con el `.tflock` (el objeto S3 efímero que ES el lock). Empíricamente lo tenía locked en S11, se desdibujó en 24h.
- **Distinción `Ctrl+C` vs `kill -9`**: no trabajada explícitamente en S11, fallo honesto por primera vez.

Errores viejos NO recaídos:
- Persistencia del state tras destroy — locked correctamente por primera vez. Patrón cerrado.

### Regla operativa derivada

**Los conceptos empíricos consolidados en una sesión requieren relectura de notas cada 48-72h hasta que salgan sin pensar**. Sin uso diario, se desdibujan. El propio alumno lo verbaliza: "tengo que repasarme las notas cada 2 ó 3 días".

Fijado como práctica: releer bitácoras recientes en sesiones ligeras (Sundays o low-energy slots), sin abrir código, solo texto.

## Bloque 2 — Adopción brownfield vs greenfield

### Vocabulario

- **Greenfield**: proyecto arrancado desde cero, sin infra previa. HCL y realidad AWS nacen sincronizados porque el HCL ES el origen de la realidad. State arranca vacío y se puebla con lo que Terraform va creando en `apply`.
- **Brownfield**: proyecto donde la infra YA EXISTE, creada por otro medio (consola AWS, scripts bash, otro tool IaC). El trabajo es meter esa infra bajo gestión de Terraform sin destruirla ni interrumpir servicio.

Origen del término: urbanismo. "Brownfield sites" son solares industriales abandonados que se rehabilitan (con costes de descontaminación) vs "greenfield sites" que son suelo virgen.

### Caso del alumno: puro brownfield

VPC, subnets, IGW, RTs, SG, EC2, RDS, S3 bucket de uploads, Instance Profile, Role, VPC Endpoint — todos creados por consola AWS en S1-S8. HCL no existe todavía. State vacío (`resources: []` al cierre de S11). Hay que reconciliar tres realidades:

1. La realidad AWS (los recursos vivos).
2. El HCL que hay que escribir.
3. El state file (mapeo entre 1 y 2).

En greenfield, 2 y 3 nacen juntos porque Terraform los genera al aplicar. En brownfield hay que construir el puente manualmente: escribir 2 (HCL), ejecutar `import` para poblar 3 (state), y verificar con `plan` que 2 y 1 coinciden.

### Trade-off import vs recrear desde cero

| Import (brownfield) | Recrear (greenfield forzado) |
|---|---|
| Cero downtime | Ventana de mantenimiento obligatoria |
| Cero pérdida de datos | Migración de datos = proyecto en sí mismo |
| IDs de AWS preservados (DNS, connection strings, IAM policies, integraciones externas siguen apuntando bien) | Cambio de IDs con dependencias externas rotas |
| Nombres únicos globales (S3 buckets) siguen intactos | Colisión temporal imposible (S3 buckets globales) |
| HCL potencialmente arrastra decisiones históricas raras del que creó por consola | HCL limpio desde cero |
| Riesgo de drift silencioso HCL vs realidad si HCL mal escrito | Sin riesgo de drift inicial |
| Ejercicio de "describir realidad" — menos didáctico | Ejercicio de "diseñar desde cero" — más didáctico |

### Regla operativa de la industria

**Si la infra tiene datos, tráfico o dependencias externas, se importa. Si es sandbox descartable, se recrea.**

Caso del alumno: RDS con datos (aunque de prueba), S3 con objetos, EC2 con Instance Profile referenciado. Se importa.

### Regla del ciclo de import

**Escribir HCL correcto → `import` → `plan` → verificar "No changes" → si hay diff, iterar HCL → repetir plan.**

Criterio de éxito: no es que "el import salga bien". Es que el `plan` posterior salga `No changes`. Mientras haya diff, el HCL no describe fielmente la realidad y todavía hay drift.

## Bloque 3 — Anatomía del comando `terraform import`

### Sintaxis

```
terraform import [options] <ADDRESS> <ID>
```

- `<ADDRESS>` = identidad Terraform. Formato `<tipo_recurso>.<nombre_local>`. Ejemplo: `aws_vpc.main`.
  - Tipo (`aws_vpc`) viene del **provider Terraform** (`hashicorp/aws`), no de AWS directamente. El provider modela los recursos AWS pero el schema es decisión del equipo del provider.
  - Nombre local (`main`) es elegido por el alumno al escribir el bloque `resource`.
  - Puede tener path de módulo: `module.network.aws_vpc.main`.
- `<ID>` = identidad AWS. Varía por tipo de recurso. Para VPC es `vpc-xxxxx`. Para EC2 es `i-xxxxx`. Para S3 es el nombre del bucket. La doc del provider (Terraform Registry) especifica el formato en la sección "Import" al final de cada recurso.

### Ejemplo pactado para el import de hoy

```bash
terraform import aws_vpc.main vpc-0d36eccf71cddeda7
```

### Lo que import NO hace

- **NO modifica AWS**. Cero llamadas de escritura a la API. Solo lee.
- **NO genera HCL** (en la vía imperativa clásica).
- **NO reconcilia** HCL con realidad. Solo lee AWS y escribe en state. La reconciliación es cosa del operador, iterando con `plan`.

### Lo que import SÍ hace

- **Adquiere lock**, como cualquier operación que toca state. Aparece `.tflock` en S3 al arrancar, desaparece al terminar. (Frase ⭐⭐⭐ locked en S11: "Terraform lockea el state, no los recursos. Cualquier operación que abra el state adquiere lock — apply, destroy, refresh, taint, import.")
- **Escribe state** en el backend configurado.
- **Incrementa el `serial`** del state (es una mutación).

### Alternativa declarativa disponible pero no usada hoy

Terraform 1.5+ introdujo el bloque `import { }` en HCL:

```hcl
import {
  to = aws_vpc.main
  id = "vpc-abc123"
}

resource "aws_vpc" "main" { ... }
```

Con `terraform plan -generate-config-out=generated.tf` Terraform autogenera el HCL del recurso importado. Es más seguro que la vía imperativa porque el import se aplica dentro del ciclo plan-apply normal.

**Decisión pactada**: hoy vía imperativa clásica. Razón pedagógica: el objetivo es entender qué le pasa al state cuando importas, no que la herramienta autogenere HCL sin ejercicio mental. Si Terraform genera el HCL, el alumno se salta el ejercicio de "predecir qué atributos tendrá que declarar" y se limita a copiar-pegar-limpiar. Para infra grande (~200 recursos) sí se usaría la vía declarativa.

### Tres escenarios de import según estado del HCL

1. **HCL sin bloque `resource` alguno para ese recurso**: `terraform import` falla con `resource address does not exist in the configuration`.
2. **HCL con bloque `resource` vacío** (`resource "aws_vpc" "main" {}`): import funciona, state se puebla con la realidad AWS, pero el próximo `plan` muestra diff enorme (state tiene 20 atributos, HCL 0). Puede proponer in-place updates para desalinearlos, o incluso `-/+ destroy and replace` en atributos read-only. **Peligrosísimo si se aplica sin leer.**
3. **HCL con bloque `resource` bien escrito describiendo la realidad**: import funciona, state se puebla con la realidad AWS, `plan` posterior compara HCL vs state y encuentra que coinciden. Muestra `No changes`. **Objetivo.**

### Cadena mental correcta HCL ↔ state ↔ realidad

1. Import lee AWS → escribe en state.
2. State ahora refleja AWS.
3. Plan compara HCL vs state.
4. Diff de plan = distancia entre lo que el HCL declara y lo que AWS realmente tiene.
5. Iterar HCL hasta que la diferencia sea cero → `No changes` → HCL fielmente describe AWS → adopción brownfield completa para ese recurso.

**Punto crítico**: `terraform plan` NO compara HCL contra AWS directamente. Compara HCL contra state. El state post-import refleja la realidad AWS. Por tanto plan post-import es indirectamente una comparación HCL-vs-AWS mediada por state.

## Bloque 4 — Vocabulario schema del provider: Required / Optional / Computed

Introducido como concepto nuevo tras cazar imprecisión del alumno al hablar de atributos "read-only" sin distinguir el mecanismo.

### Definiciones

- **Required**: DEBES declararlo en HCL o el plan falla.
- **Optional**: PUEDES declararlo. Si no lo haces, el provider aplica un default.
- **Computed**: NO puedes declararlo. Terraform lo LEE de la respuesta de AWS y guarda en state para que puedas referenciarlo desde otros recursos. Solo va AWS → Terraform, nunca al revés.
- **Optional+Computed** (avanzado): puedes declararlo; si no lo haces, AWS te asigna un valor que Terraform captura. Ejemplo: `dhcp_options_id`. No trabajado hoy.

### Consecuencia operativa

Si en el HCL escribes un atributo Computed (ejemplo: `state = "available"` dentro de `resource "aws_vpc" "main"`), Terraform **NO habla con AWS**. Valida contra schema del provider ANTES de llamar a API. Error inmediato:

```
Error: Unsupported argument
An argument named "state" is not expected here.
```

**Regla mental corregida**: los atributos del Grupo B (identidad/estado asignados por AWS) no se declaran no porque "AWS no los deje cambiar" sino porque **son Computed en el schema del provider**. La restricción la impone el provider antes que AWS. Distinción importante: errores de schema son baratos e instantáneos (validate/plan), errores de AWS aparecen tras adquirir lock y llamar API.

### Ejercicio de clasificación aplicado al VPC

Nueve atributos del JSON de `aws ec2 describe-vpcs` clasificados en Grupo A (decisiones explícitas del alumno), Grupo B (AWS asigna, no declarables — Computed), Grupo C (defaults aceptados sin fijarse — declarables o omitibles):

| Atributo | Grupo | Nota |
|---|---|---|
| `Tags` (Name=task-manager-vpc) | A | Elegido explícitamente |
| `CidrBlock` (10.0.0.0/16) | A | Elegido explícitamente |
| `InstanceTenancy` (default) | C | Elegido implícitamente al aceptar el default del formulario de consola |
| `OwnerId` (750392809244) | B | Account ID, asignado por AWS |
| `VpcId` (vpc-...) | B | Asignado al crear |
| `State` (available) | B | Estado runtime del recurso |
| `IsDefault` (false) | B | Consecuencia de haber usado "Create VPC" en consola vs `CreateDefaultVpc` |
| `BlockPublicAccessStates` | B | Feature 2024 a nivel cuenta/región, no atributo del VPC individual |
| `CidrBlockAssociationSet` | B | Vista alternativa del CIDR con AssociationId asignado por AWS |
| `DhcpOptionsId` | C | Asignado por AWS al aceptar default de la cuenta |

Errores cometidos por el alumno en la clasificación inicial (corregidos):
- Clasificó `BlockPublicAccessStates` y `State` como Grupo A.
- Olvidó clasificar `IsDefault` y `CidrBlockAssociationSet`.

### Regla operativa profesional emergente

Sobre defaults del Grupo C:
- Declararlos → HCL más explícito, protección ante cambios de defaults del provider en versiones futuras. Mayor detección de drift.
- Omitirlos → HCL más limpio, aceptas defaults del provider. Menor detección de drift.
- **Regla profesional**: declara explícitamente los defaults críticos (encryption, versiones, tenancy, cualquier cosa con `ForceNew` implícito). Omite defaults inocuos (tags opcionales, DHCP options si no personalizas).

## Bloque 5 — Peligro de defaults implícitos en HCL

### Escenario del riesgo

`instance_tenancy` NO declarado en HCL. Provider actual usa `"default"` como default. Todo bien.

Un día se actualiza provider AWS a versión N+1 y cambian el default (hipotético: pasa a `"dedicated"`). Se ejecuta `terraform plan`:

1. Terraform lee HCL → `instance_tenancy` no declarado → toma NUEVO default = `"dedicated"`.
2. Terraform lee state → `instance_tenancy = "default"` (heredado del import).
3. Compara HCL (interpretado con nuevos defaults) vs state → detecta diff.
4. Muestra en plan: `~ instance_tenancy = "default" -> "dedicated"`.

En este caso concreto `instance_tenancy` es un atributo `ForceNew` — cambiarlo obliga a `-/+ destroy and replace`. Destruir la VPC significa perder subnets, IGW, RTs, EC2, RDS, SG, VPC Endpoint. Catastrófico.

**Terraform NO te salta un mensaje preguntando si quieres modificar**. Terraform es declarativo y asume que tu HCL representa la verdad. El diff aparece en el plan, sí, pero es TU responsabilidad leerlo. `apply` con `yes` sin revisar → aplicado. Con `-auto-approve` → aplicado sin humano.

### Tres capas de protección (NO memorización de atributos)

Ante el auto-diagnóstico del alumno "eso es fácil decirlo si los sabes, si eres un pardillo como yo tendría que declarar todos" — respuesta operativa:

1. **Fijar versión del provider en `versions.tf`**. Ya lo tiene: `version = "~> 6.58"`. El operador `~>` (pessimistic constraint) acepta 6.58+ en la serie 6.x pero NUNCA salta a 7.x. Los defaults del provider AWS 6.x quedan congelados hasta que se suba a 7.x deliberadamente, revisando changelog. **Protección real sin memorización**.
2. **Leer el plan siempre antes del apply**. No es "buena práctica opcional" — es la regla operativa universal. Un plan de 200 líneas se lee en 3 minutos. Un `-/+ destroy and replace` inesperado salta a la vista.
3. **Policy engines en equipos maduros** (OPA, Sentinel, Checkov). Reglas automáticas que bloquean cambios peligrosos antes de producción.

Con esas tres capas, cualquier persona opera Terraform con seguridad. La memorización enciclopédica es lo que menos importa.

## Bloque 6 — Deuda pedagógica recaída: semver 1.15 vs 1.5

Al mencionar la vía declarativa "disponible desde Terraform 1.5", el alumno responde: **"yo no podría usarlo, tengo la versión 1.15"**.

Confusión grave de versionado semántico. Ya cazada en S10 con "MAJOR/MINOR/PATCH". Reaparece hoy en otra manifestación.

### Diagnóstico

Alumno lee `1.5` como decimal (uno-punto-cinco). No es decimal. Es **semver** = MAJOR.MINOR.PATCH. El componente MINOR es un entero, no decimal:

`1.0 → 1.1 → 1.2 → ... → 1.9 → 1.10 → 1.11 → 1.12 → 1.13 → 1.14 → 1.15 → ...`

Por tanto **`1.15 > 1.5`** (10 versiones MINOR de diferencia). Lo mismo aplica a Java 21 > Java 8, PostgreSQL 18 > PostgreSQL 9, Spring Boot 4 > Spring Boot 3.

### Corrección aplicada

Regla mental fijada: **"cuando veas un número de versión, léelo como una secuencia de enteros separados por puntos, no como un decimal"**. `1.15.8` = "uno-quince-ocho". No "uno coma quince".

### Consecuencia práctica para hoy

Alumno tiene Terraform 1.15.8. La vía declarativa `import { }` con `-generate-config-out` está disponible en su setup desde hace 10 versiones MINOR. La decisión de usar la vía imperativa es puramente pedagógica, NO técnica.

### Deuda arrastrada activa

Semver ha fallado 2 veces (S10 y S12-A). No repasarlo → volverá a fallar. Añadir al set de conceptos que requieren relectura cada 48-72h.

## Bloque 7 — Trampa de AWS: auto-rearranque RDS a 7 días

### Descubrimiento

Al arrancar S12-A, la RDS `task-manager-db` estaba `available`. Prompt de continuación de S11 la daba por `stopped`. Reacción inicial del alumno: "yo no lo he encendido estos días, no me jodas".

Diagnóstico ofrecido inicialmente por Claude: probable observación errónea al cierre de S11. **Diagnóstico incorrecto**.

### Verificación empírica con CloudTrail

Comandos ejecutados:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=StopDBInstance \
  --max-items 5

aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=StartDBInstance \
  --max-items 5
```

Eventos relevantes:
- **6 ago 20:51** — `StopDBInstance` (usuario `tole`).
- **7 ago 17:54** — `StartDBInstance` (aparece como `tole`).
- **7 ago 20:35** — `StopDBInstance` (usuario `tole`, definitivo).

Del 7 ago al 17 ago hay **10 días**. Más de 7.

### Contexto AWS: la trampa documentada

AWS RDS rearranca automáticamente cualquier instancia parada tras 7 días. Oficialmente "para asegurar parches de seguridad y mantenimiento". En la práctica: trampa de facturación muy criticada por la comunidad. Sin aviso, sin notificación por email por defecto.

### Regla operativa fijada

**Al cerrar cada sesión, verificar EN LA CONSOLA o con AWS CLI el estado de recursos costosos. No confiar en memoria de "creo que la paré".**

Snippet añadido al checklist estándar de fin de sesión (junto a `docker compose ps` y `git status`):

```bash
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,State.Name]' \
  --output table

aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]' \
  --output table
```

30 segundos. Evita facturación silenciosa.

### Corrección meta

Diagnóstico inicial de Claude ("probable observación errónea") fue incorrecto. Retirado explícitamente tras evidencia CloudTrail. **Regla implícita**: cuando el alumno afirma con seguridad "yo no hice X", asumir buena fe y buscar explicación externa antes de sugerir olvido.

## Bloque 8 — Anatomía del comando AWS CLI

Introducido al preguntar el alumno "descríbeme las opciones que pones en el comando".

### Estructura universal

```
aws <servicio> <operación> [--opciones...]
```

Aplicado a `aws ec2 describe-vpcs --vpc-ids vpc-0d36eccf71cddeda7`:

- `aws` — binario CLI. Punto de entrada a todos los servicios AWS.
- `ec2` — **servicio/namespace**. VPCs viven bajo `ec2` porque históricamente EC2 fue el primer servicio de cómputo y las VPCs nacieron para dar red a las instancias EC2.
- `describe-vpcs` — **operación**. Convención de naming en AWS CLI:
  - `describe-*` → lee recursos, devuelve JSON detallado (`describe-instances`, `describe-vpcs`, `describe-db-instances`).
  - `list-*` → lista recursos, típicamente solo IDs o nombres (`list-buckets`, `list-users`).
  - `get-*` → obtiene un valor concreto o metadata (`get-caller-identity`).
  - `create-*`, `delete-*`, `modify-*` → operaciones de escritura.
- `--vpc-ids` — flag/opción. Filtro para obtener info solo de VPCs concretas. Acepta múltiples IDs separados por espacio.
- `vpc-0d36eccf71cddeda7` — valor del flag.

### Flag implícito: `--region`

No aparece en el comando pero está actuando. Configurado en `~/.aws/config` (`eu-west-1`). Sin región por defecto, comando fallaría con `You must specify a region`.

Recursos regionales: VPC, EC2, RDS, subnets. Excepciones globales: IAM, Route 53, CloudFront, S3 (nombre global, contenido regional).

### Flags universales útiles

- `--query "expresión JMESPath"` — filtra respuesta JSON. Ejemplo: `--query "Vpcs[0].CidrBlock"`.
- `--output json|text|table|yaml` — formato salida.
- `--profile <nombre>` — perfil AWS distinto del default.
- `--no-cli-pager` — evita `less`.

Combinación útil en scripts:

```bash
aws ec2 describe-vpcs \
  --query "Vpcs[?Tags[?Key=='Name' && Value=='task-manager-vpc']].VpcId" \
  --output text
```

Devuelve solo el VPC ID buscando por tag Name, sin JSON de por medio.

## Bloque 9 — Escritura del HCL del VPC, errores y correcciones

### Primer intento del alumno

```hcl
provider "aws" {
  region = "eu-west-1"
}
resource "aws_vpc" "main" {
  tags = {
  [
  {
    "Key" : "Name",
    "Value" : "task-manager-vpc"
  }
  ]}
  cidr_block = "10.0.0.0/16"
}
# Trivial S3 bucket to exercise the full init/plan/apply/destroy lifecycle end-to-end.
# ...
```

### Tres errores identificados

1. **Sintaxis de `tags` monstruosamente mal**. Mezcla representación JSON de la respuesta de `describe-vpcs` con sintaxis HCL. En HCL un mapa se escribe con `=`, no con `:`, sin comillas en clave si es identificador válido, sin arrays anidados.

   Corrección directa (no ejercicio Socrático — es sintaxis pura del lenguaje, no razonamiento):
   ```hcl
   tags = {
     Name = "task-manager-vpc"
   }
   ```

   **Por qué AWS lo devuelve como array `[{Key, Value}, ...]` y HCL lo acepta como mapa**: la API de AWS es verbose por consistencia con otros servicios; el provider Terraform traduce entre el mapa HCL (ergonómico) y el array de la API (burocrático) automáticamente.

2. **Comentario huérfano de S10**. Sobre el bucket `aws_s3_bucket.test` eliminado al cierre de S10. Borrado.

3. **Bloque `provider "aws"` en `main.tf` — decisión de estilo**. Verificación con `cat versions.tf` confirmó que NO estaba duplicado (versions.tf solo tenía `terraform { }`). Decisión aplicada: mover `provider "aws"` a `versions.tf` justo debajo del cierre de `terraform { }`, según convención pro:
   - `versions.tf` → `terraform { }` + `provider "xxx" { }`.
   - `main.tf` → recursos.
   - Ventaja: `main.tf` que solo contiene recursos escala bien; mezclarlo con config del provider se vuelve incómodo cuando pasas de 3 a 30 recursos.

### Cuarto error tras primera corrección: valor sin comillas

```hcl
Name = task-manager-vpc
```

`task-manager-vpc` es string literal, no identificador HCL. Corrección: `Name = "task-manager-vpc"`.

**Regla mental**: en HCL cualquier valor texto entre humanos (nombres, descripciones, ARNs, endpoints, IDs de AWS) va entre comillas dobles. Los únicos valores SIN comillas son números (`5432`), booleanos (`true`), referencias a otros recursos (`aws_vpc.main.id`), variables (`var.region`), expresiones (`local.tags["Owner"]`).

## Bloque 10 — Verificación sintáctica: `fmt` + `validate`

```bash
tole@TxM:~/proyectos/cloud-roadmap/infra$ terraform fmt
tole@TxM:~/proyectos/cloud-roadmap/infra$ terraform validate
Success! The configuration is valid.
```

Observaciones:
- **`terraform fmt` es idempotente y silencioso**. Si el fichero ya está formateado, no imprime nada. Si hubiera reformateado, imprimiría el nombre del fichero modificado. Cero output = todo perfecto. Distinto a Prettier o Black que suelen ser más verbosas.
- **`terraform validate`** verifica que el HCL es sintácticamente correcto y que los recursos referenciados existen en el schema del provider. No toca AWS ni state.

HCL en verde antes de `import`. Regla operativa: **nunca ejecutar `import` sin `validate` previo en verde**.

## Bloque 11 — Import empírico del VPC con observatorio del `.tflock`

Aplicando regla de S11: "cuando un mecanismo tenga ciclo de vida efímero, diseñar ejercicio que permita observarlo en el momento intermedio".

### Setup: dos terminales

**Terminal 2 (observatorio)** lanzada primero:

```bash
while true; do
  echo "--- $(date +%H:%M:%S.%N) ---"
  aws s3 ls s3://toleflaco-terraform-state-2026/envs/dev/
  sleep 0.3
done
```

Ventaja de esta variante sobre `watch -n 0.5`: registro histórico con timestamps precisos que se copia limpio a bitácora.

**Terminal 1 (operación)**:

```bash
terraform import aws_vpc.main vpc-0d36eccf71cddeda7
```

### Predicciones del alumno

| # | Pregunta | Predicción | Realidad | ✓/✗ |
|---|----------|-----------|----------|-----|
| 1 | ¿Aparece `.tflock`? ¿Cuánto? | "Pocos segundos" | Visible ~3s | ✓ |
| 2 | Output del import | "Confirmación de éxito con lo escrito en state" | Confirmación de éxito, no muestra atributos | ✓ (esencial) |
| 3 | Serial y resources post-import | "Serial mayor, resources con la VPC dentro" | Serial 3, resources[0] = aws_vpc.main | ✓ |
| 4 | Plan inmediato post-import | "Diff con todo lo que hay por importar (RDS, SG, RTs, etc.)" | `No changes` | ✗ |

### Evidencia empírica capturada

**Terminal 2** (extracto):
```
--- 08:56:44.095202010 ---
2026-08-16 07:55:11        181 terraform.tfstate
2026-08-17 08:56:45        236 terraform.tfstate.tflock
--- 08:56:45.229049466 ---
2026-08-16 07:55:11        181 terraform.tfstate
2026-08-17 08:56:45        236 terraform.tfstate.tflock
--- 08:56:47.637730640 ---
2026-08-17 08:56:48       1981 terraform.tfstate
```

Observaciones:
- `.tflock` visible ~3s (08:56:44 – 08:56:47).
- `terraform.tfstate` pasa de **181 bytes** a **1981 bytes** (~11x). Salto empírico de tamaño = evidencia de que el array `resources` ahora tiene contenido.
- Timestamp del state actualizado al momento del import.

**Terminal 1**:
```
aws_vpc.main: Importing from ID "vpc-0d36eccf71cddeda7"...
aws_vpc.main: Import prepared!
aws_vpc.main: Refreshing state... [id=vpc-0d36eccf71cddeda7]

Import successful!
```

### Corrección de P4 y consecuencia conceptual

P4 fallada revela modelo mental incorrecto sobre lo que compara `terraform plan`. **Terraform no compara HCL contra AWS directamente**. Compara HCL contra state. Y el state actual solo contiene el VPC (recién importado). Los demás recursos AWS (RDS, SG, RTs, etc.) NO están en state → no existen para Terraform → no aparecen en el diff.

**Frase ⭐⭐⭐ fijada**: "Terraform solo ve lo que le declaras. Un `plan` con `No changes` no significa que tu infra esté completa en HCL — significa que lo que has declarado hasta ahora coincide con la realidad. La cuenta AWS puede tener 100 recursos huérfanos y Terraform seguirá diciendo `No changes` felizmente."

### Implicaciones operativas

1. **Adopción brownfield progresiva es viable**. Puedes importar VPC hoy, subnets mañana, RDS pasado mañana. Cada plan intermedio dirá `No changes` para lo importado.
2. **"Unmanaged resources"** = infra que vive en AWS pero no está bajo control de ningún state. Perfectamente legal.
3. **Herramientas para detectar unmanaged**: `driftctl` (deprecated pero útil de conocer), `firefly`, `cloudquery`. Escanean cuenta AWS entera y reportan qué no está en ningún state.
4. **`terraform plan` NUNCA alertará de recursos faltantes por importar**. El checklist lo lleva el operador.

**Sugerencia práctica**: al arrancar cada sesión de import, abrir fichero `SesionX-Import-Checklist.md` con lista de recursos a importar. Ir tachando.

## Bloque 12 — Verificación post-import

### `terraform state list` + `terraform state show`

```bash
terraform state list
# → aws_vpc.main

terraform state show aws_vpc.main
```

Output revela atributos que Terraform leyó de AWS y guardó en state pero que NO están en HCL:

```
enable_dns_hostnames = true
enable_dns_support   = true
default_network_acl_id = "acl-0b98db6566d82b15b"
default_route_table_id = "rtb-01af7b83e0427bbba"
main_route_table_id    = "rtb-01af7b83e0427bbba"
default_security_group_id = "sg-01f966cb344439254"
region                 = "eu-west-1"
```

Todos son **Computed** o **Optional+Computed**. Terraform los leyó, los guardó, pero como no están en HCL y coinciden con defaults, `plan` no ve diff.

### Cara oscura de omitir defaults

Si alguien cambia por consola `enable_dns_hostnames` a `false`, el próximo `plan` NO detectará el cambio porque el HCL no declara ese atributo.

**Trade-off consciente aceptado por el alumno para el proyecto de aprendizaje**: HCL mínimo → menor detección de drift en atributos no declarados. Anotado en bitácora como decisión, no como olvido.

Para proyecto profesional con auditoría/compliance sería obligatorio declarar explícitamente.

### `serial` y `lineage` verificados con jq

```bash
aws s3 cp s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate /tmp/state-post-import.json
jq '.serial, .lineage, (.resources | length)' /tmp/state-post-import.json
```

Resultado:
- `serial`: **3**
- `lineage`: **"6d8b3dbd-a903-d71a-8fd9-e6d84798dde2"** — mismo lineage que al cierre de S11 (continuidad preservada, no hubo re-init con lineage nuevo).
- `.resources | length`: **1**

### `terraform plan` = `No changes`

```
aws_vpc.main: Refreshing state... [id=vpc-0d36eccf71cddeda7]

No changes. Your infrastructure matches the configuration.
```

Ciclo brownfield completo para VPC:
1. HCL correcto escrito ✓
2. `terraform import` exitoso ✓
3. `terraform plan` = `No changes` ✓ → HCL fielmente describe realidad AWS.

Un recurso importado. Faltan bastantes.

## Bloque 13 — Realidad descubierta: 4 subnets, no 2

Al ejecutar `aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0d36eccf71cddeda7"` para preparar S12-B, descubierto:

**El VPC tiene 4 subnets, no 2 como asumía el prompt de continuación de S11**:

| Subnet ID | AZ | CIDR | Tag Name |
|---|---|---|---|
| subnet-00571f5c84fc414d3 | eu-west-1a | 10.0.128.0/20 | task-manager-subnet-private1-eu-west-1a |
| subnet-0af15e9e05f81098f | eu-west-1b | 10.0.144.0/20 | task-manager-subnet-private2-eu-west-1b |
| subnet-0af881e02d4a9322b | eu-west-1a | 10.0.0.0/20 | task-manager-subnet-public1-eu-west-1a |
| subnet-066074bd45c1a46f6 | eu-west-1b | 10.0.16.0/20 | task-manager-subnet-public2-eu-west-1b |

2 privadas + 2 públicas. Distribuidas en dos AZs (1a, 1b).

### Consecuencia para S12-B

El bloque de red va a ser mayor de lo estimado:
- 4 `aws_subnet`.
- 1 `aws_internet_gateway`.
- Probablemente 2 `aws_route_table` (una para privadas, una para públicas).
- 4 `aws_route_table_association` (una por subnet).
- ≥1 `aws_route` (la del IGW en la RT pública).

Solo la red = ~12 recursos.

### Prompt de continuación de S11 tenía info incompleta

No indicaba número de subnets. Regla operativa: **al escribir prompts de continuación, verificar con AWS CLI el estado real de recursos en lugar de asumir memoria de la sesión anterior**. Añadir bloque específico "Realidad AWS verificada" al final de cada prompt de continuación futuro.

## Bloque 14 — Recalibración de estimación temporal

### Estimación original vs realidad

- **Original (prompt de continuación)**: ~2h honestas para 9 pasos.
- **Real**: 2h15 para 1 recurso importado + conceptual denso.

### Desglose del tiempo real por recurso

Por cada recurso brownfield con vía imperativa clásica:
- Descubrir realidad con `aws ec2 describe-*` (~2 min).
- Clasificar atributos Grupo A/B/C (~5 min).
- Escribir HCL (~5 min).
- `terraform fmt` + `validate` (~1 min).
- `terraform import` (~1 min).
- `terraform plan` + iterar HCL si diff (~5-20 min).

Total ≈ **15-20 min por recurso simple** (VPC, subnet, IGW).
Total ≈ **25-40 min por recurso complejo** (EC2 con múltiples atributos, RDS con sensitive+ignore_changes, SG con reglas separadas).

### Estimación pendiente honesta para S12-B (y S12-C)

- 4 subnets: ~30 min (2ª-4ª más rápidas por patrón repetido).
- IGW: ~15 min.
- 2 RTs + 4 associations + 1 route: ~45 min.
- 2 SGs + reglas: ~40 min.
- S3 bucket + sub-recursos (versioning, encryption): ~30 min.
- IAM Role + Instance Profile: ~20 min.
- EC2 con Instance Profile: ~30 min.
- RDS con deletion protection: ~30 min.
- VPC Endpoint Gateway: ~15 min.
- Plan global final + commit + push + ADRs + bitácora: ~30 min.

**Total realista pendiente: ~4h**. Probablemente hay que dividir en S12-B (~2h30) y S12-C (~1h30).

### Regla operativa emergente

**Las estimaciones de adopción brownfield se calculan por recurso individual, no por lote**. Fórmula:

```
Estimación_brownfield = N_recursos × (20 min si simples | 40 min si complejos)
```

Para infra ≥10 recursos, evaluar switching a vía declarativa `import { }` + `-generate-config-out` para ahorrar tiempo. Trade-off: menos ejercicio pedagógico, más productividad.

### Corrección meta

Estimación mal calibrada de partida — de Claude, no del alumno. Reconocida al cierre en el momento en que el alumno verbalizó "se van a hacer largos todos los imports". Regla: **cuando el alumno reporta fatiga o desproporción de tiempo, es señal fiable de recalibración, no bandera de queja a suavizar**.

## Bloque 15 — Cierre S12-A

### Commit final

```bash
git add infra/
git commit -m "feat(infra): import task-manager VPC into Terraform state

Imported existing VPC vpc-0d36eccf71cddeda7 into Terraform management.
HCL declares only cidr_block and Name tag. Other attributes left as
provider defaults, accepting reduced drift detection on undeclared
computed attributes as conscious trade-off for HCL minimalism.

State migration successful: terraform plan shows No changes.

---

Importada la VPC existente vpc-0d36eccf71cddeda7 al state de Terraform.
El HCL declara solo cidr_block y el tag Name. Otros atributos quedan
con los defaults del provider, aceptando menor deteccion de drift en
atributos computed no declarados como decision consciente a cambio de
un HCL mas minimalista.

Migracion de state exitosa: terraform plan muestra No changes."

git push
```

Commit hash: `75b9855`.

### Parada de recursos costosos

```bash
aws rds stop-db-instance --db-instance-identifier task-manager-db
aws ec2 stop-instances --instance-ids i-031f9ec92618edea1
```

Verificación:
```
| task-manager-db |  stopping  |
| i-031f9ec92618edea1 |  stopping  |
```

Ambos en `stopping`. Al final de la sesión estarán en `stopped`.

### Estado del observatorio

Terminal 2 (`while true`) cerrada con `Ctrl+C` tras verificación.

## Frases ⭐⭐⭐ locked de Sesión 12-A

1. **"1.15.8 se lee 'uno-quince-ocho'. No es decimal. Por eso 1.15 > 1.5, porque 15 > 5 como enteros. Semver son enteros separados por puntos, siempre."**
2. **"Terraform solo ve lo que le declaras. Un `plan` con `No changes` no significa infra completa — significa que lo declarado hasta ahora coincide con realidad. La cuenta AWS puede tener 100 recursos huérfanos y Terraform sigue diciendo No changes."**
3. **"Terraform no te protege de defaults implícitos. Un cambio de default entre versiones del provider puede convertirse en un `-/+ destroy and replace` silencioso si no lees el plan."**
4. **"Atributos Computed no se declaran no porque AWS los prohíba — porque el schema del provider los marca read-only. El error salta en `plan` antes de tocar API AWS."**
5. **"Adopción brownfield con `terraform import` clásico: 15-40 min por recurso. Si son ≥10, evaluar vía declarativa con `import { }` + `-generate-config-out`."**
6. **"Regla profesional de defaults en HCL: declara explícitamente los críticos (encryption, versiones, tenancy, ForceNew implícitos). Omite los inocuos. Trade-off: mayor detección de drift vs HCL más limpio."**
7. **"HCL primero, import después, plan para verificar. Criterio de éxito no es que el import salga bien — es que el plan posterior salga No changes."**
8. **"Terraform NO compara HCL contra AWS directamente. Compara HCL contra state. Import lee AWS y escribe en state; después plan compara HCL vs state (que ahora refleja AWS)."**
9. **"En HCL cualquier valor texto entre humanos va entre comillas dobles. SIN comillas solo: números, booleanos, referencias a recursos, variables, expresiones."**
10. **"AWS RDS rearranca automáticamente instancias paradas tras 7 días. Trampa de facturación documentada. Verificar estado con AWS CLI al cerrar cada sesión."**
11. **"Cuando el alumno reporta desproporción de tiempo, es señal fiable de recalibración de estimación, no bandera de queja a suavizar."**
12. **"`terraform fmt` es idempotente y silencioso. Cero output = fichero ya en estilo canónico."**
13. **"`aws <servicio> <operación> [--opciones...]` es la estructura universal de AWS CLI. `describe-*` lee, `list-*` lista IDs, `get-*` obtiene valor concreto, `create/delete/modify-*` escriben."**
14. **"Los conceptos empíricos consolidados en una sesión requieren relectura de notas cada 48-72h hasta que salgan sin pensar."**

## Recursos AWS al final de Sesión 12-A

- **S3 Bucket** `toleflaco-task-manager-uploads-2026` — vivo, con 3 objetos. **Pendiente de import en S12-B**.
- **S3 Bucket** `toleflaco-terraform-state-2026` — vivo, con state (serial=3, resources=1). **NO importar** (bootstrap manual documentado con `ManagedBy: manual-bootstrap`).
- **IAM Role** `task-manager-ec2-role` + **Instance Profile** — vivos. **Pendiente de import en S12-B**.
- **EC2** `task-manager-ec2` (`i-031f9ec92618edea1`) — **stopping/stopped**. Nueva Public IP al arrancar la próxima vez. **Pendiente de import en S12-B**.
- **RDS** `task-manager-db` — **stopping/stopped**. PostgreSQL 18.3, db.t4g.micro, deletion protection ON. **Pendiente de import en S12-B**. **Trampa 7 días activa**: rearranque automático el 24 ago si no se toca antes.
- **VPC custom** `task-manager-vpc` (`vpc-0d36eccf71cddeda7`) — vivo, **IMPORTADO** ✓.
- **Subnets (×4)** — vivos. **Pendientes de import en S12-B**.
  - subnet-00571f5c84fc414d3 (private, 1a, 10.0.128.0/20)
  - subnet-0af15e9e05f81098f (private, 1b, 10.0.144.0/20)
  - subnet-0af881e02d4a9322b (public, 1a, 10.0.0.0/20)
  - subnet-066074bd45c1a46f6 (public, 1b, 10.0.16.0/20)
- **IGW** — vivo. **Pendiente de import en S12-B**.
- **Route Tables (probablemente ×2)** + associations + routes — vivos. **Pendientes de import en S12-B**.
- **Security Groups (×2)** (SG EC2, SG RDS) — vivos. **Pendientes de import en S12-B**.
- **VPC Endpoint Gateway** `vpce-0122ecf0ee7226fb9` para S3 — vivo. **Pendiente de import en S12-B**.
- **MongoDB Atlas M0** — vivo, free. **NO gestionar por Terraform** (proveedor distinto, fuera de scope). IP allow list actualizada con IP pública actual de EC2.
- **DynamoDB** `terraform-state-lock` — **eliminada al cierre de S11** (huérfana tras migración a `use_lockfile`). No importar.

**State Terraform**: serial=3, lineage=6d8b3dbd-a903-d71a-8fd9-e6d84798dde2 (continuidad desde S11), resources=1 (aws_vpc.main).

## Lecciones operativas

1. **Los conceptos empíricos se desdibujan en 48-72h sin uso**. Warmup S12-A demostró que dos conceptos aterrizados empíricamente en S11 (`.tflock` como objeto vs `use_lockfile` como config; distinción Ctrl+C vs kill -9 no cubierta) se han desdibujado o nunca aterrizaron. Fijar como hábito: relectura de notas de la sesión anterior antes del warmup, no como sustituto del warmup sino como precondición.

2. **La confusión semver es persistente**. Falló en S10, vuelve a fallar en S12-A. Requiere refuerzo directo cada vez que aparezca — no dejar pasar. Añadir a la lista corta de conceptos-que-requieren-vigilancia junto con persistencia del state.

3. **La estimación de tiempo para tareas repetitivas debe hacerse por unidad, no por lote**. La estimación "2h para 9 imports" es fundamentalmente incorrecta. Correcta: "15-40 min por recurso × 12 recursos = 3-8h, divisible en múltiples sesiones". Aplicar esta lógica desde el prompt de continuación siguiente.

4. **CloudTrail es la fuente de verdad cuando la memoria falla**. La sospecha inicial "puede que fuera olvido del alumno" era mala hipótesis. CloudTrail resolvió el asunto en 30 segundos. Regla: ante discrepancia entre memoria y realidad AWS, verificar con CloudTrail antes de asumir causa.

5. **Verificación empírica con dos terminales es rutina, no lujo**. Aplicado hoy con `.tflock` durante import. Va a repetirse en todos los imports de S12-B: patrón consolidado. Coste ínfimo (30 segundos preparar), evidencia contundente.

6. **HCL primero, import después, plan para verificar** es la única regla operativa que importa en adopción brownfield. Todo lo demás son detalles. Fijada como frase ⭐⭐⭐.

7. **Cuando el alumno hace pushback sobre tiempo o alcance, es dato fiable**. "Se van a hacer largos todos los imports" fue el momento de decidir cerrar S12-A. Ignorarlo habría degradado la sesión. Regla operativa: **el alumno es co-piloto del ritmo, no pasajero**.

8. **Convención pro sobre organización de ficheros Terraform importa desde el día uno**: `versions.tf` (terraform + providers), `main.tf` (recursos), y a futuro `variables.tf`, `outputs.tf`, `locals.tf`. Alumno la ha adoptado ya. Un `main.tf` que solo contiene recursos escala; uno que mezcla config del provider se vuelve incómodo con >30 recursos.

## Deuda arrastrada actualizada

### Deuda nueva (Sesión 12-A)

- **9 recursos pendientes de import** para completar adopción brownfield: 4 subnets, IGW, 2 RTs + associations + routes, 2 SGs + reglas, S3 uploads + sub-recursos, IAM Role + Instance Profile, EC2, RDS, VPC Endpoint. Planificados para S12-B (y probablemente S12-C).
- **ADRs pendientes reservados para tras cerrar bloque Terraform**:
  - ADR-A2: Terraform vs CloudFormation vs CDK (redactar al terminar S12-B/C).
  - ADR-A6: DynamoDB locking vs S3 native locking en backend Terraform (redactar en cierre S12).
  - ADR-A7: `terraform import` vs recrear infra desde cero para adopción brownfield (redactar en cierre S12).
  - ADR-A8 (nuevo candidato): declarar defaults críticos en HCL vs aceptar defaults del provider — trade-off drift detection.
- **Deuda pedagógica sobre semver**: recaída por 2ª vez (S10 + S12-A). Añadir a lista de vigilancia junto con persistencia del state.
- **Deuda pedagógica menor sobre distinción Ctrl+C vs kill -9 en Terraform**: cubierta hoy por primera vez. Verificar en warmup de S12-B que ha aterrizado.

### Deuda arrastrada de sesiones anteriores (siguen abiertas)

- **README de portfolio pendiente actualizar** con S3 integration + presigned URLs + VPC Endpoint. Acumulada desde S6-S8.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2**. Elastic IP fija o Atlas VPC Peering.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location**. Deuda REST menor.
- **`postgresql-client` en EC2 en v16 vs server v18**.
- **Billing access para IAM user `tole`** — activar desde root.
- **Verificación empírica del tráfico por VPC Endpoint** — postpuesta al módulo Observabilidad.
- **Concepto de `tags_all` y `default_tags` a nivel provider** anticipado pero no ejercitado — programado para S12-B o módulos.

### Deudas cerradas hoy

- **Concepto de adopción brownfield vs greenfield**: cerrado con vocabulario, trade-offs y regla operativa de la industria.
- **Anatomía del comando `terraform import`**: cerrada con sintaxis, tres escenarios, cadena mental HCL↔state↔realidad.
- **Vocabulario schema Required/Optional/Computed**: cerrado con consecuencias operativas (error de schema vs error de AWS).
- **Peligro de defaults implícitos en HCL**: cerrado con tres capas de protección.
- **Modelo mental "plan compara HCL vs AWS"**: corregido a "plan compara HCL vs state (que refleja AWS post-import)".
- **Anatomía de comandos AWS CLI**: cubierta con estructura universal + convenciones de naming + flags útiles.
- **Trampa de auto-rearranque RDS a 7 días**: descubierta empíricamente con CloudTrail. Regla de checklist final añadida.

## Para retomar en Sesión 12-B

**Warmup obligatorio (~15 min)** — sin abrir diario S12-A ni S11:

1. Qué es la adopción brownfield y por qué se prefiere sobre recrear infra desde cero. Regla operativa de la industria.
2. `<address>` vs `<id>` en `terraform import`. De dónde viene cada uno. Escribir el comando completo para importar la subnet privada 1a (`subnet-00571f5c84fc414d3`) con address `aws_subnet.private_1a`.
3. Qué es un atributo Computed y por qué NO se declara en HCL. Qué error salta si intentas declararlo. Diferencia con un atributo AWS que devuelve error de API.
4. Si en el HCL omites un atributo Optional que tiene default del provider, y en una versión futura el provider cambia el default, qué pasa en el próximo plan. Con qué tres capas te proteges.
5. Ctrl+C limpio en el prompt yes de un apply vs kill -9. Estado del `.tflock` en cada caso. Solución en el segundo.

**Objetivo S12-B**: importar 4 subnets + IGW + Route Tables + associations + routes. Total estimado ~2h. Si sobra tiempo, arrancar SGs.

**Objetivo S12-C**: SGs + S3 bucket uploads + IAM Role + Instance Profile + EC2 + RDS + VPC Endpoint + plan global final + commit + push + ADRs + bitácora final. Total estimado ~2h.

**Regla obligatoria**: crear al arrancar `Sesion12-Import-Checklist.md` con la lista completa de recursos a importar. Ir tachando. Al cerrar S12-C se cierra el ciclo brownfield.

**Refuerzo pedagógico obligatorio antes de arrancar S12-B**: releer notas de S12-A. Especialmente:
- Frases ⭐⭐⭐ #4, #7, #8 (Computed, HCL primero, plan compara HCL vs state).
- Bloque 4 (schema Required/Optional/Computed).
- Bloque 5 (peligro de defaults implícitos).
- Bloque 11 (por qué el plan post-import mostró No changes en lugar de diff con RDS/SG/etc.).

**Alternativa vespertina ligera si baja energía**: sesión de repaso conceptual sin código nuevo. Alumno narra los 14 frases ⭐⭐⭐ de hoy en sus palabras, Claude pregunta nuances, gaps identificados. Fijo o Sunday-slot.

## Meta-observaciones de método

1. **Warmup con 1.5/5 aciertos limpios reveló zona de dominio frágil**: el modelo mental "state persistente tras destroy" (locked por primera vez, cerrado); en cambio, "distinción config del mecanismo vs objeto físico del lock" (fallada) muestra fragilidad. Patrón coherente con Meta-obs #4 de S11 (dominio operativo sólido, dominio conceptual sobre mecanismos frágil). Requiere: releer notas cada 48-72h, no depender de memoria pasiva.

2. **Estimación de tiempo mal calibrada de partida — de Claude, no del alumno**. Corregida abiertamente al cierre. Regla derivada: **cuando el operador reporta desproporción de tiempo, actuar. No suavizar, no minimizar, recalibrar y explicar**. Aplicado hoy en el momento en que el alumno verbalizó "se van a hacer largos todos los imports".

3. **Autoevaluación negativa del alumno ("si eres un pardillo como yo") fue oportunidad de corregir marco, no de dar ánimo**. Respuesta correcta: explicar las tres capas de protección operativas (version pinning + lectura del plan + policy engines) que hacen innecesaria la memorización enciclopédica. Confirma regla: **la autoetiqueta pardillo/no-pardillo es marco erróneo. Los ingenieros senior no memorizan atributos; leen el plan**.

4. **Verificación con CloudTrail resolvió sospecha errónea en 30 segundos**. Diagnóstico inicial "probable olvido del alumno" era mala hipótesis. Retirado explícitamente ante evidencia. **Regla derivada**: cuando el alumno afirma con seguridad "yo no hice X", asumir buena fe, verificar con logs antes de sugerir olvido.

5. **Corrección propia sin softening aplicada dos veces**: (a) diagnóstico inicial equivocado sobre la RDS ("probable observación errónea") — retirado; (b) estimación de tiempo original mal calibrada — reconocida y recalibrada. Efecto observado: refuerza confianza en método, no la daña.

6. **Prompt de continuación de S11 tenía dato incompleto**: no indicaba número de subnets. Regla derivada: **al escribir prompts de continuación, incluir bloque "Realidad AWS verificada con CLI" con estado real de recursos** en lugar de asumir memoria de sesión anterior.

7. **Cierre parcial S12-A con solo 1 recurso importado es decisión correcta, no fracaso**. Alternativa (intentar meter 3-4 más en la última media hora) habría degradado método. Regla derivada de S11 aplicada: **cuando el ritmo se descoloca, la respuesta correcta suele ser cortar y digerir, no acelerar para "cerrar hoy"**.

8. **Ratio de predicciones acertadas en el import: 3.5/4**. Predicciones sobre `.tflock` (aparece, dura pocos segundos), output del import (esencial), y estado post-import (serial y resources) — acertadas. Predicción sobre `plan` post-import (esperaba diff con recursos huérfanos, obtuvo No changes) — fallada por modelo mental erróneo sobre qué compara `plan`. Corrección oportuna, frase ⭐⭐⭐ #2 fijada.

9. **Deuda nueva hoy**: 1 pedagógica (semver recaída) + 1 técnica pequeña (Ctrl+C vs kill -9 primera exposición) + 9 recursos pendientes de import. Ratio deuda/entregado alto en recursos pendientes, aceptable dada recalibración honesta.

10. **Estimación de contexto al cierre**: ~65-70% del chat consumido. Prompt de continuación denso generado para S12-B. Sesión de tarde recomendada arrancar en chat nuevo con prompt inyectado.
