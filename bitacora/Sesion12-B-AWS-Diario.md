# Sesión 12-B — Import brownfield subnets privadas (parte 5 de la Sesión 5 oficial del roadmap)

**Fecha:** 17 agosto 2026
**Duración:** ~2h (~17:00 – 18:55, ventana vespertina desde casa de los gatos)
**Estado:** Parcial. Cierre S12-B con 2 subnets privadas importadas al state y `terraform plan` = `No changes` verificado en cada una. Scope pactado a mitad de sesión: solo 4 subnets + IGW (recalibración desde el prompt original que incluía RTs + associations). Alcance efectivo hoy: 2 subnets privadas. Pendiente en S12-C: 2 subnets públicas + IGW + 3 RTs + routes + associations + resto del ciclo brownfield. Recalibración confirmada respecto a S12-A: **30-35 min por subnet en el primer ejercicio guiado, ~15 min en la segunda por replicación de patrón**. IGW y recursos con anatomía distinta requerirán su propio tiempo — no asumir que "subnet ya cerrado = resto igual de rápido".

## Objetivo pedagógico

Continuar la adopción brownfield sistemática iniciada en S12-A. Cubrir en orden:

1. Warmup — validar consolidación de conceptos S12-A (brownfield, address/id, Computed, defaults + tres capas, Ctrl+C vs kill -9).
2. Descubrir realidad de IGW y Route Tables con `aws ec2 describe-*`. Corregir supuestos del prompt de continuación.
3. Import práctico de las 4 subnets con verificación `plan` = `No changes` tras cada una.
4. Import práctico del IGW.
5. Commit + push + bitácora.

Recalibración de scope aplicada durante la sesión al descubrir 4 RTs (no 2 como asumía el prompt) y al detectar sobrecarga cognitiva del alumno con conceptos no introducidos (Main RT, routes VPC Endpoint). Reencuadre: solo 4 subnets + IGW hoy. Alcance real cerrado: 2 subnets privadas + checklist inicial. Cierre respeta regla operativa de 2h y regla derivada de S12-A "cuando el ritmo se descoloca, cortar y digerir es mejor que acelerar para cerrar hoy".

## Bloque 1 — Warmup: repaso de conceptos de S12-A

Cinco preguntas de predicción antes de arrancar contenido nuevo, sin abrir diario de S12-A.

### Preguntas y desempeño

| # | Tema | Predicción del alumno | Realidad | Correcto |
|---|------|----------------------|----------|----------|
| 1 | Brownfield + regla operativa | "Import de recursos que hay en AWS ya creados, se prefiere porque no se para el servicio" | Confusión situación (brownfield) vs mecanismo (`terraform import`). Regla operativa no recordada. | Parcial |
| 2 | address vs id + comando import | Invertidos ("id es el que yo le doy, address es de AWS"). HCL escrito en vez de comando shell. | Correcto en segunda pasada tras corrección: `terraform import aws_subnet.private_1a subnet-00571f5c84fc414d3` | Parcial |
| 3 (crítica) | Computed | "Atributo que no se declara, viene de AWS como el id" | Fragmentario. Faltaba: por qué NO se declara (schema del provider marca read-only), qué error salta (`unconfigurable attribute` en `plan`), diferencia con error de API AWS. Refuerzo con ejemplo directo aplicado. Aterrizado en reformulación: "error de schema es local, no se conecta con AWS; error de API es en apply, ya conectado, más caro". | Aterrizado tras refuerzo |
| 4 (crítica) | Defaults + tres capas | "Puede dar +/- atributo Optional. Se subsana: leer el plan, policy engine, fijar versión del provider en versions.tf" | Correcto directo. Sin refuerzo necesario. Precisión menor añadida sobre símbolos reales (`~` update in-place vs `+/-`). | Correcto |
| 5 | Ctrl+C vs kill -9 | "Ctrl+C guarda state, kill -9 no. Primero desaparece, segundo queda bloqueado" | Concepto correcto en lo esencial. Matiz: en el prompt `yes` no hay nada que "guardar" (no hay operación en curso), Ctrl+C solo libera lock. Comando solución fallido: escribió `unlock-force UUID` en lugar de `force-unlock <LOCK_ID>`. | Parcial |

### Resultado global del warmup

**2 aciertos limpios + 3 parciales de 5**. Mejora respecto a S12-A (1.5/5). Las dos críticas (P3 Computed, P4 defaults + tres capas) aterrizadas. Ratio suficiente para arrancar imports sin refuerzo adicional.

### Errores nuevos identificados

- **Invertir `<address>` y `<id>`** en la sintaxis de `terraform import`. Corregido en directo. Regla mnemotécnica fijada: **address vive en Terraform, id vive en AWS**.
- **Nombre invertido `unlock-force` vs `force-unlock`**. Convención Terraform: verbo principal al final (`state list`, `state rm`, `workspace new`).
- **Aclaración de comunicación mía sobre "el provider de AWS está escrito en Go"**: alumno preguntó "¿AWS está programado en Go?". Ambigüedad mía. Distinción explícita añadida: AWS-plataforma es mezcla propietaria (Java, C++, Rust, opaco); `terraform-provider-aws` es open source en Go, mantenido por HashiCorp, es el que descarga `terraform init`. Cadena mental fijada: HCL → CLI Go → provider Go (con schema) → AWS API HTTPS+SigV4 → AWS backend opaco.

### Errores viejos NO recaídos

- **Persistencia del state tras destroy**: consolidada. Sin recaída.
- **Modelo mental "plan compara HCL vs state, no vs AWS"**: aplicado limpio durante el import de la 1a.

### Regla operativa confirmada de S12-A

Los conceptos empíricos consolidados en una sesión requieren relectura de notas cada 48-72h. Hoy S12-B ocurre el mismo día que S12-A por la tarde — no cuenta como incumplimiento (notas frescas). La próxima ventana (S12-C) sí exige relectura previa.

## Bloque 2 — Descubrimiento realidad AWS: IGW y Route Tables

Ejecución de dos comandos AWS CLI para conocer IDs reales antes de tocar HCL.

### Comando 1: IGW

```bash
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=vpc-0d36eccf71cddeda7"
```

**Predicción del alumno**: 2 IGWs (uno para privadas, uno para públicas).

**Realidad**: 1 IGW.

- ID: `igw-0ab423637224cab0c`
- Tag Name: `task-manager-igw`
- Attached a: `vpc-0d36eccf71cddeda7`, estado `available`.

### Concepto derivado — 1 VPC = máximo 1 IGW

Restricción del propio servicio AWS, no convención. Las subnets privadas no se conectan a IGW por definición. **La diferencia público/privado se hace a nivel de Route Table**, no a nivel de IGW. Una RT con default route a IGW → subnet(s) asociada(s) es "pública". Una RT sin ese default → "privada".

### Comando 2: Route Tables

```bash
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-0d36eccf71cddeda7"
```

**Predicción del alumno**: 3 RTs (1 pública + 2 privadas, una por AZ).

**Realidad**: 4 RTs.

| ID | Tag Name | Rol | Asociaciones |
|---|---|---|---|
| `rtb-07f9363299f58b0b3` | `task-manager-rtb-public` | Pública compartida | pub 1a + pub 1b |
| `rtb-0be3472cd9db77b55` | `task-manager-rtb-private1-eu-west-1a` | Privada 1a | priv 1a |
| `rtb-09250fc195ff54f09` | `task-manager-rtb-private2-eu-west-1b` | Privada 1b | priv 1b |
| `rtb-01af7b83e0427bbba` | (sin tag) | **Main RT** — fallback silencioso | ninguna subnet |

### Concepto derivado — Main Route Table

**Toda VPC tiene una Main RT desde el momento cero**. AWS la crea automáticamente al crear cualquier VPC como red de seguridad: si aparece una subnet nueva sin RT asociada explícitamente, hereda la Main. En este caso las 4 subnets tienen RT explícita, así que la Main no rutea nada real — pero existe.

Análoga conceptual: default implícito del servicio AWS, similar a los defaults del provider Terraform que vimos en P4 del warmup. Si no la declaras en HCL, sigue existiendo y actuando de fallback en AWS.

### Concepto derivado — Rutas locales vs no-locales

Cada RT tiene una route `10.0.0.0/16 → local`. NO se importa. La crea AWS automáticamente al crear la RT y no puede modificarse ni borrarse. Es implícita del servicio, no una entidad Terraform.

Las rutas que sí se importan (o se declaran) son las no-locales: default hacia IGW (`0.0.0.0/0 → igw-...`), prefix list del S3 Gateway Endpoint (`pl-6da54004 → vpce-...`), rutas hacia NAT Gateway, VPC Peering, etc.

### Descubrimiento no planificado — rutas del VPC Endpoint

Cada una de las 3 RTs con subnets asociadas tiene una route `pl-6da54004 → vpce-0122ecf0ee7226fb9`. Esas rutas **las crea automáticamente el propio `aws_vpc_endpoint`** cuando en HCL declaras `route_table_ids = [pub, priv1, priv2]`. Se recomienda **no importarlas como `aws_route` explícitas** — dejar que el recurso VPC Endpoint las adopte en S12-C.

## Bloque 3 — Recalibración de scope a mitad de sesión

### Situación

Tras ejecutar los dos `describe-*`, ofrecí al alumno tres decisiones abiertas de golpe (Main RT sí/no, routes del VPC Endpoint modelo A/B, alcance realista para hoy A/B/C) más una tabla "Realidad reconstruida" con 4 RTs, IDs, tags, associations y routes. Vocabulario nuevo sin introducción explícita: Main RT, rutas locales, prefix list del VPC Endpoint.

### Feedback del alumno (verbatim)

> "no veo de donde lo sacas... vamos no sé como se lee el JSON... te soy sincero desde que has empezado has puesto '## Realidad reconstruida' me ha empezado a explotar la cabeza, es como si no supiera nada de lo que me estás hablando. La Decisión 2, no sé de lo que me estás hablando"

### Error de método (mío) reconocido

Rompí la regla socrática: introducir concepto → predecir → ejecutar → verificar. Salté a "leer el output y decidir" sin haber enseñado a leer el JSON de `describe-route-tables` (que es más denso que el de `describe-subnets`) y sin haber introducido Main RT como concepto.

Regla operativa derivada nueva de S12-B:

> **Cuando el alumno diga "me explota la cabeza" o equivalente, parar, reconocer el error de método sin softening, y reencuadrar recortando scope. No es un momento para tranquilizar — es un momento para corregir el ritmo.**

### Reencuadre aplicado

- Scope pactado: **solo 4 subnets + 1 IGW hoy**. Todo lo demás (Main RT, RTs, routes, associations, SGs, S3, IAM, EC2, RDS, VPC Endpoint) → S12-C o más adelante.
- Decisión 2 (VPC Endpoint routes): archivada, se retoma en S12-C con marco mental introducido primero.
- Aprender a leer JSON de RTs: pospuesto a S12-C, cuando toquen las RTs y sea el momento didáctico correcto.
- Recalibración de tiempo con nuevo scope: ~2h 10min desde ese momento. Encaja en ventana hasta las 19h.

## Bloque 4 — Creación del checklist

Regla operativa OBLIGATORIA del prompt: crear `Sesion12-Import-Checklist.md` al arrancar.

### Confusión (mía) reconocida

Nombré el fichero dos veces sin haberlo introducido en esta sesión. El alumno lo señaló: "esto de donde lo sacas??? es la segunda vez que lo nombras... que hago ahora?". Reconocido como fallo de comunicación — el nombre venía del prompt de continuación (contexto mío), no de algo pactado en la sesión.

### Ubicación decidida

`bitacora/Sesion12-Import-Checklist.md`. Es artefacto de proceso, no código de infra. Vive con los diarios. Al cerrar el ciclo brownfield se renombrará a `Sesion12-Import-Checklist-CERRADO.md`.

### Consolidación operativa

- `touch` sobre fichero existente **NO modifica contenido** — solo actualiza timestamp. Alumno lo tenía mal ("añade al final") — confusión con `>>` de shell redirection.
- Tabla mental fijada:
  - `touch f.md` → crea vacío / actualiza timestamp.
  - `echo "x" > f.md` → crea con "x" / **sobrescribe** (peligroso).
  - `echo "x" >> f.md` → crea con "x" / añade al final.
- Convención Unix "no news is good news": `touch`, `cp`, `mv`, `rm`, `chmod`, `mkdir` son silenciosos en caso de éxito.

### Commit inicial del checklist

- Hash: `37eca42`
- 1 fichero, 30 inserciones.
- Modo permisos `100644` (`-rw-r--r--`) — fichero normal.

## Bloque 5 — Primera subnet como ejercicio guiado completo

Ciclo completo con verificaciones didácticas. **Este es el patrón que se replicará en todas las subnets posteriores**.

### Paso 1: verificar realidad AWS

```bash
aws ec2 describe-subnets --subnet-ids subnet-00571f5c84fc414d3
```

Output JSON leído campo a campo. Tres categorías de campos identificadas:

**Categoría 1 — atributos que declaras en HCL** (Required u Optional):
`VpcId`, `CidrBlock`, `AvailabilityZone`, `MapPublicIpOnLaunch`, `AssignIpv6AddressOnCreation`, `Tags`.

**Categoría 2 — Computed** (AWS los genera, no se declaran):
`SubnetId`, `SubnetArn`, `OwnerId`, `State`, `AvailableIpAddressCount`, `AvailabilityZoneId`, `DefaultForAz`.

**Categoría 3 — atributos con default del provider que coincide con AWS**:
`MapCustomerOwnedIpOnLaunch: false`, `EnableDns64: false`, `Ipv6Native: false`, `PrivateDnsNameOptionsOnLaunch`, `BlockPublicAccessStates`, `Ipv6CidrBlockAssociationSet: []`.

### Contradicción (mía) sobre `map_public_ip_on_launch` cazada por el alumno

En un primer momento sugerí "no hace falta declarar `map_public_ip_on_launch` porque el default del provider coincide con AWS". Antes había puesto ese atributo en Categoría 1 (declarar). El alumno cazó la contradicción: "aquí está en la categoría 1, hay que declararlo no??".

### Corrección aplicada

**Regla operativa derivada nueva de S12-B**:

> **En brownfield real, declara todo atributo semánticamente significativo aunque coincida con el default del provider. La brevedad del HCL no es una virtud si sacrifica claridad o robustez.**

Razones:
- Blindaje ante cambios de default en versiones futuras del provider (P4 warmup).
- Detección de drift si alguien toca por consola AWS.
- Legibilidad para otro humano.

`map_public_ip_on_launch` es semánticamente significativo — define si la subnet es "pública" en sentido AWS. Se declara. `assign_ipv6_address_on_creation` es discutible (VPC IPv4-only) pero también válido declararlo por consistencia.

### Paso 2: escribir HCL

```hcl
resource "aws_subnet" "private_1a" {
  vpc_id                          = "vpc-0d36eccf71cddeda7"
  cidr_block                      = "10.0.128.0/20"
  availability_zone               = "eu-west-1a"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false

  tags = {
    Name = "task-manager-subnet-private1-eu-west-1a"
  }
}
```

**Error del alumno en primera pasada**: tab (`\t`) invisible entre las comillas y `eu-west-1a`. AWS lo habría rechazado. Corregido antes de ejecutar.

### Paso 3: `terraform validate`

```
Success! The configuration is valid.
```

Consolidación: `validate` valida sintaxis y schema **sin llamar a AWS**. Red de seguridad barata. Recuerda P3 warmup: error de schema es local e instantáneo.

### Paso 4: `terraform plan` pre-import

Output mostró `+ create` con lectura de 3 grupos de líneas:

- **Grupo A — declarados por el alumno**: `assign_ipv6_address_on_creation`, `availability_zone`, `cidr_block`, `map_public_ip_on_launch`, `vpc_id`, `tags`.
- **Grupo B — Computed (`(known after apply)`)**: `arn`, `availability_zone_id`, `id`, `owner_id`, `ipv6_cidr_block`, `ipv6_cidr_block_association_id`, `private_dns_hostname_type_on_launch`.
- **Grupo C — defaults del provider aplicados silenciosamente**: `enable_dns64`, `enable_resource_name_dns_a_record_on_launch`, `enable_resource_name_dns_aaaa_record_on_launch`, `ipv6_native`, `region`, `tags_all`.

Plan salió limpio para Grupo C porque los defaults del provider coincidían con AWS. Si en el futuro cambian, o si en la subnet real fueran otros valores, veríamos diff.

`region` y `tags_all` son metadata benigna:
- `region` hereda del bloque `provider "aws"` en `versions.tf`.
- `tags_all` es la unión de `tags` + `default_tags` (no configurado en este proyecto).

### Paso 5: `terraform import`

```bash
terraform import aws_subnet.private_1a subnet-00571f5c84fc414d3
```

Output esperado (predicción alumno acertada):
- `Importing from ID "subnet-00571f5c84fc414d3"...`
- `Import prepared!`
- `Import successful!`

### Paso 6: `terraform plan` post-import

```
No changes. Your infrastructure matches the configuration.
```

**Criterio de éxito cumplido**. Frase ⭐⭐⭐ #2 de S12-A aplicada.

### Paso 7 y 8 — verificaciones complementarias

```bash
terraform state list
```

Output:
```
aws_subnet.private_1a
aws_vpc.main
```

Predicciones alumno acertadas: 2 recursos, ordenados alfabéticamente por address.

### Paso 8 — verificación del state en backend S3

Pregunta espontánea del alumno: "ese state donde está en el directorio .terraform/". Aprovechada para consolidar concepto crítico:

**El state real NO está en `.terraform/`**. `.terraform/` es cache local con:
- Binario del provider descargado por `terraform init`.
- Metadata de config (puntero al backend, NO el state real).
- `.gitignore` siempre. Regenerable.

**El state real vive en el backend S3**: `s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate`.

Verificación:
```bash
aws s3 ls s3://toleflaco-terraform-state-2026/envs/dev/
```

Output: `4085 terraform.tfstate` — un solo fichero, 4KB, timestamp coincide con último `import`. `.tflock` ausente (lock liberado tras terminar la operación). Predicciones alumno acertadas.

Ciclo Terraform en cada mutación: baja state de S3 → adquiere lock (crea `.tflock`) → ejecuta → sube state modificado → libera lock (borra `.tflock`).

**Estimación de crecimiento**: state actual 4KB con 2 recursos. Al cierre del ciclo brownfield (~15 recursos) probable ~30-50KB. Crecimiento no lineal — cada recurso arrastra atributos, tags, sub-recursos.

## Bloque 6 — Segunda subnet + lección crítica copy-paste

Ciclo mínimo sin verificaciones didácticas. Objetivo: replicar patrón para consolidar.

### Ejecución del alumno

Ejecutó autónomamente:

1. `aws ec2 describe-subnets --subnet-ids subnet-0af15e9e05f81098f` ✓
2. Escritura HCL bloque `aws_subnet.private_1b` ✓
3. `terraform validate` ✓ (`Success!`)
4. `terraform plan` pre-import ✓ (`Plan: 1 to add`)
5. `terraform import` ✓ (`Import successful!`)
6. `terraform plan` post-import — **`~ update in-place`**, NO `No changes`.

### Diagnóstico

Output del plan post-import mostró:

```
~ "Name" = "task-manager-subnet-private2-eu-west-1b" -> "task-manager-subnet-private1-eu-west-1b"
```

**Causa**: copy-paste sin releer del bloque `private_1a`. Al duplicar cambió `1a → 1b` en address, cidr_block y AZ, pero en el tag Name se dejó `private1` en lugar de `private2`.

Valor real AWS: `task-manager-subnet-private2-eu-west-1b`. HCL declarado: `task-manager-subnet-private1-eu-west-1b`. **HCL mentía sobre la realidad**.

### Por qué esto es peligroso

Si `apply` hubiera ejecutado:
- Terraform llama `ec2:CreateTags` en AWS.
- AWS renombra el tag Name real de `private2` a `private1`.
- Cualquier script, dashboard, alerta o monitorización que filtre por tag Name se rompe silenciosamente.

Modo real en que `terraform apply` destruye producción: no con errores dramáticos, con un `~ update in-place` de una línea que no se releyó bien porque "es una subnet, qué va a pasar".

### Solución aplicada

Edición del HCL cambiando `private1` → `private2` en el tag Name. `terraform plan` vuelto a ejecutar. Output:

```
No changes. Your infrastructure matches the configuration.
```

Cerrado limpio. **NO se re-importa** — el import ya se hizo bien, solo se sincroniza HCL con state.

### Reglas operativas derivadas nuevas de S12-B

1. **El plan post-import solo es señal de éxito si sale `No changes`. Cualquier `~`, `-`, `+` o `-/+` significa que tu HCL miente sobre la realidad. Antes de apply, decides QUIÉN tiene razón — HCL o AWS — y ajustas.**

2. **En brownfield, la fuente de verdad es AWS, no el HCL. Tu HCL está aprendiendo a describir AWS, no al revés. Si el plan post-import muestra diff, la respuesta correcta 99% del tiempo es arreglar el HCL para que coincida con AWS, NO ejecutar apply.**

3. **Copy-paste sin releer es el modo #1 de romper cosas en Terraform. Cuando dupliques un bloque de recurso, cambia TODOS los identificadores humanos (address, tags, comentarios) antes de ejecutar plan. El schema no te protege — el tipo `string` acepta cualquier cosa.**

Este es un patrón recurrente cazado en múltiples fases anteriores (JPA @RequestParam vs @PathVariable, boundary operator `<` vs `<=`, IDE autocomplete aceptado sin releer). Añadido al set operativo permanente.

## Bloque 7 — Cierre operativo

### Actualización del checklist

Toggles `- [ ]` → `- [x]` en las dos subnets privadas importadas.

### Diff verificado antes del commit

```bash
git diff
```

Dos ficheros modificados como esperado. `terraform.tfstate` NO aparece en `git diff` — vive en S3, no en local. Consolidación importante.

### Commit final

- Hash: `6ffef9c`
- 2 ficheros modificados, 22 inserciones, 2 deleciones.
- Mensaje Conventional Commits bilingüe (EN + `---` + ES).

### Push

- `37eca42..6ffef9c main -> main`.
- Passphrase de la clave ED25519 (`~/.ssh/id_ed25519`).
- Exit code 0.

## Comandos AWS CLI memorables (referencia rápida — a memorizar)

Petición explícita del alumno de anotarlos destacados.

1. **`aws ec2 describe-vpcs`** — listar VPCs de la cuenta.
2. **`aws ec2 describe-subnets`** — listar subnets. Con `--subnet-ids <id>` filtra por una específica. Con `--filters "Name=vpc-id,Values=<vpc>"` filtra por VPC.
3. **`aws ec2 describe-security-groups`** — listar SGs. Filtros análogos.
4. **`aws s3 ls s3://<bucket>/<prefix>`** — listar objetos de un bucket. Sin prefix, lista raíz.
5. **`aws ec2 describe-instances`** — listar EC2. Con `--instance-ids <id>` filtra por una.

Estructura universal AWS CLI (repaso S12-A):
```
aws <servicio> <operación> [--opciones...]
```

Convenciones de operación: `describe-*` (leer detalles), `list-*` (listar sin detalle), `get-*` (leer un elemento), `create-*`, `delete-*`, `modify-*`.

Comandos avanzados que se buscan cuando se necesiten (nadie los memoriza): `--filters`, `--query`, integración con `jq`.

## Frases ⭐⭐⭐ nuevas de S12-B

1. "El plan post-import solo es señal de éxito si sale `No changes`. Cualquier `~`, `-`, `+` o `-/+` significa que tu HCL miente sobre la realidad."
2. "En brownfield, la fuente de verdad es AWS, no el HCL. Tu HCL está aprendiendo a describir AWS, no al revés."
3. "Copy-paste sin releer es el modo #1 de romper cosas en Terraform. El schema no te protege — el tipo `string` acepta cualquier cosa."
4. "Address vive en Terraform, id vive en AWS." (mnemotécnica para `terraform import`)
5. "En brownfield real, declara todo atributo semánticamente significativo aunque coincida con el default del provider. La brevedad del HCL no es una virtud si sacrifica claridad o robustez."
6. "1 VPC = máximo 1 IGW. La diferencia público/privado se hace a nivel de Route Table, no de IGW."
7. "El state real NO está en `.terraform/`. Vive en el backend (S3 en este proyecto). `.terraform/` es solo cache local regenerable."

## Deuda arrastrada actualizada

### Deuda nueva (Sesión 12-B)

- **11 recursos pendientes de import** para completar adopción brownfield: 2 subnets públicas, IGW, 3 RTs + associations + routes, 2 SGs + reglas, S3 uploads + sub-recursos, IAM Role + Instance Profile, EC2, RDS, VPC Endpoint. Planificados para S12-C (y probablemente S12-D).
- **Formato del HCL en `main.tf`**: faltan líneas en blanco entre recursos hermanos. Se arregla con `terraform fmt` en `infra/` al arrancar S12-C. Cero impacto funcional, cosmético.
- **Confirmar en warmup S12-C** que la lección copy-paste ha aterrizado. Primera pregunta: "¿por qué el plan post-import de la 1b salió con `~` en vez de `No changes` y cuál es la lección?".
- **JSON de `describe-route-tables`**: pendiente aprender a leerlo cuando toque importar RTs en S12-C. Es más denso que `describe-subnets`.
- **Decisiones abiertas para RTs** (S12-C):
  - Importar Main RT (recomendación: no).
  - Routes del VPC Endpoint (recomendación: delegar al `aws_vpc_endpoint`, no importar como `aws_route` explícitos).

### Deuda arrastrada de sesiones anteriores (siguen abiertas)

- **RDS y EC2 parados desde S12-A**. Trampa de auto-arranque a 7 días activa: **fecha límite 24 ago**. Si S12-C se retrasa más allá, verificar manualmente con CloudTrail.
- **ADRs pendientes reservados para tras cerrar bloque Terraform**:
  - ADR-A2: Terraform vs CloudFormation vs CDK.
  - ADR-A6: DynamoDB locking vs S3 native locking.
  - ADR-A7: `terraform import` vs recrear desde cero.
  - ADR-A8 (candidato): declarar defaults críticos en HCL vs aceptar defaults del provider.
- **README de portfolio pendiente actualizar** con S3 integration + presigned URLs + VPC Endpoint. Acumulada desde S6-S8.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2**.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location**.
- **`postgresql-client` en EC2 en v16 vs server v18**.
- **Billing access para IAM user `tole`** — activar desde root.
- **Verificación empírica del tráfico por VPC Endpoint** — postpuesta al módulo Observabilidad.
- **`tags_all` y `default_tags` a nivel provider** — anticipado pero no ejercitado.

### Deudas cerradas hoy

- **Warmup consolidando conceptos S12-A**: cerrado con 2/5 aciertos limpios + 3 parciales. Ratio suficiente. Críticas P3 y P4 aterrizadas.
- **Primera subnet como ejercicio guiado completo**: cerrada con patrón replicable para las 3 subnets restantes.
- **Segunda subnet con replicación de patrón + lección copy-paste**: cerrada con regla operativa fijada.
- **Confusión address ↔ id**: corregida. Mnemotécnica fijada.
- **Confusión `unlock-force` vs `force-unlock`**: corregida.
- **Confusión `touch` vs `>>`**: corregida. Tabla mental fijada.
- **Modelo mental "state vive en .terraform/"**: corregido. State vive en el backend S3, `.terraform/` es cache local.
- **Comprensión de las 3 categorías de líneas en `terraform plan`** (declarados / Computed / defaults del provider): consolidada.
- **Regla operativa "en duda, declara"** en atributos semánticamente significativos: fijada.

## Para retomar en Sesión 12-C

**Prerrequisito obligatorio**: relectura de esta bitácora S12-B antes de arrancar. Regla operativa de S12-A (releer notas 48-72h) aplicada.

**Warmup obligatorio (~15 min)** — sin abrir diarios S12-A ni S12-B:

1. Por qué el `plan` post-import de la subnet 1b salió con `~ update in-place` en vez de `No changes`. Cuál fue la causa exacta y cuál es la lección operativa. Cuál es la regla derivada sobre copy-paste.
2. En brownfield, cuando el `plan` post-import muestra diff, ¿arreglas el HCL o ejecutas apply? Justifica.
3. Diferencia entre `.terraform/` local y el state real en S3. Qué pasa si borras `.terraform/`. Qué pasa si borras el objeto S3.
4. Por qué NO se importan las rutas locales de una Route Table. Por qué SÍ se importa (o se declara) la ruta hacia IGW.
5. En AWS: cuántos IGWs puede tener un VPC. Qué determina que una subnet sea "pública" — nombra las tres cosas.

**Objetivo S12-C**: `terraform fmt` inicial + 2 subnets públicas restantes + 1 IGW. Total estimado ~2h con calibración realista.

**Objetivo S12-D (probable)**: 3 RTs explícitas + routes + associations + Main RT (decisión pendiente) + SGs. Total estimado ~2h.

**Objetivo S12-E (probable)**: S3 uploads + IAM Role + Instance Profile + EC2 + RDS + VPC Endpoint + plan global final + commit + push + ADRs + bitácora final. Total estimado ~2h.

**Recalibración honesta del ciclo brownfield**: no cierra en 3 sesiones (S12-A + S12-B + S12-C) como estimaba originalmente. Probable extensión a 5 sesiones (S12-A a S12-E). Aceptado.

**Alternativa vespertina ligera si baja energía**: sesión de repaso conceptual sin código nuevo. Alumno narra las 7 frases ⭐⭐⭐ de hoy en sus palabras, Claude pregunta nuances, gaps identificados. Fijo para Sunday-slot.

## Meta-observaciones de método

1. **Ratio 2/5 aciertos limpios en warmup + 3 parciales**: mejora respecto a S12-A (1.5/5), pero sigue reflejando dominio operativo sólido y dominio conceptual sobre sintaxis frágil (address vs id, force-unlock vs unlock-force). Requiere: repetición de ejercicios prácticos, no solo lectura de notas.

2. **Dos errores de método (míos) reconocidos y corregidos sin softening**:
   - Dumpear "Realidad reconstruida" con 4 RTs + 3 decisiones + vocabulario sin introducir. Corregido tras feedback "me explota la cabeza".
   - Nombrar `Sesion12-Import-Checklist.md` dos veces sin haberlo introducido en la sesión (asumí contexto del prompt como pactado con el alumno). Corregido tras "esto de donde lo sacas??".
   - Ambos reforzaron confianza en método, no la dañaron. Regla derivada: **cuando el alumno señala confusión, reconocer el error de método sin softening y reencuadrar. Es dato operativo, no queja a suavizar.**

3. **Contradicción cazada por el alumno sobre `map_public_ip_on_launch`**: puse ese atributo en Categoría 1 (declarar) y luego dije "no hace falta declararlo porque coincide con el default". Alumno preguntó explícitamente cuál valía. Corregido con regla operativa fijada. Ejemplo positivo de alumno tratándome como co-piloto crítico, no como fuente infalible.

4. **Recalibración de scope en directo a mitad de sesión**: aplicada regla de S12-A #7 ("cuando el ritmo se descoloca, cortar y digerir es mejor que acelerar para cerrar hoy"). Reducción de 4 subnets + IGW + RTs + associations a 4 subnets + IGW y finalmente a 2 subnets. Cierre con 2/4 subnets es correcto — método intacto, patrón consolidado, lección crítica aterrizada.

5. **La lección copy-paste apareció espontáneamente en el ejercicio**: no la planifiqué, salió del error del alumno. Aprovechada al máximo — vale más que cualquier explicación teórica que hubiera dado. Regla derivada: **los errores empíricos son oportunidades didácticas de oro. Nunca corregir mecánicamente — siempre explicar la mecánica del error y derivar regla operativa fijable.**

6. **Alumno preguntando "¿AWS está programado en Go?"**: pregunta buena y correcta. Reveló ambigüedad en mi comunicación previa ("código Go del AWS provider" leído como "código Go de AWS"). Distinción explícita añadida: AWS-plataforma es propietario multi-lenguaje; `terraform-provider-aws` es Go, open source, HashiCorp. Fijado con cadena mental completa (HCL → CLI Go → provider Go → AWS API → AWS backend). Regla derivada: **cuando el alumno pregunta algo aparentemente básico, casi siempre revela ambigüedad en la comunicación previa. Corregir la comunicación, no dar por básica la pregunta.**

7. **Pregunta espontánea "¿dónde está el state?" después del `state list`**: aprovechada para consolidar concepto crítico ya trabajado en S11 pero no aterrizado del todo. Confirmado con verificación empírica en S3. Ejemplo de curiosidad genuina del alumno impulsando consolidación oportuna.

8. **Petición explícita "anota los comandos AWS CLI en las notas marcados en rojo"**: registrada. Comandos listados en sección propia de esta bitácora.

9. **Alumno propuso "¿no hacemos el IG?" a 19 min del cierre**: respuesta correcta fue **no**, con tres motivos explícitos (margen real 10 min efectivos, IGW es anatomía distinta a subnet, cerrar en verde tras lección aterrizada consolida mejor). Regla S12-A #7 aplicada. Alumno aceptó sin pushback.

10. **Estimación de contexto al cierre**: ~70-75% del chat consumido. Prompt de continuación denso ya no cabe con calidad — S12-C arranca en chat nuevo con prompt de continuación explícito.

11. **Duración real vs estimada**: sesión de 2h efectivas cerrando 2 subnets (más warmup + descubrimiento + checklist + reencuadre). Estimación calibrada de S12-A ("30-40 min por recurso brownfield") confirmada en el primer ejercicio guiado, mejorada en el segundo (~15 min por replicación de patrón). Recalibración honesta funciona.
