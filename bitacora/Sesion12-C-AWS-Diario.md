# Sesión 12-C — Import brownfield subnets públicas + IGW (parte 6 de la Sesión 5 oficial del roadmap)

**Fecha:** 19 agosto 2026
**Duración:** ~2h 15min (~16:15 – 18:30, ventana vespertina desde casa de dormir)
**Estado:** Parcial. Cierre S12-C con 2 subnets públicas + IGW importados al state y `terraform plan` = `No changes` verificado en cada import. Total 6/13 recursos en state (VPC + 2 privadas + 2 públicas + IGW). Recalibración honesta respecto al prompt original: se cumplió el objetivo planeado (2 pub + IGW) con desvío de +15min por bug de copy-paste recurrente en el `vpc_id` del IGW. Pendiente en S12-D: 3 RTs explícitas + routes + associations + decisión Main RT + 2 SGs. Pendiente en S12-E: S3 uploads + IAM Role + Instance Profile + EC2 + RDS + VPC Endpoint + plan global final + ADRs + bitácora final. Confirmada extensión del ciclo brownfield a 5 sesiones (S12-A a S12-E).

## Objetivo pedagógico

Continuar la adopción brownfield sistemática iniciada en S12-A y consolidada en S12-B. Cubrir en orden:

1. Warmup — validar consolidación de conceptos S12-B (copy-paste + regla operativa, brownfield source of truth, `.terraform/` vs state en S3, rutas locales vs ruta IGW, condiciones subnet pública).
2. `terraform fmt` inicial en `infra/` + commit separado.
3. Import práctico de las 2 subnets públicas con verificación `plan` = `No changes` tras cada una.
4. Import práctico del IGW con contexto conceptual previo (anatomía distinta a subnet, dos operaciones AWS, Opción A vs B del provider).
5. Commit + push por bloque + actualización checklist + bitácora.

Escenario de aterrizaje empírico: aplicar la regla ⭐⭐⭐ #7 de S12-B ("AWS es fuente de verdad, arreglar HCL, nunca apply sobre diff") ante el primer bug real post-consolidación. Ocurrió — y la aplicó en directo. Aterrizaje empírico confirmado.

## Bloque 1 — Warmup: repaso de conceptos de S12-B

Cinco preguntas de predicción antes de arrancar contenido nuevo, sin abrir diarios S12-A ni S12-B.

### Preguntas y desempeño

| # | Tema | Predicción del alumno | Realidad | Correcto |
|---|------|----------------------|----------|----------|
| 1 (crítica) | Copy-paste bug + regla operativa | Causa: "un nombre de tag diferente un 1 por un 2, y eso cambiaba todo". Lección: "TENGO QUE LEER BIEN LOS COPY/PASTE SI O SI". Regla operativa: no articulada como principio. | Causa correcta (tag `private1` vs `private2`). Lección en forma emocional, no como regla aplicable. Faltaban dos piezas: (a) mecánica de por qué el schema no lo pilla — schema valida sintaxis y tipos, no semántica; `string` acepta cualquier cosa. (b) regla operativa como procedimiento: "releer todos los identificadores humanos del bloque nuevo antes de ejecutar plan". | Parcial tras refuerzo denso |
| 2 (crítica) | Brownfield source of truth | "Arreglo HCL, no ejecuto apply, el plan tiene que salir No changes para que sea lo mismo en AWS y en HCL". | Correcto operativo directo. Refuerzo conceptual añadido: en brownfield la fuente de verdad es AWS; el HCL está aprendiendo a describir AWS. Un apply sobre diff modificaría AWS para coincidir con la mentira del HCL. En el peor caso (`-/+ forces replacement`) destruiría el recurso real. | Correcto operativo + refuerzo conceptual |
| 3 | `.terraform/` vs state en S3 | (1) `.terraform/` contiene "un terraform.tfstate". (2) Borrar `.terraform/`: "en el import se vuelve a meter". (3) Borrar objeto S3: "se pierde el state de terraform". | (1) **RECAÍDA**. `.terraform/` NO contiene state de recursos; contiene binarios del provider en `.terraform/providers/` (~500 MB) + metadata de conexión al backend. State real en S3. Este concepto estaba en deuda cerrada de S12-B. (2) "No pasa nada" catastrófico correcto, pero mecanismo mal: se regenera con `terraform init`, no con import. (3) Correcto pero incompleto: el bucket tiene versionado, `delete` normal pone delete marker recuperable; solo se pierde definitivamente eliminando todas las versiones. | Parcial tras refuerzo — **recaída de deuda cerrada S12-B** |
| 4 | Rutas locales vs ruta IGW | "No lo sé, he leído eso de las notas y no lo he entendido". Honesto. | Refuerzo completo: rutas `local` (`10.0.0.0/16 → local`) las crea AWS automáticamente al crear el VPC, no pueden borrarse ni modificarse, son constantes del servicio. Terraform NO las modela como `aws_route` — `local` no es un ID de recurso, es keyword mágico. En contraste, rutas explícitas creadas por humano (ej: `0.0.0.0/0 → igw-xxx`) sí son `aws_route` gestionables. Regla: ruta implícita del servicio = ignorada; ruta explícita = recurso. | Aterrizado tras refuerzo directo |
| 5 | IGW por VPC + subnet pública | "Uno solo. Las subnets son públicas o privadas por la route table". | (1) Correcto: 1 VPC = máximo 1 IGW attached. (2) Parcial: la pregunta pedía **tres cosas**. Las tres: (a) subnet asociada a RT con ruta `0.0.0.0/0 → IGW`, (b) `map_public_ip_on_launch = true` en la subnet, (c) IGW attached al VPC. Falta una → subnet NO es funcionalmente pública. | Parcial tras refuerzo |

### Resultado global del warmup

**0 aciertos limpios + 5 parciales de 5**. Peor ratio que S12-B (2/5 limpios). Todos los conceptos aterrizados tras refuerzo directo. La recaída sobre `.terraform/` vs S3 es especialmente significativa — era deuda cerrada de S12-B. Señal fuerte: **la consolidación conceptual sigue frágil y necesita sesión de repaso dedicada antes de S12-D** (que introduce RTs, associations, decisión Main RT — anatomía más densa).

### Errores del profesor durante el warmup

1. **"No es catástrofe" tras 0/5 aciertos limpios** — softening que violaba regla explícita del alumno. Corregido tras pushback directo del alumno ("joder si lo es"). Sin excusas. Dato reforzado: el alumno está vigilando el método, lo cual es exactamente lo que debe hacer.
2. **Propuesta pobre de "releer las 12 frases ⭐⭐⭐"** para consolidar deuda de repaso. Corregido tras pushback del alumno ("no creo que valgan, tengo que mirar todo el chat"). Reformulado a: **relectura completa de bitácoras S12-A y S12-B con diario abierto, en voz alta, alumno explicando cada bloque en sus palabras**. Frases sueltas son mnemotécnicas post-facto, no reemplazan material denso.

### Errores viejos NO recaídos

- **Confusión address ↔ id**: consolidada. Sin recaída.
- **Sintaxis `terraform import`**: sin errores.
- **Modelo mental "plan compara HCL vs state"**: aplicado limpio durante todos los imports de hoy.
- **Regla brownfield #7 (AWS source of truth)**: aplicada empíricamente en directo ante el bug del IGW (ver Bloque 4).

### Regla operativa confirmada de S12-B

Los conceptos empíricos consolidados requieren relectura de notas cada 48-72h. Hoy S12-C ocurrió 2 días después de S12-B — dentro de ventana. Sin embargo, la relectura previa fue mecánica (el alumno "releyó" pero llegó frío al warmup, evidenciado por 0/5 aciertos limpios). Refuerzo de regla: **relectura ≠ leer rápido. Requiere reproducir mentalmente el ejercicio y verbalizar la regla operativa antes del warmup**.

## Bloque 2 — `terraform fmt` inicial + commit separado

Ejecución de la regla operativa fijada al cierre de S12-B: primer comando técnico de S12-C debe ser `terraform fmt` para arreglar el formato heredado (líneas en blanco irregulares entre bloques).

```bash
cd infra/
terraform fmt
git status
git diff
```

**Resultado**: diff limpio de whitespace puro — una sola línea en blanco añadida entre `aws_vpc.main` y `aws_subnet.private_1a`.

**Commit separado** (regla operativa: no mezclar cosmético con funcional):

```
style(infra): apply terraform fmt to main.tf
```

Hash `1f8d003`. Push OK a `origin/main`. Buena disciplina — commit atómico con cambio verificable.

### Nota operativa capturada

Al ejecutar `cd infra/` desde `~/proyectos/cloud-roadmap/infra`, aparece `-bash: cd: infra/: No such file or directory` (ya estabas dentro). Sin impacto — los otros comandos corrieron. Dato: **el shell ejecuta el resto de comandos aunque el primero falle** cuando están pegados con Enter, siempre que sea un fallo no-fatal.

## Bloque 3 — Import subnet pública 1a

Ejercicio guiado moderado — patrón conocido de S12-B, pero con verificación empírica AWS obligatoria.

### Descubrimiento de discrepancia realidad vs predicción del prompt

Comando de verificación:

```bash
aws ec2 describe-subnets --subnet-ids subnet-0af881e02d4a9322b
```

**Predicción del prompt de continuación** (redactado ayer al cierre de S12-B): "casi seguro `MapPublicIpOnLaunch = true`".

**Realidad AWS**: `MapPublicIpOnLaunch = false`.

Aplicación de regla operativa S12-B: **empírico manda, predicción del prompt falsable como cualquier otra**. Los errores empíricos son oportunidades didácticas de oro (regla derivada S12-B #5).

### Ejercicio de clasificación por categorías

Antes de escribir HCL, clasificación del atributo por las 3 categorías fijadas en S12-B:

- Realidad AWS: `false`.
- Default del provider Terraform: `false`.
- Categoría 3 (default del provider).
- Aplicación regla "en duda, declara en atributos semánticamente significativos": **sí, declarar explícito**.

Justificación del alumno: "lo declaro para que sea así si se produce un cambio en consola" — correcto. **Segunda razón añadida**: proteger contra cambios de default en futuras versiones del provider (breaking changes 6.x → 7.x son posibles).

### Aclaración conceptual: HashiCorp vs AWS

Pregunta espontánea del alumno: "HashiCorp?? no debería cambiar el default AWS??? pregunto desde mi ignorancia".

Aclaración explícita añadida:

- **AWS** publica la API HTTP. Si la request no incluye `MapPublicIpOnLaunch`, AWS lo trata como `false`. Comportamiento del servicio, propiedad de Amazon.
- **HashiCorp** escribe `terraform-provider-aws` en Go (open source). Es un **cliente** de la API AWS. En su schema, decide qué valor por defecto pone en el request si no lo declaras. Habitualmente coincide con AWS por menor sorpresa, pero **no está obligado**. En cambios de versión mayor puede diferir como breaking change documentado.
- Cadena mental completa: **AWS API (default AWS) ← provider Terraform en Go (default HashiCorp, puede diferir) ← tu HCL (tu decisión explícita)**. Cada capa puede tener su propio default.

Pregunta buena. Reveló que la distinción de S12-B ("provider AWS de Terraform es Go, open source, HashiCorp") no había aterrizado del todo. Consolidada ahora.

### HCL escrito y ejercicio del ciclo

Bloque `aws_subnet.public_1a` escrito con:
- `vpc_id` (Cat 1), `cidr_block` (Cat 1), `availability_zone` (Cat 1), `map_public_ip_on_launch = false` (Cat 3 declarada), `assign_ipv6_address_on_creation = false` (Cat 3 declarada por consistencia con las privadas), `tags.Name` (Cat 1).

`terraform plan` intermedio: `1 to add, 0 to change, 0 to destroy` con `+ create aws_subnet.public_1a`. Refresh limpio de los 3 recursos ya importados.

`terraform import`:

```bash
terraform import aws_subnet.public_1a subnet-0af881e02d4a9322b
```

Resultado: `Import successful`.

`terraform plan` post-import: **`No changes`**. En una sola iteración. Sin ~, sin +, sin -. Objetivo cumplido.

### Aterrizaje empírico crítico

Este es el primer import donde el HCL se escribió ANTES con Categoría 3 declarada explícitamente por regla "en duda, declara". Resultado: `No changes` en primera iteración, sin diff que arreglar. Contraste con S12-B, donde varios `plan` post-import requirieron iteración. **La regla operativa "en duda, declara" tiene tracción empírica confirmada**.

## Bloque 4 — Import subnet pública 1b

Ejercicio de replicación con verificación pre-import por parte del alumno (proceso pactado explícitamente: "pégamelo aquí antes de importar").

### Copy-paste con relectura aplicada

Duplicación del bloque `public_1a` a `public_1b`. Cambio de los 3 identificadores discriminantes:

- `cidr_block`: `10.0.0.0/20` → `10.0.16.0/20`
- `availability_zone`: `eu-west-1a` → `eu-west-1b`
- `tags.Name`: `public1-eu-west-1a` → `public2-eu-west-1b` (**cambio doble**: `public1` → `public2` Y `1a` → `1b`)

Verificación conjunta línea a línea contra `describe-subnets` de `subnet-066074bd45c1a46f6`. Todo coincide. **Lección S12-B aterrizada empíricamente por primera vez** — no solo verbalizada en el warmup.

### Ejecución sin fricciones

```bash
terraform validate    # Success
terraform import aws_subnet.public_1b subnet-066074bd45c1a46f6    # Import successful
terraform plan        # No changes
```

Serial del state incrementado. 5 recursos gestionados.

### Curiosidad espontánea aprovechada: ver el serial por CLI

Pregunta del alumno: "donde puedo ver el serial en el bucket? y luego como lo veo por AWS CLI??"

Respuesta enseñada:

```bash
aws s3 cp s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate - | jq '.serial, .lineage, .resources | length'
```

Desglose:
- `aws s3 cp <s3-path> -` → descarga a stdout (el `-` es stdout).
- `| jq` → parsea JSON.
- `.serial`, `.lineage`, `.resources | length` → los 3 metadatos clave.

**Regla operativa nueva capturada**: `aws s3 cp` sobre `terraform.tfstate` es operación potencialmente peligrosa según qué recursos gestione el state. En este momento (subnets + VPC) sin secretos, pero cuando importe RDS o IAM en S12-E el state contendrá contraseñas, credenciales, tokens. Alternativa segura: `terraform state list` (solo addresses) y `terraform state show <address>` (recurso concreto, vista pública) — NO exponen todo el JSON.

## Bloque 5 — Commit intermedio de las 2 subnets públicas

Decisión del alumno tras pregunta explícita: commit intermedio ahora + IGW después (opción segura).

Verificación pre-commit: `git log --oneline -5` + `git status` + `git diff main.tf`.

- Commit anterior (`fmt`) pusheado a `origin/main`: OK.
- Un solo fichero modificado (`main.tf`), diff limpio con los 2 bloques nuevos.
- Sin sorpresas en el árbol de trabajo.

Commit bilingüe con mensaje denso documentando:
- Los 2 bloques importados con CIDR y AZ.
- Justificación de `map_public_ip_on_launch = false` explícito (Cat 3 semánticamente significativa + protección contra cambios de defaults del provider).
- Serial del state incrementado a 7.
- Disciplina de copy-paste aplicada (todos los identificadores humanos verificados antes de plan).
- Aterrizaje empírico de la lección S12-B.

Hash `42ebc88`. Push OK.

## Bloque 6 — Import IGW: contexto conceptual + bug de copy-paste recurrente

Ejercicio con recurso de anatomía distinta a subnet. Requirió contexto conceptual previo antes de tocar HCL.

### Contexto conceptual introducido antes de HCL

1. **El IGW es recurso de red distinto a subnet**. Subnet vive DENTRO del VPC (`vpc_id` obligatorio en creación). IGW vive JUNTO al VPC — se crea independiente y se attacha después.
2. **En AWS API hay dos operaciones**: `CreateInternetGateway` (crea detached) y `AttachInternetGateway` (asocia al VPC). En la práctica siempre encadenadas, pero conceptualmente distintas.
3. **En provider 6.x hay dos opciones de modelado**:
   - **Opción A** (elegida): todo en `aws_internet_gateway` con `vpc_id` como atributo interno. Un recurso, un import. Provider hace las 2 llamadas AWS.
   - **Opción B**: `aws_internet_gateway` + `aws_internet_gateway_attachment` separados. Dos recursos, dos imports. Solo útil si los ciclos de vida se gestionan por equipos distintos (raro).

Decisión: Opción A por unidad conceptual + gestión unificada.

### Clasificación de atributos por categoría (ejercicio)

Sobre el JSON de `describe-internet-gateways igw-0ab423637224cab0c`:

| Atributo | Categoría del alumno | Correcto |
|---|---|---|
| `InternetGatewayId` | 2 | ✓ (Computed, generado por AWS) |
| `OwnerId` | 2 | ✓ (Computed, cuenta AWS) |
| `Tags.Name` | 1 | ✓ (humano decide) |
| `Attachments[0].VpcId` | 1 (con matiz: "aunque anteriormente estaba en la 2") | ✓ con observación fina |

**4/4 correctas**. La observación sobre `vpc_id` es especialmente aguda: en `aws_subnet`, `vpc_id` es Cat 1 pura (argumento obligatorio de creación); en `aws_internet_gateway`, `vpc_id` viene del **attachment** (nested en AWS JSON) y en Opción A HashiCorp lo eleva a atributo directo del recurso IGW para simplificar. Es Cat 1 en el HCL, aunque en AWS-plataforma pertenece a otra entidad conceptual.

### Bug de copy-paste RECURRENTE — el mismo tema aterrizado 90 min antes

El alumno se saltó el ciclo pactado ("pégamelo aquí antes de importar. Verifico y arrancamos") y escribió + importó de golpe. HCL escrito:

```hcl
resource "aws_internet_gateway" "task-manager" {
  vpc_id = "vpc-0d36eccf72cddeda7"   # <-- 72, real es 71
  tags = {
    Name = "task-manager-igw"
  }
}
```

**Bug**: `vpc-0d36eccf`**72**`cddeda7` en HCL vs `vpc-0d36eccf`**71**`cddeda7` en AWS. Un solo carácter diferente en medio de un ID pseudoaleatorio.

**Cómo se detectó**: `terraform plan` post-import mostró:

```
~ resource "aws_internet_gateway" "task-manager" {
    ~ vpc_id = "vpc-0d36eccf71cddeda7" -> "vpc-0d36eccf72cddeda7"
  }
Plan: 0 to add, 1 to change, 0 to destroy.
```

**Reacción del alumno**: aplicó la regla ⭐⭐⭐ #7 de S12-B en directo — arregló HCL antes de cualquier apply. **Zero AWS mutation**. Aterrizaje empírico de la regla brownfield confirmado bajo estrés real.

### Análisis del bug — tres fallos encadenados

**Fallo 1: recaída de copy-paste, el MISMO BUG de S12-B.** Tema aterrizado hace 90 min en el warmup. Regla operativa consolidada completa. Recaída inmediata. Peor que S12-B porque el atributo bugueado fue `vpc_id` — el más crítico semánticamente. Con apply, Terraform habría intentado detach del VPC real + attach a VPC inexistente `72...`. Escenarios: error AWS ("VPC no existe") o peor, dependencias en cadena rotas.

**Fallo 2: saltarse ciclo pactado, segunda vez en la sesión** (la primera fue con el bloque `public_1b` escrito antes de acuerdo, sin consecuencia). Ejemplo de "excitación por avanzar" identificada como enemigo silencioso en brownfield. Regla derivada:

> El flow es sospechoso cuando cada paso puede corromper infraestructura. En código de aplicación el flow es aliado; en IaC brownfield es señal de saltarse verificaciones, no de estar en zona.

**Fallo 3: reintentar `terraform import` tras arreglar HCL.** El error de AWS fue exactamente correcto: `Resource already managed by Terraform`. Reveló confusión conceptual sobre qué hace `import`. Regla operativa:

> `terraform import` se ejecuta UNA vez por recurso (address). Después, arreglar HCL solo requiere `plan` para verificar coincidencia. Si `import` da "Resource already managed", NO reintentar — significa que el import previo ya escribió el mapping en state.

### Diagnóstico refinado sobre copy-paste

**Releer no es leer rápido**. Releer es identificar cada carácter que podría ser distinto. Los IDs de AWS parecen ruido visual — son la parte donde más falla el ojo humano. Regla operativa refinada:

> Al copiar un bloque HCL, releer especialmente los IDs de AWS carácter a carácter. El ojo humano no distingue `71` de `72` en medio de un string pseudoaleatorio. Comparar contra el JSON de `describe-*` línea a línea.

### Por qué AWS quedó intacto — concepto crítico consolidado

`terraform import` es **read-only en AWS**. Lee el recurso real y escribe el mapping (address, id) en state. NO llama a APIs mutadoras de AWS. Todo lo peligroso (crear, modificar, destruir) pasa en `apply`.

Frase ⭐⭐⭐ candidata:

> `terraform import` es READ-ONLY en AWS. El peligro está en el `apply` posterior, no en el import.

## Bloque 7 — Refactor con `terraform state mv`

Al preparar commit, observación de convención: el address `"task-manager"` usa guion, pero convención HashiCorp es snake_case.

Decisión: renombrar ahora con `terraform state mv` — combina fix cosmético con ejercicio empírico de una herramienta útil.

```bash
terraform state mv aws_internet_gateway.task-manager aws_internet_gateway.task_manager
# Successfully moved 1 object(s).
```

Después: arreglar address en `main.tf` (renombrar `"task-manager"` → `"task_manager"` en la línea del `resource`). `terraform validate` OK. `terraform plan` → **`No changes`**.

### Aprendizaje conceptual empírico

- `terraform state mv <origen> <destino>` reescribe el **address** del recurso en el state.
- **NO toca AWS**, **NO reimporta**.
- El **id** (`igw-0ab423637224cab0c`) permanece igual — mismo recurso real de AWS.
- El HCL debe estar sincronizado con el nuevo address para que `plan` cuadre.

Frase ⭐⭐⭐ candidata:

> `terraform state mv` mueve el address dentro del state; NO toca AWS, NO reimporta. Ideal para renames y refactors de HCL sin costo real. Herramienta central del kit de refactor Terraform.

Ejemplos donde volverá a aparecer: extraer recursos a un módulo (`aws_subnet.public_1a` → `module.vpc.aws_subnet.public_1a`), reorganizar naming, dividir un state monolítico en varios.

### Commit del IGW con lección incluida

Mensaje bilingüe denso documentando:
- Address, ID, VPC attached.
- Justificación de Opción A vs B.
- Serial incrementado, 6 recursos totales.
- **Lección del bug documentada en el cuerpo del commit** — no ocultada. Va al historial como enseñanza pública en el repo.
- Refactor con `terraform state mv` explicado.

Hash `0a04c2f`. Push OK a `origin/main`.

### Nota operativa capturada: artefactos visuales en WSL

En el output del `git commit + push` del IGW apareció una línea corrupta visualmente:

```
git pushp: snake_case para addresses de recursos).dembrado
```

Mezcla del `git push` que el alumno escribió con residuo del mensaje de commit. Probablemente artefacto de paste multilínea largo en WSL con heredoc. **Comando ejecutó bien** (hash creado, push exitoso a `origin/main`). Regla operativa: **outputs de WSL con paste largo pueden mostrar artefactos visuales sin corromper la acción real**. No confundir "output raro" con "comando roto" — verificar con `git log` + `git status` post-hoc.

## Comandos AWS CLI ejecutados (marcados en rojo para notas)

Comandos que van a las notas de repaso para tener listos en interview / consultoría:

```bash
# Verificar subnet
aws ec2 describe-subnets --subnet-ids <subnet-id>

# Verificar IGW
aws ec2 describe-internet-gateways --internet-gateway-ids <igw-id>

# Ver metadata del state en S3 (¡peligro con recursos que contienen secretos!)
aws s3 cp s3://<bucket>/<key>/terraform.tfstate - | jq '.serial, .lineage, .resources | length'

# Ver solo qué gestiona Terraform (seguro)
terraform state list

# Ver un recurso concreto del state (vista pública, seguro)
terraform state show <address>

# Mover address de un recurso en el state sin tocar AWS
terraform state mv <address-origen> <address-destino>
```

## Frases ⭐⭐⭐ candidatas (nuevas de S12-C)

1. "El schema del provider valida sintaxis y tipos, no semántica. `string` acepta cualquier cosa; releer todos los identificadores humanos del bloque nuevo antes de plan."
2. "`terraform import` es READ-ONLY en AWS. El peligro está en el `apply` posterior, no en el import."
3. "`terraform import` se ejecuta UNA vez por recurso (address). Después, arreglar HCL solo requiere `plan` para verificar coincidencia con state."
4. "`terraform state mv` mueve el address dentro del state; NO toca AWS, NO reimporta. Ideal para renames y refactors."
5. "El flow es sospechoso cuando cada paso puede corromper infraestructura. En código de aplicación es aliado; en IaC brownfield es señal de saltarse verificaciones."
6. "AWS default ≠ default del provider Terraform. Son cadenas independientes: AWS API ← provider Go de HashiCorp ← tu HCL. Cada capa puede diferir."
7. "Al copiar HCL, releer los IDs de AWS carácter a carácter. El ojo humano no distingue `71` de `72` en medio de un string pseudoaleatorio."

Total acumulado del arco Terraform (S12-A + S12-B + S12-C): **19 frases ⭐⭐⭐**.

## Deuda arrastrada actualizada

### Deuda nueva (Sesión 12-C)

- **7 recursos pendientes de import** para completar adopción brownfield: 3 RTs + routes + associations + 2 SGs + reglas + S3 uploads + sub-recursos + IAM Role + Instance Profile + EC2 + RDS + VPC Endpoint. Planificados para S12-D y S12-E.
- **Recaída de copy-paste consolidada como patrón**: dos ocurrencias en dos sesiones consecutivas del mismo bug. Verbalización de la regla en warmup NO garantiza aplicación bajo estrés. Requiere refuerzo empírico continuado — el próximo warmup S12-D debe forzar ejecución mental completa del ciclo, no solo enunciado.
- **Recaída conceptual `.terraform/` vs S3**: era deuda cerrada de S12-B, reabierta hoy. Consolidación conceptual sigue frágil.
- **Disciplina de ciclo pactado**: dos violaciones hoy (public_1b sin pactar + IGW sin pactar). La segunda causó el bug. Regla operativa: **en brownfield, nunca ejecutar acción que escriba en state sin pactar con el profe. Excitación por avanzar es enemigo, no aliado**.
- **Sesión de repaso conceptual pendiente URGENTE**: relectura completa de bitácoras S12-A y S12-B (no frases ⭐⭐⭐ sueltas), con diario abierto, en voz alta, alumno explicando cada bloque. Fijar para Sunday-slot antes de S12-D si es posible.
- **Cuidado con `aws s3 cp terraform.tfstate`**: state en claro puede contener secretos según qué recursos gestione. Regla operativa: usar `terraform state list` / `terraform state show` como alternativa segura.

### Deuda arrastrada de sesiones anteriores (siguen abiertas)

- **RDS y EC2 parados desde S12-A**. Trampa auto-arranque a 7 días: **fecha límite 24 ago**. Hoy 19 ago — **5 días de margen**. Verificar antes del 24 con CloudTrail si S12-D no ocurre antes.
- **ADRs pendientes reservados para tras cerrar bloque Terraform**:
  - ADR-A2: Terraform vs CloudFormation vs CDK.
  - ADR-A6: DynamoDB locking vs S3 native locking.
  - ADR-A7: `terraform import` vs recrear desde cero.
  - ADR-A8 (candidato): declarar defaults críticos en HCL vs aceptar defaults del provider.
  - ADR-A9 (candidato nuevo S12-C): Opción A vs B del provider AWS para IGW (`aws_internet_gateway` con `vpc_id` interno vs `aws_internet_gateway_attachment` separado).
- **README de portfolio pendiente actualizar** con S3 integration + presigned URLs + VPC Endpoint. Acumulada desde S6-S8.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2**.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location**.
- **`postgresql-client` en EC2 en v16 vs server v18**.
- **Billing access para IAM user `tole`** — activar desde root.
- **Verificación empírica del tráfico por VPC Endpoint** — postpuesta al módulo Observabilidad.
- **`tags_all` y `default_tags` a nivel provider** — anticipado, aún no ejercitado (aparece en cada plan como duplicado silencioso de `tags`).

### Deudas cerradas hoy

- **Warmup consolidando conceptos S12-B**: cerrado con 0/5 aciertos limpios + 5 parciales aterrizados tras refuerzo. Ratio peor que S12-B (2/5). Sesión de repaso conceptual añadida como deuda urgente.
- **`terraform fmt` inicial**: aplicado en commit separado.
- **Subnet pública 1a importada**: HCL con Cat 3 declarada, plan `No changes` en primera iteración.
- **Subnet pública 1b importada**: copy-paste con relectura aplicada bien, plan `No changes`.
- **IGW importado**: tras bug recurrente + arreglo, plan `No changes`. Regla brownfield #7 aterrizada empíricamente bajo estrés.
- **`terraform state mv`**: aprendido empíricamente. Herramienta de refactor central.
- **Distinción HashiCorp vs AWS defaults**: aclarada con cadena mental completa (AWS API ← provider Go ← HCL).
- **Anatomía IGW vs subnet**: clarificada (recurso independiente del VPC + attachment como operación separada).
- **Opción A vs B del provider para IGW**: decidida (A) con justificación.
- **Ver metadata del state por AWS CLI**: enseñado con `aws s3 cp - | jq` + regla de peligro con secretos.
- **Distinguir output corrupto de WSL vs comando roto**: regla operativa capturada.

## Para retomar en Sesión 12-D

**Prerrequisito obligatorio**: relectura de esta bitácora S12-C antes de arrancar. Regla operativa de S12-A/B (releer notas 48-72h) aplicada.

**Preferible antes de S12-D**: **sesión de repaso conceptual** de S12-A + S12-B (Sunday-slot ligero, 30-45 min), con bitácoras abiertas, alumno explicando cada bloque en sus palabras. NO recitar frases ⭐⭐⭐ sueltas. Objetivo: llegar a S12-D con la base conceptual firme antes de introducir RTs (anatomía más densa: aws_route_table, aws_route, aws_route_table_association, decisión Main RT, decisión sobre routes VPC Endpoint).

**Warmup obligatorio S12-D (~15 min)** — sin abrir diarios S12-A, S12-B, S12-C:

1. Por qué el `plan` post-import del IGW hoy salió con `~ update in-place` mostrando `vpc_id: 71 -> 72`. Cuál fue la causa exacta y qué hiciste para arreglarlo sin tocar AWS. Cuál es la regla operativa derivada sobre disciplina de ciclo pactado.
2. Diferencia entre `terraform import` y `terraform state mv`. Cuándo usar cada uno. Qué escribe cada uno y qué NO escribe.
3. Diferencia entre `.terraform/` local, el objeto `terraform.tfstate` en S3, y el fichero `main.tf`. Qué contiene cada uno. Qué pasa si borras cada uno. **Recuperación garantizada de la recaída de hoy**.
4. Qué son las 3 categorías de atributos en `terraform plan` (Cat 1 declarados, Cat 2 Computed, Cat 3 defaults del provider). Da un ejemplo de cada una en los recursos ya importados.
5. En provider AWS 6.x hay 2 formas de modelar el attachment de un IGW al VPC. Nombra las dos. ¿Cuál elegiste y por qué?

**Objetivo S12-D**: 3 RTs explícitas + routes + associations + decisión Main RT (recomendación: no importar) + decisión routes VPC Endpoint (recomendación: delegar al `aws_vpc_endpoint`, no importar como `aws_route` explícitos) + 2 SGs + reglas. Total estimado ~2h con calibración realista. Si sobrepasa scope, cortar en verde.

**Objetivo S12-E (probable)**: S3 uploads + IAM Role + Instance Profile + EC2 + RDS + VPC Endpoint + plan global final + commit + push + ADRs + bitácora final. Total estimado ~2h.

**Alternativa vespertina ligera si baja energía**: sesión de repaso conceptual sin código nuevo (opción preferida antes de S12-D, ver arriba).

## Meta-observaciones de método

1. **Ratio 0/5 aciertos limpios en warmup vs 2/5 en S12-B**: retroceso. Los conceptos de S12-B se verbalizaron pero no aterrizaron con solidez. La recaída sobre `.terraform/` vs S3 (deuda cerrada) es especialmente preocupante. Requiere: **repaso conceptual dedicado antes de S12-D**, no más ejercicios prácticos encima.

2. **Softening detectado y corregido por el alumno**: "No es catástrofe" tras 0/5 aciertos violaba regla explícita. Alumno corrigió con "joder si lo es". Sin excusas del profesor. Ejemplo positivo de vigilancia mutua del método. Regla derivada reforzada: **el softening es un fallo de método, no una amabilidad. El alumno tiene derecho a corregir sin softening en el profesor**.

3. **Idea pobre del profesor sobre "releer las 12 frases ⭐⭐⭐"** para consolidar deuda de repaso. Alumno propuso mejor solución ("tengo que mirar todo el chat de esas sesiones"). Aceptado sin resistencia. Regla derivada: **las frases ⭐⭐⭐ son mnemotécnicas post-facto para recuperar contenido ya aterrizado, no reemplazan la relectura del material denso. Consolidación requiere volver al material completo, no al índice**.

4. **Bug de copy-paste recaído 90 min tras consolidación completa en warmup**. Dato operativo crítico:

> Una regla aterrizada verbalmente no es una regla aterrizada empíricamente. La consolidación empírica requiere repetición bajo estrés y errores reproducidos, no solo enunciación correcta en warmup.

5. **Alumno aplicó regla brownfield #7 en directo tras ver el `~ update in-place` del IGW**. Arregló HCL antes de cualquier `apply`. Cero AWS mutation. **Aterrizaje empírico real de S12-B confirmado bajo estrés real**. Contrapeso al ratio pobre del warmup: la operativa fundamental está aterrizada aunque el vocabulario y los detalles conceptuales estén frágiles.

6. **"Excitación por avanzar" identificada por el alumno como causa** de los dos saltos de ciclo pactado. Autodiagnóstico honesto. Regla nueva capturada:

> El flow en IaC brownfield es sospechoso, no premio. Cada paso puede corromper infraestructura. En código de aplicación el flow es aliado; en brownfield es señal de saltarse verificaciones.

7. **Pregunta espontánea sobre HashiCorp vs AWS defaults** reveló consolidación incompleta de la cadena mental HCL → provider → API AWS. Aclaración explícita añadida. Ejemplo de curiosidad del alumno impulsando consolidación oportuna. Regla S12-B confirmada: **cuando el alumno pregunta algo aparentemente básico, casi siempre revela ambigüedad previa. Corregir la comunicación, no dar por básica la pregunta**.

8. **Curiosidad del alumno sobre ver serial en S3** aprovechada para introducir `aws s3 cp` + jq + regla de peligro con secretos. Contenido no planificado, útil, integrado en el flujo natural de la sesión.

9. **Petición explícita del alumno al final**: "haz las notas con el mismo formato que te he pasado". Autonomía sobre proceso. Registrado.

10. **Duración real 2h 15min vs pactado 2h**. Desvío aceptable dado el bug IGW + refactor state mv + explicaciones no planificadas (HashiCorp vs AWS, ver serial). Calibración honesta.

11. **Cierre en verde a pesar del susto**: 3 recursos importados con plan `No changes`, todo commiteado y pusheado. La regla operativa de S12-A ("cerrar en verde tramos completos es mejor que acumular trabajo") aplicada — commit intermedio antes de IGW salvó riesgo de perder trabajo si el IGW hubiera empeorado.

12. **Documentar el bug en el mensaje del commit**, no ocultarlo. Historial del repo como registro público de enseñanzas. Regla de método capturada: **los bugs son enseñanza pública, no vergüenza privada. Commit messages son documentación viva**.
