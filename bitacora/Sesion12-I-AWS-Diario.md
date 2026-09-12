# Sesión 12-I — Import brownfield bloque de aplicación S3 (bucket + encryption + PAB) con aterrizaje de #S12H-8 a locked ⭐⭐⭐ y descubrimiento empírico de la ausencia de versioning

**Fecha:** viernes 11 septiembre 2026 (ventana vespertina 16:35 – ~18:15, ~1h 40min). Sesión de una sola ventana continua, sin interrupciones externas.
**Duración total:** ~1h 40min honestas. Estimación inicial del prompt de continuación: 2h con margen a 2h 30min. **Sub-estimación consistente con el plan** — se cerró el bloque S3 por debajo del techo pactado gracias a que (a) 3 subrecursos S3 en lugar de los 4-6 anticipados por el descubrimiento del Bloque 3 (versioning, policy, CORS, lifecycle, notification, logging todos ausentes en AWS), (b) ciclo pactado ejecutado sin drift ni bugs semánticos en ninguno de los 3 imports, (c) commit bilingüe correcto al primer intento aplicando aterrizaje S12-H (0 `--amend`).
**Estado:** Cierre limpio del bloque de aplicación S3 con 3 imports (bucket maestro + encryption + public access block). Total 29/29 recursos gestionados (14 red + 7 seguridad + 1 VPC Endpoint + 4 IAM + 3 S3). `terraform plan` global = `No changes`, serial **32**. Commit `fcb520f` pusheado a `origin/main` limpio con triple confirmación conjunta (6ª aplicación consecutiva desde S12-F, primera limpia sin amend previos desde S12-G). RDS: `stopped` verificado al arrancar. IP casa: `95.121.15.184` (rotó desde `88.11.202.24` de S12-H — casa de los gatos, ISP distinto, no bloqueante para S3 pero anotable para S12-J). Bloque EC2 + RDS NO entraron — pactado explícitamente para S12-J. Sesión con **densidad pedagógica media**: 1 promoción a locked ⭐⭐⭐ (#S12H-8), 1 nueva regla candidata, 3 fallos menores de método del profesor asumidos sin softening con reglas derivadas.

## Objetivo pedagógico

Cerrar el bloque de aplicación S3 (uploads bucket + subrecursos según descubrimiento empírico) importando el recurso maestro y todos sus subrecursos con configuración real en AWS. Objetivos empíricos paralelos: (i) validar por primera vez en el roadmap el patrón moderno de recursos separados en S3 (`aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block` en lugar de bloques anidados legacy) confirmando que la semántica binaria "declarado = gestionado / ausente = no gestionado" simplifica el brownfield; (ii) verificar la peculiaridad del schema S3 (`id = bucket_name = valor del atributo bucket`) como tercer caso de la regla candidata #S12H-8 (peculiaridades del schema requieren referencias semánticamente correctas, no `.id` como comodín); (iii) aplicar la regla candidata #S12H-6 (no dumpear traducciones mecánicas completas) al bloque de encryption con `rule { apply_server_side_encryption_by_default {} }` — dar la estructura y reglas de traducción, no el HCL entero.

## Bloque 0 — Verificación al arranque

Sesión con hueco de 2 días desde el cierre de S12-H día 2 (9 sep 06:30-08:30). Hueco < 7 días: no requiere refresco de vocabulario básico. Regla operativa 48-72h aplicada: bitácora S12-H releída el día anterior por el alumno, confirmado antes del warmup.

Los 5 comandos habituales ejecutados sin incidencias:

- `git log --oneline -5` → HEAD en `83d1f8b docs(bitacora): add S12-H diary and update import checklist`, encima de `f395d8b feat(infra): import iam identity resources for ec2 task manager`. `origin/main` sincronizado.
- `git status` → `working tree clean`.
- `terraform state list | wc -l` → **26**.
- `terraform plan` → `No changes`, 26 recursos refreshed (14 red + 7 seguridad + 1 VPC Endpoint + 4 IAM).
- `aws s3 cp .../terraform.tfstate - | jq '.serial'` → **29**.
- `aws rds describe-db-instances --db-instance-identifier task-manager-db --query 'DBInstances[0].DBInstanceStatus'` → `"stopped"`.

Verificación IP casa `curl -s https://ifconfig.me` → `95.121.15.184`. **Rotó respecto a S12-H** (`88.11.202.24`). Alumno explicó: conexión desde "casa de los gatos" (Reinosa, distinto punto de acceso que Nestares habitual), ISP distinto. Máquina real es la misma (`TxM` WSL2 Ubuntu 22). Sin efecto operativo para S3 (API HTTPS con IAM, no depende de IP origen). **Anotar para S12-J** cuando toque SSH a EC2: el SG de acceso a EC2 tiene la IP de Nestares whitelisted, desde la de los gatos no entra.

Margen sobre deadline RDS auto-arranque (~15-16 sep): 4-5 días. Cómodo pero apretado si S12-J se retrasa a la semana siguiente.

Todo cuadró exactamente con lo esperado del estado al cierre de S12-H. Arranque limpio.

## Bloque 1 — Warmup 2 preguntas con Pregunta A pospuesta por confusión inicial (falta de anclaje S12-H en la memoria del alumno)

Warmup pactado según locked ⭐⭐⭐ #S12H-1 (máximo 2 preguntas, 5 min techo, filtro "¿falla → HCL corrupto en 30 min?").

Preguntas planteadas:

- **A (crítica)**: referencia HCL en subrecurso S3 al bucket padre. Aplicando #S12H-8: sabiendo que `aws_s3_bucket` expone `.id` y `.bucket` como atributos output (ambos devuelven el mismo string, el nombre del bucket), ¿cuál usas y por qué? Con nota honesta del profesor: "no recuerdo al 100% que `.bucket` esté expuesto, verificaré en docs".
- **B**: diferencia semántica entre patrón viejo (`aws_s3_bucket` con bloques anidados `versioning {}`) y patrón moderno (recursos separados). ¿Por qué el moderno es objetivamente mejor en brownfield?

### Confusión detectada antes de respuesta de la Pregunta A

Alumno respondió: **"Para, para lo último que hicimos fue el vpc_endpoint, de bucket no hemos hecho nada, no encuentro en HCL ninguna referencia a aws_s3_bucket"**.

Dos observaciones importantes en la reacción del alumno:

1. **"Lo último que hicimos fue el vpc_endpoint"** — **empíricamente falso**. Lo último fue el bloque IAM completo en S12-H (4 recursos: Role + Policy + Attachment + Instance Profile), commit `f395d8b`. El VPC Endpoint fue S12-G. Verificación empírica directa contra los ficheros HCL subidos por el alumno + los outputs de `Refreshing state` del `terraform plan` del Bloque 0 (donde salen los 4 `aws_iam_*`). La bitácora S12-H "releída ayer" no había aterrizado en su memoria operativa.
2. **"No encuentro referencia a aws_s3_bucket"** — **empíricamente correcto**. `aws_s3_bucket` es lo que vamos a importar HOY, no existía en su HCL antes de la sesión.

### Fallo de método del profesor

Formulación de la Pregunta A mencionaba "Bloque 5+" sin haber pactado explícitamente el plan de bloques de S12-I al arranque del mensaje anterior. Asumí que el prompt de continuación estaba fresco en la cabeza del alumno. **Falso**. La confusión sobre "lo último fue el vpc_endpoint" indica que la S12-H no estaba aterrizada operativamente, y el plan de S12-I tampoco. El alumno leyó mi mensaje sin el mapa mental del prompt de continuación al lado.

Reparación en caliente sin softening:

- Corrección de "lo último fue el vpc_endpoint" con evidencia directa (contenido de `iam.tf` + output del `plan` del Bloque 0). Sin softening — la bitácora releída no había cuajado.
- Aclaración de que la Pregunta A era **anticipada** (sobre HCL a escribir en Bloques 4-6), no sobre HCL existente.
- Explicitación del plan de bloques de S12-I antes de continuar.

Alumno pidió saltarse la Pregunta A y arrancar directamente Bloque 2 conceptual: **"si bloque 2 conceptual"**. **Decisión aceptada sin defensa del formato original** — es aplicación directa de la regla operativa S12-H "cuando el alumno pide cambio de método por fricción real, aceptar y reformular en caliente, no defender el método por consistencia con el prompt". Pregunta A quedó **pospuesta** para verla en vivo cuando escribiéramos la primera línea `bucket = ...` de un subrecurso.

Solo Pregunta B llegó a responderse implícitamente durante el Bloque 2 conceptual (Concepto 1). Warmup real ~5-7 min, dentro del techo.

### Regla derivada del fallo

> **Regla nueva #S12I-1 (candidata):** Al inicio de cada sesión, antes del warmup, **recordar explícitamente el plan de bloques de la sesión de hoy** aunque esté en el prompt de continuación. La suposición "el alumno lo tiene fresco porque lo leyó" es falsa cuando han pasado 2+ días desde la sesión anterior. Coste marginal ~30 segundos, evita 5-10 min de confusión y reformulaciones. Aterrizada por caso positivo real (confusión sobre "lo último fue el vpc_endpoint" cuando en realidad fue el bloque IAM).

## Bloque 2 — Introducción conceptual S3 (3 conceptos con verificación entre cada uno)

Regla máximo 3 conceptos con verificación entre cada uno (S12-F) respetada. Vocabulario nuevo introducido explícitamente ANTES de aparecer en preguntas o HCL (regla S12-D locked).

### Concepto 1 — `aws_s3_bucket` como recurso maestro delgado

Contexto histórico del provider AWS. Versiones < 4.x tenían `aws_s3_bucket` con muchos bloques anidados legacy (`versioning {}`, `server_side_encryption_configuration {}`, `logging {}`, `lifecycle_rule {}`, etc.). En provider 4.x+ HashiCorp/AWS desagregaron a subrecursos separados por concern (`aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block`, `aws_s3_bucket_policy`, `aws_s3_bucket_lifecycle_configuration`, etc.). Análogo al patrón consolidado en S12-F (SGs modernas con reglas separadas) y S12-H (`aws_iam_role_policy_attachment` separado del Role).

Verificación de Concepto 1: alumno predijo empíricamente lo que hacen ambos patrones cuando el HCL declara solo el bucket maestro sin declarar los subrecursos, con un bucket que en AWS ya tiene versioning `Enabled`. Predicción: **"con la versión vieja, lo que haría es decirle que le borre y con la versión nueva pues si no está declarada, que coja el que está por defecto en AWS"**.

Corrección con precisión operativa sin softening:

- **Patrón moderno correcto en intuición pero impreciso en formulación**. No es "coge el default de AWS", es **explicit management scope**: subrecurso declarado → Terraform lo gestiona con reglas Optional+Computed; subrecurso omitido → Terraform no lo gestiona en absoluto (no está en state, no lo compara, AWS mantiene su configuración sin drift).
- **Patrón viejo empíricamente falso en formulación**. La semántica real del patrón viejo era **inconsistente bloque a bloque**: algunos bloques anidados eran Optional+Computed (respetaban lo existente si no los declarabas — como confirmamos en S12-F con `ingress`/`egress` del SG viejo y en S12-G con `route` del RT y `policy` del VPC Endpoint), otros interpretaban ausencia como "borrar". Sin forma de saber cuál era cuál sin docs bloque a bloque. Esa inconsistencia es literalmente por qué HashiCorp/AWS refactorizaron.

Aterrizaje operativo para el Bloque 3 de hoy: cada `aws s3api get-*` que devuelva configuración real → subrecurso a declarar e importar. Cada uno que devuelva "SIN X" → subrecurso a omitir. Semántica binaria clara.

### Concepto 2 — Versioning S3

Tres estados posibles a nivel bucket, expuestos por atributo `versioning_configuration.status`:

- **`Enabled`**: versioning activo. Cada PUT crea nueva versión. DELETE crea "delete marker" pero no borra versiones anteriores. Recuperación tras borrado accidental posible.
- **`Suspended`**: fue activado pero está pausado. Versiones existentes preservadas con `VersionId` real. Escrituras nuevas usan `VersionId = "null"`. Transitorio raro en producción.
- **Nunca activado**: `get-bucket-versioning` devuelve JSON vacío o `Status` ausente. **NO es un estado declarable** — no puedes escribir HCL con `status = "Disabled"` porque no existe ese valor. Es la ausencia del recurso.

Diferencia crítica para brownfield: bucket nunca versioning → **NO importar `aws_s3_bucket_versioning`**. Bucket `Enabled` o `Suspended` → sí importar con status declarado.

Analogía correcta al perfil backend del alumno (aplicando candidata #S12H-analogías, tecnología conocida): **versioning es a S3 lo que Git es a código fuente**. Si un usuario sobrescribe un fichero por error, sin versioning el original está perdido; con versioning se recupera por `VersionId`.

Verificación de Concepto 2: si `get-bucket-versioning` devuelve `{"Status": "Enabled", "MFADelete": "Disabled"}`, ¿importas? ¿Qué valor concreto declaras para `status` en HCL? Alumno respondió: **"si, importo"** y **`Enabled`** literal, string con mayúscula tal como AWS devuelve. Regla S12-D locked reforzada ("la palabra que la consola AWS usa para un concepto es la palabra que Terraform copia").

### Concepto 3 — Public Access Block con 4 booleanos

Contexto histórico: S3 nació en 2006 con ACLs (metadatos legacy por objeto/bucket). Se añadieron bucket policies (JSON estilo IAM) más expresivas. Coexistencia larga → leaks masivos por buckets accidentalmente públicos (Verizon 2017, Accenture 2017, Pentagon 2017, cientos más). AWS respondió en 2018 con **Public Access Block**, capa por encima de ACLs y policies que puede bloquear cualquier configuración pública independientemente.

Los 4 booleanos:

| Booleano | Qué bloquea |
|---|---|
| `block_public_acls` | Impide crear o modificar ACLs públicas nuevas. Existentes siguen. |
| `ignore_public_acls` | Ignora ACLs públicas al evaluar acceso (respetadas pero como si no fueran públicas). |
| `block_public_policy` | Impide crear o modificar bucket policy con statements públicos. |
| `restrict_public_buckets` | Si bucket policy ya es pública, restringe acceso a owner + AWS services autorizados. |

Interpretación operativa: dos sobre ACLs (preventivo + runtime), dos sobre bucket policies (preventivo + runtime). Buena práctica banca/compliance (SOC 2, ISO 27001, PCI DSS): los 4 a `true` en buckets no expuestos públicamente.

Diferencia ACL vs bucket policy aterrizada corta:

- **ACL**: legacy, formato AWS propio (no JSON estilo IAM), grants a `AllUsers` o `AuthenticatedUsers`, expresividad pobre.
- **Bucket policy**: JSON estilo IAM con `Effect`, `Principal`, `Action`, `Resource`, `Condition`. Moderno. Es lo que probablemente NO tenga este bucket — el permiso vive en la IAM policy del Role de EC2 importada en S12-H.

Verificación de Concepto 3: dos preguntas cortas encadenadas.

1. En el caso de este uploads bucket privado con acceso controlado por IAM Role, ¿bucket policy debe existir o no?
2. Si `aws s3api get-bucket-policy` devuelve `NoSuchBucketPolicy`, ¿es problema o estado correcto?

Alumno: **"1. no debería existir, con el IAM Role ya controlamos el acceso. 2. es el estado correcto"**. Ambas correctas al primer intento.

Aterrizaje operativo consolidado: **un solo lugar donde vive el permiso, mejor si es el más específico** (IAM policy attached al Role en este caso). Bucket policy sería redundante o peor, multiplicaría superficie de evaluación y complicaría auditoría compliance. Casos donde sí es necesaria bucket policy (cross-account access, CloudFront OAI, service-to-service via principal específico) no aplican aquí.

## Bloque 3 — Descubrimiento realidad S3 con 11 comandos `aws s3api get-*` sin filtro

Aplicación 4 (en total en el roadmap) de locked ⭐⭐⭐ #S12H-5: `aws <service> get-<resource>` sin `--query`. En S12-H el caso positivo real fue el drift `description` del Role por haber usado `list-*` con filtro. Aquí aplicamos directamente `get-*` completo desde el arranque.

Comandos ejecutados (nota menor: el prompt de continuación cuenta "10" pero son 11 líneas — error tipográfico sin efecto operativo):

```bash
aws s3api head-bucket --bucket toleflaco-task-manager-uploads-2026
aws s3api get-bucket-location --bucket toleflaco-task-manager-uploads-2026
aws s3api get-bucket-versioning --bucket toleflaco-task-manager-uploads-2026
aws s3api get-bucket-encryption --bucket toleflaco-task-manager-uploads-2026
aws s3api get-public-access-block --bucket toleflaco-task-manager-uploads-2026
aws s3api get-bucket-policy --bucket toleflaco-task-manager-uploads-2026 || echo "SIN POLICY"
aws s3api get-bucket-tagging --bucket toleflaco-task-manager-uploads-2026 || echo "SIN TAGS"
aws s3api get-bucket-cors --bucket toleflaco-task-manager-uploads-2026 || echo "SIN CORS"
aws s3api get-bucket-lifecycle-configuration --bucket toleflaco-task-manager-uploads-2026 || echo "SIN LIFECYCLE"
aws s3api get-bucket-notification-configuration --bucket toleflaco-task-manager-uploads-2026
aws s3api get-bucket-logging --bucket toleflaco-task-manager-uploads-2026
```

### Predicciones vs realidad

| Predicción del prompt / profesor | Realidad AWS | Resultado |
|---|---|---|
| Región `eu-west-1` | `eu-west-1` | ✓ |
| Versioning probable `Enabled` | Vacío (nunca activado) | **Falso** — regla ⭐⭐⭐ #S12E-1 aplicada al profesor |
| Encryption SSE-S3 `AES256` | `AES256` + `BucketKeyEnabled: true` + `BlockedEncryptionTypes: [SSE-C]` | ✓ + hallazgo adicional |
| PAB 4 booleanos a `true` | Los 4 a `true` | ✓ |
| Bucket policy probable SIN | `NoSuchBucketPolicy` → SIN POLICY | ✓ |
| Tags `Project = "task-manager"` | `Project = "task-manager"` + `Environment = "learning"` | ✓ base + 1 tag adicional |
| CORS SIN | `NoSuchCORSConfiguration` → SIN CORS | ✓ |
| Lifecycle SIN | `NoSuchLifecycleConfiguration` → SIN LIFECYCLE | ✓ |
| Notification SIN | (vacío literal, sin JSON, sin error) | ✓ con matiz |
| Logging SIN | (vacío literal, sin JSON, sin error) | ✓ con matiz |

### Hallazgos empíricos importantes

**Sub-aprendizaje sobre comportamiento del AWS CLI**: primera pasada de los 11 comandos dejó dudas por outputs "invisibles" (versioning, notification, logging). Segundo pase con delimitadores `echo "--- X ---"` confirmó: los 3 devuelven **string vacío literal** (ni siquiera `{}`, literal nada). No lanzan error (a diferencia de policy/CORS/lifecycle que sí lanzan `NoSuch<X>Configuration`). **Diseño inconsistente del API S3** — algunos endpoints modelan "sin config" como error, otros como string vacío. Registrar mentalmente.

**Hallazgo `BucketKeyEnabled: true`**: optimización S3 que reduce llamadas KMS API. Con SSE-S3 puro (`AES256`) suele ser default `true`, sin efecto operativo visible. Declarable.

**Hallazgo `BlockedEncryptionTypes: {EncryptionType: ["SSE-C"]}`**: feature relativamente reciente que permite bloquear tipos específicos de encryption. **Profesor no lo conocía y anticipó erróneamente "no es declarable"**. Verificación empírica en el plan pre-import de Bloque 5 lo desmintió — aparece como Computed en el schema (ver fallo 2 más abajo).

**Predicción sobre versioning `Enabled` falsa**: el prompt de continuación decía "probable `Enabled` como buena práctica para uploads". Realidad: nunca activado. Aterrizaje: regla ⭐⭐⭐ #S12E-1 (empírico > predicción teórica basada en "buena práctica"). Sin versioning en uploads = si un usuario sobrescribe un fichero, el original está perdido. **Candidato ADR futuro anotado** — decisión revisable en apply, no bloqueante hoy.

### Lista definitiva de imports post-descubrimiento

Sesión más ligera de lo previsto por el prompt (que anticipaba 4-6 imports). Solo 3 subrecursos con configuración real en AWS:

- **Bucket maestro** `aws_s3_bucket.task_manager_uploads` (bucket + 2 tags).
- **Encryption** `aws_s3_bucket_server_side_encryption_configuration.task_manager_uploads` (SSE-S3 AES256 + BucketKeyEnabled).
- **Public Access Block** `aws_s3_bucket_public_access_block.task_manager_uploads` (4 booleanos a `true`).

NO importar: versioning (nunca activado), bucket policy (no existe), CORS (no existe), lifecycle (no existe), notification (vacío), logging (vacío). Ninguno tiene configuración real → no gestionar (aplicando semántica binaria del Concepto 1).

Total imports esperados: **3 recursos**. Serial esperado al cierre: 29 + 3 = **32**. State list: 26 + 3 = **29**.

## Bloque 4 — Import bucket maestro `aws_s3_bucket.task_manager_uploads`

### Decisión de fichero destino

Alumno eligió crear `s3.tf` como fichero nuevo (coherente con patrón S12-H de `iam.tf` separado por concern). Mantiene `main.tf` para red + seguridad + endpoints. Facilita navegación futura y `git blame` limpio.

### Escritura del HCL y verificación conjunta línea por línea

Predicción teórica del profesor sobre atributos declarables mínimos: `bucket` (Required), `tags` (Optional, declarar por ⭐⭐⭐ #10). NO declarar bloques anidados legacy (`versioning {}`, `server_side_encryption_configuration {}`, `logging {}`, etc.). NO declarar `force_destroy` (default `false` es lo seguro).

HCL escrito por el alumno:

```hcl
resource "aws_s3_bucket" "task_manager_uploads" {
  bucket = "toleflaco-task-manager-uploads-2026"
  tags = {
    Project     = "task-manager"
    Environment = "learning"
  }
}
```

Verificación conjunta línea por línea (locked ⭐⭐⭐ #S12F-10, aplicación 1 de S12-I): cerrada limpia. Match exacto del `bucket` contra `head-bucket` output. Match exacto de los 2 tags contra `get-bucket-tagging`. Ausencias verificadas conscientemente (sin bloques anidados legacy = correcto para patrón moderno).

`terraform validate` → `Success!`.

### Ciclo pactado ejecutado

1. **Predicción plan pre-import** (alumno, 4 sub-predicciones):
   - `Plan: 1 to add, 0 to change, 0 to destroy` ✓
   - 26 recursos no se tocan ✓ (matiz: sí se refrescan, no se "cambian")
   - Computed esperados: `id`, `arn`, `timestamps`
   - `tags_all` aparecerá con mismo valor que `tags` ✓
2. **`terraform plan` pre-import**: confirmó predicciones 1, 2, 4. Falsó predicción 3 en `timestamps` — **no aparece ningún atributo timestamp en el output**. `aws_s3_bucket` NO expone `creation_date` como Computed. Aterrizaje: regla ⭐⭐⭐ #S12E-1 aplicada al alumno (intuición razonable pero empíricamente falsa).
3. **Atributos Computed adicionales aparecidos** no anticipados por el alumno: `bucket_domain_name`, `bucket_regional_domain_name`, `hosted_zone_id`, `bucket_namespace` (nuevo para el profesor también, sin verificar), `bucket_prefix`, `bucket_region`, `acceleration_status`, `acl`, `object_lock_enabled`, `policy`, `request_payer`, `website_domain`, `website_endpoint`. **Todos los bloques anidados del schema legacy aparecieron como Computed** (`versioning`, `server_side_encryption_configuration`, `logging`, `cors_rule`, `lifecycle_rule`, `website`, `grant`, `replication_configuration`, `object_lock_configuration`). **Aterrizaje sólido del Concepto 1 del Bloque 2** — el schema mantiene los bloques legacy por retrocompatibilidad, pero como no los declaramos en HCL, quedan Computed sin interferencia. Coexistencia legacy/moderno visible empíricamente.
4. `terraform import aws_s3_bucket.task_manager_uploads toleflaco-task-manager-uploads-2026` → limpio. **Confirmación empírica**: `id = bucket_name` en `aws_s3_bucket` (peculiaridad S3, análoga a IAM Role `id = name`).
5. **Predicción plan post-import** (alumno): `0 to add, 0 to change, 0 to destroy, No changes`. **Sin drift esperado**. Correcta al 100%.
6. `terraform plan` post-import → `No changes` ✓. State serial **30**, `state list = 27`.

Ciclo cerrado sin fricción. **Sin drift oculto** — diferencia clave respecto al Role de S12-H (donde `description` no declarada causó drift). Aquí el descubrimiento previo con `get-bucket-tagging` fue completo (aplicación #S12H-5), y el schema del `aws_s3_bucket` maestro es simple (pocos atributos declarables), lo que redujo superficie de riesgo.

## Bloque 5 — Import encryption `aws_s3_bucket_server_side_encryption_configuration.task_manager_uploads`

### Preparación con Pregunta A del warmup pospuesta resuelta en vivo

Antes de escribir el HCL, resolvimos la Pregunta A pospuesta del Bloque 1. Opciones:

- **A**: `bucket = aws_s3_bucket.task_manager_uploads.id`
- **B**: `bucket = aws_s3_bucket.task_manager_uploads.bucket`
- **C**: `bucket = aws_s3_bucket.task_manager_uploads.arn`

Descarte inmediato de C (schema pide nombre string, no ARN). Entre A y B, alumno eligió **B** con razonamiento correcto (aplicando #S12H-8, atributo semánticamente correcto según lo que el schema del destino pide).

Aterrizaje mnemónico completo de #S12H-8 con 3 casos consolidados:

| Recurso destino | Peculiaridad schema | Atributo semánticamente correcto |
|---|---|---|
| IAM Role (ref desde Instance Profile o Attachment) | `id = name` | `.name` |
| IAM Policy (ref desde Attachment) | `id = arn` | `.arn` |
| S3 Bucket (ref desde subrecursos `aws_s3_bucket_*`) | `id = bucket_name = valor de bucket` | `.bucket` |

Regla operativa consolidada: usar el atributo cuyo nombre coincide con lo que el schema del destino pide semánticamente, aunque `.id` funcione por coincidencia. **Aplicación #3 de #S12H-8 (2 IAM S12-H + 1 S3 aquí)**.

### Traducción JSON → HCL con reglas explícitas (aplicando #S12H-6 correctamente)

Profesor entregó estructura de schema + tabla de correspondencias JSON→HCL + esqueleto vacío, **sin dumpear el HCL completo**. Aplicación correcta de candidata #S12H-6 (aterrizada en S12-H por caso positivo real — dumpeo completo del `jsonencode` de la policy). Reglas de traducción explícitas:

- `"ServerSideEncryptionConfiguration": { ... }` → envoltorio desaparece.
- `"Rules": [ { ... } ]` → bloque anidado `rule { ... }` (nested block, sin `=`, sin comillas, sin corchetes).
- `"ApplyServerSideEncryptionByDefault": { ... }` → bloque anidado `apply_server_side_encryption_by_default { ... }` con conversión PascalCase → snake_case (regla S12-D locked).
- `"SSEAlgorithm": "AES256"` → `sse_algorithm = "AES256"` (mayúscula → minúscula en HCL, valor literal preservado).
- `"BucketKeyEnabled": true` → `bucket_key_enabled = true` (booleano HCL sin comillas).
- `"BlockedEncryptionTypes": {...}` → **profesor dijo "no declarable, verificar empíricamente"** (fallo 2, ver más abajo).

**Aplicación 1 de candidata #S12H-6 en S12-I** (caso normal — aterrizaje operativo sin drift). Alumno tradujo el JSON aplicando las reglas y produjo HCL correcto al primer intento.

### Fallo 1 del profesor — salto de verificación conjunta antes de `validate`

Al final del mensaje de andamiaje, profesor escribió "Escríbelo y pégalo" sin recordar explícitamente el paso intermedio de S12F-10 (verificación conjunta línea por línea ANTES de `validate`). Alumno ejecutó orden natural: escribir → `validate` → `plan`. **Verificación conjunta pre-validate saltada** — análogo exacto al fallo del Bloque 6 de S12-H (Policy Attachment con `.id` comodín).

Detección post-facto: `validate` y `plan` salieron OK por suerte + simplicidad del subrecurso. Reparación: verificación conjunta ejecutada post-facto para no perder la disciplina. HCL confirmado limpio en 9 líneas.

Responsabilidad principalmente del profesor. Regla derivada:

> **Refuerzo operativo #S12I-1 (candidata):** Al final de cada mensaje que termina con "escríbelo tú" en tareas de HCL, **explicitar "y pásamelo ANTES de `validate` para verificación conjunta"**. La instrucción implícita "orden pactado del ciclo" no basta cuando el mensaje anterior es denso o el alumno lleva ritmo. Coste marginal ~5 palabras, evita saltos de S12F-10. **Aplicación 1 (caso positivo real S12-I Bloque 5)**. Aterrizaje inmediato en Bloque 6 con éxito.

Diferencia respecto a S12H-6 en función: S12H-6 protege contra dumpeo de solución completa por el profesor. S12I-1 protege contra salto de verificación conjunta por el alumno cuando el profesor no lo explicita.

### Fallo 2 del profesor — afirmación no verificada sobre `blocked_encryption_types`

Profesor dijo en la traducción JSON→HCL: "`BlockedEncryptionTypes` NO es declarable en el schema, verificaremos empíricamente". **Falso empírico** — el `terraform plan` pre-import lo mostró como Computed:

```
+ rule {
    + blocked_encryption_types = (known after apply)
    + bucket_key_enabled       = true
    ...
}
```

Está en el schema del subrecurso. Debería haber sido "verificar en docs" antes de afirmar. Análogo estructural al fallo `description` del Role en S12-H ("no aparece → no tiene" basado en `list-*` con filtro).

Reparación en caliente: profesor asumió el error sin softening, corrigió a "es Computed en el schema, valor real absorbido en state al importar". Aterrizaje: **cuando aparece un atributo AWS nuevo (como `BlockedEncryptionTypes`), la respuesta correcta es "verificar en docs" antes de decidir si es declarable, no asumir por defecto que no lo es**. Regla del prompt aplicada retroactivamente ("cuando no sé algo, lo digo"). Confirmado en post-import: Optional+Computed, absorbido sin drift.

HCL final del subrecurso (alumno):

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "task_manager_uploads" {
  bucket = aws_s3_bucket.task_manager_uploads.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
```

### Ciclo pactado ejecutado

1. `terraform validate` → OK.
2. `terraform plan` pre-import → `+ create`, 1 to add, con `blocked_encryption_types = (known after apply)` visible en el bloque `rule`. `region = "eu-west-1"` Computed heredado del provider block.
3. `terraform import aws_s3_bucket_server_side_encryption_configuration.task_manager_uploads toleflaco-task-manager-uploads-2026` → limpio. ID = nombre del bucket (mismo patrón que el bucket maestro).
4. **Predicción plan post-import** (alumno, 3 sub-predicciones): `No changes`, sin drift en `blocked_encryption_types` "creo que es Optional+Computed", sin drift en otros atributos declarados. **Las 3 correctas al 100%**.
5. `terraform plan` post-import → `No changes` ✓. **Confirmación empírica**: `blocked_encryption_types = ["SSE-C"]` en AWS absorbido en state, no declarado en HCL, sin drift. **Aplicación 4 (total roadmap) de locked ⭐⭐⭐ #S12F-1**. State serial **31**, `state list = 28`.

**Aterrizaje pedagógico importante**: primera vez en la sesión que el alumno aplica **la regla teórica antes de la evidencia empírica** (Optional+Computed) y acierta. Contrasta con S12-H donde la predicción "no habrá drift" del Role fue falsa por drift `description`. Diferencia clave: en S12-H no se aplicó `get-*` completo antes de escribir HCL. En S12-I sí. **La combinación `#S12H-5 + #S12F-1` produce ciclos limpios**.

## Bloque 6 — Import Public Access Block `aws_s3_bucket_public_access_block.task_manager_uploads`

### Escritura del HCL con verificación conjunta ANTES de validate (aplicando #S12I-1)

Refuerzo operativo #S12I-1 aterrizado en el mensaje del profesor: instrucción explícita "pásamelo ANTES de `validate` para verificación conjunta". Aplicación 2 (caso positivo real en misma sesión).

Estructura del schema (verificada en docs del provider por el profesor): **schema plano**, sin nested blocks. Los 4 booleanos van directamente en el bloque `resource`, al mismo nivel que `bucket`.

Correspondencias JSON → HCL directas (`PublicAccessBlockConfiguration` desaparece como envoltorio, 4 booleanos con PascalCase → snake_case).

Nota preventiva pactada anti-bug: **default del schema Terraform es `false` para los 4 booleanos, pero AWS tiene los 4 a `true`**. Si el alumno se olvida uno, plan post-import propondría cambiar de `true` → `false`. Riesgo real. Aunque son probablemente Optional+Computed (schema respeta valores existentes), buena práctica brownfield es **declararlos explícitamente todos** — no confiar en absorción silenciosa cuando son los 4 booleanos críticos de compliance.

HCL escrito por el alumno con estilo alineado en `=`:

```hcl
resource "aws_s3_bucket_public_access_block" "task_manager_uploads" {
  bucket                  = aws_s3_bucket.task_manager_uploads.bucket
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
```

**Verificación conjunta línea por línea** (locked ⭐⭐⭐ #S12F-10, aplicación 3 de S12-I): cerrada limpia. Match exacto de los 4 booleanos contra `get-public-access-block`. `bucket = ...bucket` aplicando #S12H-8 (aplicación 4 en S12-I). Sin nested blocks → sin riesgo `}` seguido de `{` (candidata #S12H-7 no aplica aquí, schema plano).

### Ciclo pactado ejecutado

1. `terraform validate` → OK.
2. **Predicción plan pre-import** (alumno): `1 to add, 0 to change, 0 to destroy`, Computed esperados `bucket, 4 booleanos, id`. **Correcta con incompletitud**. Alumno no respondió la sub-pregunta 3 sobre atributos extra en el schema no vistos en AWS output (análogo `blocked_encryption_types`). Realidad: **aparece `region = "eu-west-1"`** heredado del provider block. Sin otros atributos extra — el schema del PAB es plano y transparente. Aterrizaje: no todos los subrecursos S3 tienen atributos ocultos.
3. `terraform plan` pre-import: 4 booleanos con valor literal `true`, `id = (known after apply)`, `region = "eu-west-1"`. Sin sorpresas más allá de `region`.
4. `terraform import aws_s3_bucket_public_access_block.task_manager_uploads toleflaco-task-manager-uploads-2026` → limpio. ID = nombre del bucket (patrón consistente entre los 3 subrecursos S3).
5. **Predicción plan post-import** (alumno, 3 sub-predicciones): `No changes`, sin drift en 4 booleanos, sin drift en `region`. **Las 3 correctas al 100%**.
6. `terraform plan` post-import → `No changes` ✓. State serial **32**, `state list = 29`.

## Bloque 9 — Verificación intermedia

Ejecutada antes de commit + push para confirmar estado pactado por el prompt de continuación.

- `aws s3 cp .../terraform.tfstate - | jq '.serial'` → **32** ✓ (29 + 3 mutaciones exactas)
- `terraform state list | wc -l` → **29** ✓ (26 + bucket + encryption + PAB)
- `terraform state list | grep s3` → **6 líneas** (no 4 como predijo el profesor)

### Fallo 3 del profesor — predicción incompleta de `grep s3`

Profesor anticipó 4 líneas en el `grep s3` (3 S3 nuevos + VPC Endpoint). **Falso empírico**: salieron 6 líneas — además se cazaron `aws_iam_policy.s3_uploads_rw` y `aws_iam_role_policy_attachment.ec2_task_manager_s3_uploads_rw` (importados en S12-H, contienen "s3" en el nombre por coincidencia léxica).

Aterrizaje menor sin softening: **`grep` sobre strings genéricos captura falsos positivos por coincidencias léxicas en nombres de recursos**. Cuando quieras filtrar por tipo de recurso literal, usar `grep "^aws_s3_bucket"` (regex de inicio de línea). Sin efecto operativo hoy, solo mala anticipación del profesor. Análogo estructural al fallo de `terraform fmt sin efecto` de S12-H (ambos son "afirmar sin verificar").

## Bloque 10 — Commit + push con triple confirmación (⭐⭐⭐ #31, 6ª aplicación consecutiva, primera limpia sin amend desde S12-G)

### Redacción del mensaje bilingüe al primer intento

Aterrizaje S12-H aplicado explícitamente al arranque del bloque: **redactar mensaje con estructura correcta al primer intento**, no como en S12-H con 2 `--amend` consecutivos por bugs de formato. Alumno redactó en editor externo (VS Code) y pegó texto plano para verificación conjunta ANTES de `git add`.

Contenido cubierto en el mensaje: subject `feat(infra): import uploads bucket + encryption + PAB`, body EN con contexto brownfield + patrón moderno vs viejo + atributos declarados vs Optional+Computed + rationale de omisiones (versioning, policy, CORS, lifecycle, notifications, logging todos absentes) + pendiente EC2/RDS a S12-J, separador `---`, body ES con mismo contenido esencial sin acentos ni ñ.

**Verificación conjunta del mensaje** (locked ⭐⭐⭐ #S12F-10, aplicación 4 de S12-I sobre commit message):

- Subject line: tipo(scope) + imperativo + 51 caracteres (< 72) ✓
- Estructura separadores: línea vacía tras subject, `---` en línea propia, body ES tras separador ✓
- Body ES verificación "sin acentos ni ñ": `patron` (no patrón), `contemporaneo` (no contemporáneo), `separacion` (no separación), `mas` (no más), `restriccion` (no restricción). Todas las palabras críticas verificadas ✓
- Coherencia semántica EN↔ES: simétrica, sin desalineación ✓

**Sin bugs de formato detectados**. Aterrizaje S12-H aplicado con éxito.

### Ciclo git ejecutado limpio

`git add s3.tf` → `git status` (staged: `new file: s3.tf`, sin residual) → `git diff --staged` (25 líneas del fichero, 3 recursos en orden bucket→encryption→PAB, alineación cosmética de `terraform fmt` aplicada en `tags = {}` del bucket maestro — sin efecto operativo).

`git commit` sin `-m` (editor multilínea, alumno pegó mensaje bilingüe completo, guardó y cerró).

`git log -1 --format=full` (locked ⭐⭐⭐ #30): hash `fcb520f337e6cf48b00b6ec8a1956c3928257d83`, Author + Committer `Tole <manutol@gmail.com>`, cuerpo del commit completo con los 12 párrafos EN + separador + 12 párrafos ES sin acentos ni ñ. **Mensaje correcto al primer intento — 0 `--amend`**.

### Triple confirmación conjunta (6ª aplicación consecutiva)

```
Tole confirma: SÍ cuerpo del commit revisado y correcto según git log -1 --format=full
Claude confirma: SÍ
Claude autoriza push: SÍ
```

`git push origin main` → `83d1f8b..fcb520f main -> main`. Push limpio.

`git log --oneline -5` → HEAD en `fcb520f (HEAD -> main, origin/main)` encima de `83d1f8b`, `f395d8b`, `6e40c94`, `b7c1ad4`. `git status` → `working tree clean`.

**Regla ⭐⭐⭐ #31 aterrizada 6ª vez consecutiva**. Aterrizaje operativo consolidado: aprendizaje S12-H sobre "redactar al primer intento" internalizado por el alumno. Extensión de la regla operativa: la ceremonia protege contra bugs de código, bugs de formato del mensaje **y** contra reintroducción de errores por prisa al cierre.

## Aprendizajes empíricos consolidados en S12-I

### Promoción desde candidata a **locked ⭐⭐⭐**

1. **⭐⭐⭐ #S12H-8 (locked S12-I):** Referencias HCL a recursos deben usar el atributo semánticamente correcto según el schema del destino, no `.id` como comodín, aunque coincidan por peculiaridades del provider. Reglas mnemónicas consolidadas:
   - IAM Role (`id = name` → `.name`)
   - IAM Policy (`id = arn` → `.arn`)
   - S3 Bucket (`id = bucket_name = valor de bucket` → `.bucket`)
   
   Total 5 aplicaciones acumuladas desde su descubrimiento (2 IAM S12-H + 3 S3 S12-I). Criterio locked cumplido con margen: mezcla de casos normales limpios (2 en S12-H y 3 en S12-I) + 1 corrección post-hoc (Attachment S12-H con `.id` que salía OK por coincidencia). **Promocionable a ⭐⭐⭐ al cierre de S12-I** — regla mnemónica extensible a futuros recursos (verificar peculiaridad del schema del destino, elegir atributo semánticamente coincidente).

### Refuerzo de reglas locked ya existentes

2. **⭐⭐⭐ #S12H-5 reforzada**: `aws <service> get-<resource>` sin filtro antes de HCL. **3 aplicaciones normales limpias en S12-I** (bucket, encryption, PAB). Total acumulado desde su aterrizaje en S12-H: 6 aplicaciones (1 caso positivo real S12-H + 5 casos normales limpios). Contraste directo con el ciclo Role de S12-H (donde no se aplicó y hubo drift `description`) vs los 3 ciclos S12-I (donde sí se aplicó y no hubo drift). **La combinación `#S12H-5 + #S12F-1` produce ciclos limpios sin drift oculto**.

3. **⭐⭐⭐ #S12F-1 reforzada**: Optional+Computed absorbe pre-existing values sin proponer cambio. **Caso positivo empírico en S12-I con `blocked_encryption_types = ["SSE-C"]` en encryption** — atributo Computed presente en AWS, no declarado en HCL, absorbido sin drift. Aplicación 4 (total roadmap) confirmada empíricamente.

4. **⭐⭐⭐ #31 aterrizada 6ª vez consecutiva**: triple confirmación conjunta pre-push. **Primera aplicación limpia sin amend previos desde S12-G**. Aterrizaje operativo: el aprendizaje S12-H (2 amend por bugs de mensaje) se internalizó y se aplicó al arranque del Bloque 10 con éxito. Mensaje correcto al primer intento.

### Nuevas reglas empíricas de S12-I (candidatas para promoción futura)

5. **⭐⭐⭐ #S12I-1 (candidata):** Al final de cada mensaje que termina con "escríbelo tú" en tareas de HCL, explicitar "y pásamelo ANTES de `validate` para verificación conjunta". La instrucción implícita "orden pactado del ciclo" no basta cuando el mensaje anterior es denso o el alumno lleva ritmo. Prevención directa del salto de S12F-10. **1 aplicación en S12-I (caso positivo real detectado en Bloque 5 → aterrizado en Bloque 6 con éxito, misma sesión)**. Falta 2-3 aplicaciones más en sesiones futuras para promoción a locked.

6. **⭐⭐⭐ #S12I-2 (candidata, meta-pedagógica):** Al inicio de cada sesión, antes del warmup, recordar explícitamente el plan de bloques de la sesión de hoy aunque esté en el prompt de continuación. La suposición "el alumno lo tiene fresco porque lo leyó" es falsa cuando han pasado 2+ días. Coste marginal ~30 segundos, evita 5-10 min de confusión y reformulaciones. **1 aplicación en S12-I (caso positivo real — confusión "lo último fue el vpc_endpoint" cuando en realidad fue el bloque IAM)**. Falta aplicaciones adicionales.

7. **Anotación menor (no candidata a regla) sobre comportamiento AWS CLI**: `aws s3api get-bucket-versioning`, `get-bucket-notification-configuration`, `get-bucket-logging` devuelven **string vacío literal** (ni JSON `{}`, ni error) cuando no hay configuración. A diferencia de `get-bucket-policy`, `get-bucket-cors`, `get-bucket-lifecycle-configuration` que sí lanzan `NoSuch<X>Configuration` como error. **Diseño inconsistente del API S3**. Registrar mentalmente para no confundir "vacío = sin config" con "vacío = error silencioso" cuando aparezca en futuros descubrimientos.

## Estado exacto al cierre de S12-I

Terraform:
- CLI 1.15.8, provider AWS 6.59.0 (~> 6.58 en versions.tf).
- Backend S3 con `use_lockfile = true`.
- State en `s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate`, serial **32**, lineage sin cambios, resources = **29**.
- `terraform plan` global = `No changes`.

Ficheros infra/:
- `versions.tf` — sin cambios.
- `main.tf` — 22 recursos (14 red + 7 seguridad + 1 VPC Endpoint), sin cambios en S12-I.
- `iam.tf` — 66 líneas, 4 recursos IAM, sin cambios.
- `s3.tf` — **fichero nuevo creado en S12-I, 25 líneas, 3 recursos S3**.
- `.terraform.lock.hcl` — sin cambios.

Recursos en state (29):
- **Red (14, desde S12-E)**: `aws_vpc.main`, 4 subnets, `aws_internet_gateway.task_manager`, 3 RTs, `aws_route.public_to_igw`, 4 associations.
- **Seguridad (7, desde S12-F)**: 2 contenedores SG + 3 reglas ec2 + 2 reglas db.
- **Conectividad interna (1, desde S12-G)**: `aws_vpc_endpoint.s3` con 3 RTs asociadas.
- **Identidad IAM (4, desde S12-H)**: Role + Policy + Attachment + Instance Profile.
- **Aplicación S3 (3, nuevos en S12-I)**:
  - `aws_s3_bucket.task_manager_uploads` (bucket `toleflaco-task-manager-uploads-2026`, 2 tags `Project = "task-manager"` + `Environment = "learning"`).
  - `aws_s3_bucket_server_side_encryption_configuration.task_manager_uploads` (SSE-S3 `AES256` + `bucket_key_enabled = true`, `blocked_encryption_types = ["SSE-C"]` absorbido en state como Computed).
  - `aws_s3_bucket_public_access_block.task_manager_uploads` (4 booleanos a `true`).

Commit desde S12-H:
- `fcb520f feat(infra): import uploads bucket + encryption + PAB` (mensaje bilingüe correcto al primer intento, sin `--amend`).

Pendiente commitear en frío:
- `bitacora/Sesion12-Import-Checklist.md` con casillas S3 (bucket + encryption + PAB) tachadas.
- `bitacora/Sesion12-I-AWS-Diario.md` (este documento).

RDS: `stopped`. **Próximo deadline auto-arranque ~15-16 sep** (contador reseteado el 6 sep en S12-G, ventana casi cerrada). Si S12-J se hace después del 15 sep, arrancar+parar manual antes de tocar Terraform.

IP casa: **95.121.15.184** (casa de los gatos, Reinosa). Rotó desde `88.11.202.24` de S12-H. Sin efecto operativo para S3 (API HTTPS con IAM). **Anotar para S12-J**: SG de acceso a EC2 tiene `88.11.202.24` whitelisted en Nestares — desde esta IP no entra. Si S12-J se hace desde casa de los gatos, actualizar SG previamente o volver a Nestares.

Deuda técnica anotada acumulada:
- **S12-G #1** (candidato ADR-A13): RT pública asociada al VPC Endpoint sin valor operativo. Corrección diferida a primer apply del roadmap.
- **S12-H #1** (candidato ADR-A14): Inline policy `AWSRevokeOlderSessions` excluida del scope Terraform.
- **S12-I #1** (candidato ADR-A15): S3 uploads bucket sin versioning en AWS. Decisión revisable en apply futuro — para "learning" es aceptable, para producción real de banca no lo sería. Sin corrección hoy.

## Pendientes para S12-J (~2h estimadas, matutinas)

Bloque de cómputo (EC2 instance) + bloque de base de datos (RDS instance). Recursos AWS pendientes de import:

1. **EC2 instance** `task-manager-ec2` (`aws_instance`). Anticipación: dependencias hacia `aws_subnet` (public), `aws_security_group.ec2`, `aws_iam_instance_profile.ec2_task_manager` (todos importados). Atributos densos a verificar con `get-*` completo: user_data script, root_block_device, monitoring, IMDSv2 hop limit.
2. **RDS instance** `task-manager-db` (`aws_db_instance`). Anticipación: dependencias hacia `aws_subnet` (private via DB Subnet Group — ¿existe DB Subnet Group separado?), `aws_security_group.db`. Atributos densos a verificar: engine version, instance class, storage, backup retention, master credentials (probablemente sensibles — atención especial).

Prioridad si el tiempo se acorta: EC2 completo hoy, RDS a S12-K junto con primer apply del roadmap. Cerrar bloques coherentes por sesión.

### Verificaciones empíricas esperadas en S12-J

- **`aws_instance`** con muchos atributos declarables (a diferencia de `aws_s3_bucket` que era delgado). Anticipar `Optional+Computed` en `associate_public_ip_address`, `source_dest_check`, `monitoring`, `metadata_options`. Verificar empíricamente con `aws ec2 describe-instances` sin filtro.
- **`aws_db_instance`** con atributos sensibles (credenciales). Anticipar que `password` NO sale en `describe-db-instances` — requiere tratamiento especial (posiblemente `lifecycle { ignore_changes = [password] }`).
- **Verificación DB Subnet Group**: `aws rds describe-db-subnet-groups` para descubrir si el subnet group existe como recurso separado a importar (`aws_db_subnet_group`).
- **Address propuestos**: `aws_instance.task_manager_ec2`, `aws_db_instance.task_manager_db`, `aws_db_subnet_group.task_manager` (si existe).

### Reglas operativas OBLIGATORIAS para S12-J

- **Al arrancar**: Bloque 0 completo con 5 comandos habituales. Esperado: serial 32, `state list = 29`, RDS `stopped`, IP (verificar posible rotación de nuevo).
- **Aterrizaje explícito #S12I-2 (candidata)**: recordar plan de bloques de la sesión al inicio, antes del warmup.
- **Warmup MÁXIMO 2 preguntas**, 5 min techo (locked ⭐⭐⭐ #S12H-1).
- **Aterrizaje explícito #S12I-1 (candidata)**: al final de cada "escríbelo tú" en HCL, decir "pásamelo ANTES de `validate`".
- Ciclo pactado obligatorio con predicción escrita en cada paso.
- Vocabulario nuevo (EC2 instance types, IMDSv2, RDS backup windows, DB Subnet Group) introducido explícitamente antes de aparecer. Máximo 3 conceptos consecutivos.
- **`aws ec2 describe-instances` sin filtro** y **`aws rds describe-db-instances` sin filtro** antes de HCL (locked ⭐⭐⭐ #S12H-5).
- Verificación conjunta línea por línea del HCL antes de validate (locked ⭐⭐⭐ #S12F-10).
- Referencias HCL con atributo semánticamente correcto (locked ⭐⭐⭐ #S12H-8 desde S12-I): investigar peculiaridad del schema para `aws_instance` (¿`id = i-...` opaco?) y `aws_db_instance` (¿`id = db_identifier`?) — verificar en docs.
- Triple confirmación conjunta obligatoria antes de git push (locked ⭐⭐⭐ #31).
- **Bitácora S12-I releída antes del warmup** — regla operativa 48-72h.
- **Verificar estado RDS al arrancar** — deadline auto-arranque ~15-16 sep.
- **Verificar IP casa** — si rotó de nuevo, actualizar SG del EC2 antes de intentar SSH.

### Cosas que NO hacer en S12-J

- NO importar la deuda técnica S12-G #1 (RT pública en VPC Endpoint) — diferida a apply.
- NO importar la deuda técnica S12-I #1 (versioning ausente en bucket) — diferida a apply.
- NO exponer credenciales de RDS en HCL — usar `ignore_changes` o data sources referenciados.
- NO usar patrón viejo de bloques anidados si algún subrecurso EC2/RDS lo tiene disponible.
- NO ejecutar apply de nada — reglas ⭐⭐⭐ #14 + #17.
- NO dumpear traducciones completas si aparecen (candidata #S12H-6 aplicada con éxito en S12-I).
- NO analogías a Kubernetes o tecnologías del roadmap futuro (candidata #S12H-analogías).
- NO saltarse verificación conjunta antes de validate — refuerzo #S12I-1 aplicado.

## Meta-observaciones de método

1. **Densidad pedagógica media en S12-I**: 1 promoción a locked (#S12H-8) + 2 reglas candidatas nuevas (#S12I-1, #S12I-2) + 3 fallos menores de método del profesor asumidos sin softening. Ratio "aterrizajes de regla por hora" ~1.5, similar a S12-H. Sesión más corta (~1h 40min vs ~4h 15min de S12-H) pero con densidad comparable por hora. Explicable por (a) primera vez con patrón moderno S3 (nueva peculiaridad del schema), (b) confusión inicial del alumno detectada y reparada.

2. **Confusión inicial del alumno sobre "lo último fue el vpc_endpoint"** — evidencia empírica de que la relectura de bitácora "ayer" no garantiza aterrizaje operativo. El aprendizaje se consolida con **releer + verificar contra HCL real al arrancar**. Aterrizaje operativo: si el alumno anuncia "sí releí ayer" pero luego el recuerdo no encaja con el HCL delante, pausa y verificar antes de continuar. Regla candidata #S12I-2 derivada.

3. **3 fallos menores de método del profesor en la sesión, sin softening**:
   - (a) "Escríbelo y pégalo" sin recordar S12F-10 → salto de verificación conjunta pre-validate en Bloque 5. Aterrizaje: refuerzo #S12I-1.
   - (b) Afirmación no verificada "`blocked_encryption_types` no es declarable" → falso empírico. Aterrizaje: cuando aparece atributo AWS nuevo, "verificar en docs" > asumir. Análogo estructural al fallo `description` del Role en S12-H.
   - (c) Predicción incompleta de `grep s3` (4 líneas vs 6 reales por coincidencia léxica IAM). Aterrizaje menor: `grep` sobre strings genéricos captura falsos positivos, usar regex de inicio de línea cuando importa.
   
   Los 3 fueron detectados: (a) por el propio profesor con revisión post-facto, (b) por el output del `plan` empírico, (c) por comparación con el output real. **Coincidencia**: todos son casos de "asumir en lugar de verificar" — mismo antipatrón meta detectado en S12-H, esta vez con menor magnitud y detección más rápida. Regla meta S12-H aplicada en caliente varias veces sin quiebre operativo grande.

4. **Warmup con reformulación in-situ por confusión inicial** (regla operativa S12-H aplicada). Alumno pidió saltar Pregunta A. Profesor aceptó sin defensa del formato. Pregunta A resuelta en vivo en Bloque 5 cuando el contexto empírico la hizo natural. Aterrizaje operativo: **cuando la Pregunta A queda pospuesta, no forzarla — resolverla en el momento operativo donde emerge naturalmente**. Sin coste pedagógico, mejor timing.

5. **Sesión más corta que estimada (1h 40min vs 2h-2h30min pactadas)** — primera sesión del roadmap donde termina bajo estimación. Explicable por (a) 3 imports en vez de 4-6 anticipados (descubrimiento reveló bucket sin versioning + sin CORS + sin lifecycle + sin notification + sin logging), (b) ciclo pactado internalizado por el alumno (predicciones cada vez más certeras, sin fricción), (c) commit correcto al primer intento (0 amend). **Aprendizaje operativo**: estimación futura para sesiones de subrecursos S3 con descubrimiento previo puede ser 1h 30min - 2h en lugar de 2h - 2h 30min.

6. **Triple confirmación 6ª aplicación limpia sin amend — primera vez desde S12-G**. Aprendizaje S12-H internalizado (2 amend por bugs de mensaje) aplicado con éxito en S12-I. Aterrizaje operativo: la regla ⭐⭐⭐ #31 se consolida no solo por su aplicación sino por la mejora en la calidad del mensaje redactado al primer intento. Formulación memorable adicional: **"la mejor triple confirmación es la que no tiene que cazar nada"**.

7. **Recalibración de tiempo en caliente al inicio ("planificamos como 2h-2h30min")** — regla operativa S12-D aplicada correctamente. Alumno explicitó "vamos a empezar como si tuviera 2 horas o 2 horas y media, vale??" al abrir. Profesor aceptó y ajustó plan del prompt (que originalmente decía "~2h honestas para 4-6 imports"). Aterrizaje: **la ventana real al inicio siempre pesa más que la estimación del prompt de continuación** — el prompt es intención, no dogma (regla ⭐⭐⭐ #25 S12-D reforzada).

8. **Bitácora escrita por el profesor en modo "notas borrador"** a petición del alumno tras el push. **Este documento requiere revisión y adaptación por el alumno antes de commitear**. No es producto final — es andamiaje para acelerar el paso "en frío" sin sacrificar la reflexión personal.
