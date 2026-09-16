# Sesión 12-L — Milestone del módulo AWS brownfield: primer y segundo `terraform apply` del roadmap con ciclo pactado completo, 4 ADRs formales creados en `decisions/`, dos saltos de método del alumno corregidos, tres correcciones consecutivas de vocabulario técnico sin introducción explícita por parte del profesor

**Fecha:** miércoles 16 septiembre 2026 (ventana matutina 06:00 – 08:47, ~2h 47min efectivos). Sesión con arranque anticipado por decisión del alumno la noche anterior tras recorte pactado en martes 15 sep (1h disponible, sobrecarga reconocida, aplazamiento a la mañana siguiente con ventana completa). Sueño corto reconocido al arrancar por despertar prematuro ("me he dormido un poco, todos los días madrugando se nota") y contexto emocional bajo por tema trabajo explicitado sin softening por el alumno ("no estoy bien por el tema del trabajo").
**Duración total:** ~2h 47min honestas. Estimación inicial del prompt de continuación S12-L: 2h - 3h honestas para milestone denso. **Desviación real +17min sobre el techo pactado de 2h 30min** por A13 pactada en caliente en tiempo extra tras recalibración horaria del profesor (error inicial de cálculo: reportó 07:40 cuando eran 08:10, ~30min menos disponibles de lo que estimó — aplicación 1ª ⭐⭐⭐ #S12E-1 al profesor en la sesión).
**Estado:** Cierre limpio del **milestone del módulo AWS brownfield**. **2 `terraform apply` reales** ejecutados con protocolo completo (predicción escrita + verificación línea por línea + triple confirmación conjunta pre-apply + apply interactivo sin `-auto-approve` + verificación post-apply en 3 dimensiones). **4 ADRs formales** creados en `decisions/`: ADR-013, ADR-014, ADR-015, ADR-019. **3 commits limpios** pusheados a `origin/main` (`3a696c5`, `c7d3ea1`, `7f6637a`) con **11ª aplicación consecutiva de la regla ⭐⭐⭐ #31** en git push y **1ª y 2ª aplicaciones de la extensión de #31 al `terraform apply`** en la historia del roadmap. State serial: 35 → 36 → 37. Total 33 recursos gestionados en Terraform state (era 32 al arrancar; +1 por `aws_s3_bucket_versioning`, 0 neto por A13 que solo modificó atributo de recurso existente). RDS `stopped` reportado al arrancar por el alumno, sin acción. IP casa `88.11.252.248` (Nestares, mismo prefijo /16 que S12-K aunque el 3er octeto cambió respecto al valor del prompt de continuación, sin impacto operativo). Sesión con **densidad emocional alta anticipada por primer apply del roadmap**, atenuada empíricamente por disciplina de método intacta bajo carga externa (sueño corto + tema trabajo). Bloque 11 (checklist + bitácora S12-L) pactado en frío al día siguiente.

## Objetivo pedagógico

Cerrar el bloque de import brownfield en modo activo — refactor de deudas técnicas priorizadas con `apply` explícito. Objetivos paralelos: (i) aterrizar el formato Michael Nygard de ADRs formales como andamiaje transferible a revisión de PR banca, (ii) ejecutar el primer `terraform apply` del roadmap con el ciclo pactado completo bajo densidad emocional real, (iii) aplicar el mapping Cat 1/2/3/4 aterrizado en S12-K a `create` desde cero (patrón operativo del 90% del trabajo IaC real en banca — crear infra desde HCL, no importar), (iv) verificar empíricamente la regla candidata #S12K-2 (Argument Reference vs plan real) en al menos 1 aplicación adicional para maduración a locked, (v) mantener aterrizaje S12-H sostenido (redacción bilingüe correcta al primer intento sin amend) 5ª sesión consecutiva.

El objetivo se cumplió íntegramente en scope técnico. Objetivo emergente no planificado y pactado en caliente: **A13 ejecutada en tiempo extra** tras recalibración horaria del profesor, aportando 2ª aplicación de la extensión de #31 al `apply` en la misma sesión y aterrizaje empírico de la distinción `add / change / destroy` categorías en Terraform.

## Ventana martes 15 sep (sesión frustrada por sobrecarga)

Contexto operativo relevante para la bitácora completa: el arranque original de S12-L fue el martes 15 sep tarde. El alumno reportó **1h disponible** vs plan pactado de 2h - 3h honestas, más reconocimiento explícito de sobrecarga por densidad del prompt de continuación (*"hay tantas reglas que tengo buena memoria pero no tanta"*). Profesor aplicó regla S12-H reforzada — aceptar cambio de método por fricción real, recortar scope sin defensa del plan. **Propuesta de aplazamiento pactada explícitamente**: sesión completa el miércoles temprano 06:00 con ventana honesta de 2h 30min. Ventaja identificada por el profesor: *"el milestone del primer apply merece ventana honesta, no un forzado en 1h con sobrecarga reconocida"*. Alumno aceptó.

Anotable como **caso positivo de aplicación de la regla operativa** "cuando el alumno reporta desproporción de tiempo, es señal fiable de recalibración de estimación, no bandera de queja a suavizar" — combinada con regla derivada "cuando el alumno emite señal preventiva de sobrecarga, respuesta operativa es recortar/aplazar sin defensa del plan pactado". Aplicación limpia. Anotable también: **primer aplazamiento pactado de sesión completa en el roadmap** (no recorte in-caliente, aplazamiento a día siguiente con ventana honesta) — precedente operativo transferible.

Durante la ventana martes también emergieron 2 correcciones de vocabulario por el profesor (analizadas en la sección "Correcciones de método por vocabulario del profesor" más abajo): "extensión de #31" sin introducción explícita + "ADR" como abreviatura sin explicar. Ambas detectadas y corregidas antes del aplazamiento.

## Bloque 0 — Verificación al arranque (S12-L versión definitiva, miércoles 06:00)

Sesión con hueco de **~15h 30min** desde el cierre de la ventana martes 15 sep (última interacción ~14:30 del martes). Hueco > 6h por tanto Bloque 0 completo obligatorio con protocolo reforzado. Bitácora S12-K releída el día anterior (martes 15 sep) — regla operativa 48-72h aplicable, aterrizaje limpio.

Datos reportados por el alumno en el prompt de arranque del miércoles:

- Cuánto rato disponible: 2h 30min declaradas (06:00 – 08:30 techo).
- Estado emocional: reconocido bajo por tema trabajo + sueño corto por despertar prematuro. Anotado sin softening por el profesor, con explicitación de la regla operativa: *"si aparece señal de sobrecarga durante la sesión, recortamos scope sin drama"*.
- Sitio de conexión: Nestares (confirmado explícitamente).
- Estado RDS: `stopped` reportado (parada manual el 13 sep post-auto-arranque). Sin cambio esperado.
- IP casa: `88.11.252.248`. Cambió respecto al valor del prompt de continuación (`88.11.202.24`) en el 3er octeto, sin cambio de prefijo /16 (Nestares confirmado). No bloqueante para el apply — no toca SG ingress rules.

Los 6 puntos empíricos de la verificación pactada ejecutados en un solo bloque compuesto por el alumno (`git log --oneline -5 && git status && terraform plan && terraform state list | wc -l && aws s3 cp ... | jq '.serial' && aws rds describe-db-instances ...`):

- `git log --oneline -5` → HEAD en `013102d docs(bitacora): add S12-K diary and update import checklist`, encima de `d6880b1 feat(infra): import EC2 instance and RDS instance`. **Nota**: el prompt de continuación S12-L anticipaba *"bitácora S12-K + checklist actualizado pendientes de commit en frío (hash <verificar con git log --oneline -5 al arrancar>)"*; empíricamente `013102d` ya estaba pusheado — commit del diario cerrado entre el sábado 12 sep y hoy miércoles 16 sep. Anotable como aplicación limpia del racional "verificar en warmup, no asumir del prompt de continuación".
- `git status` → `working tree clean`, `Your branch is up to date with 'origin/main'`.
- `terraform plan` → `No changes`, 32 recursos refreshed.
- `terraform state list | wc -l` → **32**.
- `aws s3 cp ... | jq '.serial'` → **35**.
- `aws rds describe-db-instances ... --query 'DBInstances[0].DBInstanceStatus'` → `stopped`.

Todo cuadró exactamente con lo esperado del estado al cierre de S12-K. Arranque limpio.

Aplicación de candidata #S12I-2 al arranque: plan de bloques recordado explícitamente ANTES del warmup en el prompt del profesor del miércoles. **Aplicación acumulada 5ª limpia consecutiva** (S12-I + S12-J + S12-K + S12-L primer intento martes + S12-L definitiva miércoles). Anotable como aterrizaje sólido, candidata madura para promoción a locked ⭐⭐⭐ en S12-M.

## Bloque 1 — Warmup (no ejecutado explícitamente)

Warmup formal no ejecutado como bloque separado en esta sesión. Racional retrospectivo: el prompt de continuación S12-L planteaba 2 preguntas candidatas (A: predicción de orden de priorización de ADRs, B: predicción del comportamiento del `plan` pre-apply para `skip_final_snapshot`). En la ejecución real la Pregunta A se colapsó directamente con el Bloque 3 (priorización de ADRs), y la Pregunta B quedó descartada al no priorizar A20 para esta sesión. Anotable como **desviación pactada implícitamente por la reestructuración del scope**, no como salto de método.

Aplicación limpia de la regla de **NO forzar warmup ceremonial cuando el contenido del warmup queda absorbido por otro bloque**. Filtro `¿falla → apply catastrófico?` aplicable al Bloque 3 directamente. Anotable para futuras sesiones: cuando el warmup y otro bloque tienen contenido solapado, colapsar es correcto.

## Bloque 3 — Priorización explícita de ADRs

Ejecución en ~15-20 min. El alumno explicitó no tener idea previa de priorización (*"bloque 3, no tengo idea previa"*), señal operativa fiable — no capricho, no pereza, simplemente ausencia de contexto suficiente para proponer sin la información completa. Profesor presentó los 8 candidatos ADR abiertos en tabla estructurada con coste + riesgo por cada uno.

### Presentación estructurada de los 8 candidatos

| # | Qué es | Coste refactor | Riesgo |
|---|---|---|---|
| A13 | Route Table pública asociada al VPC Endpoint sin valor operativo | Bajo | Bajo |
| A14 | Inline policy `AWSRevokeOlderSessions` fuera del scope Terraform por diseño | Nulo (solo documentar) | Nulo |
| A15 | Bucket S3 uploads sin versioning | Bajo | Bajo |
| A16 | Key pair `task-manager-key` referenciada como string literal, no importada | Medio | Bajo |
| A17 | Root volume EBS de EC2 sin cifrado (destroy + create replacement) | **Alto** | **Alto** |
| A18 | RDS storage type `gp2`. Migración in-place a `gp3` | Bajo-medio | Bajo |
| A19 | Password de RDS gestionado manualmente + Bitwarden, fuera del HCL | Nulo (solo documentar) | Nulo |
| A20 | RDS con `skip_final_snapshot = true` importado como realidad | Bajo | Bajo |

### Matices operativos explicitados antes de discutir

Dos matices articulados por el profesor antes de proponer priorización:

1. **A14 y A19 no requieren cambio de infraestructura** — decisiones ya tomadas que solo necesitan documentarse en ADR formal. Sin `terraform apply` asociado. "Gratis" en términos de riesgo operativo. Ventaja pedagógica: aterrizan el formato Nygard sin la tensión del apply.

2. **A17 fuera del scope de hoy sin negociación** — mantenido firme (había sido pactado el día anterior). `Destroy + create replacement` de la EC2 es catastrófico si sale mal, requiere procedimiento propio pactado en frío en sesión dedicada. NO tocamos hoy.

### Recomendación del profesor y decisión pactada

Recomendación honesta explicitada por el profesor para ~2h 30min con estado emocional bajo:

- **Objetivo mínimo viable**: 1 apply real + 2 ADRs documentales.
- **Candidato para primer apply**: A15 (S3 versioning) preferido por: (a) cambio simple, alto valor compliance banca (GDPR/PCI DSS), (b) bajo riesgo (activar versioning no destruye datos ni cambia comportamiento visible), (c) primer patrón "crear infra desde HCL" del roadmap (hasta ahora todo import).
- **Alternativas evaluadas**: A20 (requiere RDS arrancada, +15 min AWS solo para start/stop), A13 (limpieza operativa, primer patrón `destroy` — peor señal emocional para primer apply), A18 (RDS también, tercer patrón `change` — no primero).
- **Documentales**: A14 + A19 para dejar la carpeta `decisions/` inicializada con estructura y 2 ADRs de calentamiento.

Alumno aceptó la propuesta sin renegociar. Anotable como caso positivo de aplicación de recomendación por parte del profesor cuando el alumno explicita ausencia de contexto — el profesor tiene información sistémica (coste + riesgo + valor pedagógico + coherencia con estado emocional) que el alumno no tiene consolidada. Delegar en el profesor en este caso es correcto y no viola el método socrático (el racional se articula explícitamente antes de proponer, y el alumno tiene veto sobre la propuesta).

## Bloque 4 — Redacción de 4 ADRs formales

Bloque más denso pedagógicamente de la sesión — introducción del formato Michael Nygard como vocabulario técnico nuevo, aplicado 4 veces consecutivas.

### Creación de la carpeta `decisions/`

Alumno ejecutó `mkdir infra/decisions` autónomamente antes de la propuesta del profesor. Anotable como **decisión de bajo valor pedagógico correctamente delegada al alumno sin ceremonia**. Racional del profesor: "mkdir es trivial y no aporta valor pedagógico — quiero preservar el tiempo socrático para la redacción de los ADRs, que sí lo tiene". Aplicación limpia del principio "distinguir dónde va el método socrático y dónde no".

### Introducción del formato Michael Nygard

Vocabulario técnico nuevo introducido explícitamente por el profesor antes de aplicarlo (aplicación limpia de la regla S12-D reforzada en S12-K):

- **Title**: `ADR-NNN: <decisión resumida>`.
- **Status**: `Proposed | Accepted | Deprecated | Superseded`. Para esta sesión siempre `Accepted` porque documentamos decisiones ya tomadas empíricamente.
- **Context**: qué situación forzó la decisión. Hechos, no opiniones. Un párrafo o dos.
- **Decision**: qué se decidió, en presente activo.
- **Consequences**: qué implica — positivas, negativas, neutras.

Orden pactado de los 4 ADRs: A14 (calentamiento documental) → A19 (refuerzo del formato) → A15 (ADR + refactor HCL + primer apply) → A13 (ADR + refactor HCL + segundo apply, en tiempo extra pactado). Racional del profesor: los documentales al inicio aterrizan el formato antes de que el apply añada tensión operativa.

### ADR-014 — Exclude AWSRevokeOlderSessions inline policy from Terraform scope

Redacción en modo socrático estricto: 3 preguntas separadas (Context, Decision, Consequences) con verificación en cada una antes de pasar a la siguiente.

**Hallazgos operativos durante la redacción**:

- **Context**: alumno redactó 4 frases articulando situación empírica + causa (auto-generación por AWS tras click "Revoke sessions"). Profesor planteó matiz opinable — si el hecho empírico del click humano estaba verificado o era asunción. Alumno confirmó verificación empírica: *"Recuerdo que pulsé el botón"*. Anotable como aplicación limpia de la regla "cuando no sé algo, lo digo — no invento". Racional confirmado, redacción (a) mantenida.

- **Decision**: alumno redactó 2 frases con presente activo ("We exclude", "Terraform intentionally leaves"). Profesor planteó matiz opinable — la segunda frase rozaba Consequences. Alumno eligió (a) dejarla por refuerzo de intencionalidad. Aplicación de veto del alumno sobre preferencia estilística del profesor.

- **Consequences**: alumno redactó 4 frases cubriendo positivas + negativa + neutra. Cerró la "trampa autorreferencial del ADR" (documenta la decisión requiere que el ADR quede visible). Aplicación limpia.

**Normalizaciones aplicadas al fichero final** (patrón que se repite en los 4 ADRs): guiones no-break Unicode (U+2011) → ASCII (`-`), comillas tipográficas → ASCII (`"`), apóstrofes tipográficos → ASCII (`'`). Salieron del auto-formato del editor del alumno. Detectadas por el profesor en verificación línea por línea.

**Fichero final**: `decisions/ADR-014-exclude-aws-revoke-older-sessions-from-terraform-scope.md` (1406 bytes). Nombre de fichero más largo que la propuesta del profesor — descriptivamente más preciso, mantenido por el alumno. Anotable como aplicación de veto sobre propuesta del profesor por criterio propio.

### ADR-019 — Omit RDS master password from Terraform scope

Segunda iteración del patrón Nygard con mejora de disciplina: sin saltos de método, sin matices grandes.

**Hallazgos operativos**:

- **Context**: alumno articuló los 3 caminos evaluados en S12-K con matiz opinable sobre precisión técnica ("Terraform does not retrieve" vs "AWS API intentionally does not return"). Elegido (a) por brevedad y suficiencia para lector futuro.

- **Decision**: alumno nombró el recurso Terraform específico (`aws_db_instance.task_manager_db`), coherente con línea (a) elegida en A14. Introducción del vocabulario "authoritative source of truth" para el rol de Bitwarden — vocabulario correcto de arquitectura de datos.

- **Consequences**: cobertura equilibrada de superficies de exposición eliminadas (HCL + state S3) + desacoplamiento del ciclo de rotación + riesgo crítico de Bitwarden con recovery path articulado (AWS-level master password reset). Anotable: articulación del riesgo en nivel adecuado, ni catastrófico ni minimizado.

**Fichero final**: `decisions/ADR-019-omit-rds-master-password-from-terraform-scope.md` (1946 bytes).

### ADR-015 — Enable versioning on toleflaco-task-manager-uploads-2026 S3 bucket

Tercer ADR con introducción de matices técnicos adicionales por el profesor antes de arrancar (por ser el ADR asociado al primer apply del roadmap).

**Matices operativos introducidos antes de la redacción**:

1. Coste de S3 versioning: cada versión ocupa espacio facturable. Marginal en uso actual, potencial ADR futuro (lifecycle policy).
2. **Reversibilidad**: activar es simple. **Desactivar no** — S3 solo permite `Enabled → Suspended`, nunca `Disabled`. Decisión con implicación permanente. Vocabulario nuevo aterrizado en el propio ADR ("practically irreversible").

**Hallazgos operativos**:

- **Context**: alumno mencionó LOPD + GDPR + PCI DSS. Profesor articuló matiz técnico opinable — LOPD (Ley Orgánica de Protección de Datos española) está derogada por LOPDGDD (2018) tras aplicación del RGPD europeo. En ADR internacional en inglés, "GDPR" cubre el terreno con precisión sin necesidad de referencia jurídica española obsoleta. Alumno eligió (b) omitir LOPD, dejando "GDPR, PCI DSS, or similar controls". Aplicación limpia de la regla operativa "precisión jurídica > costumbre idiomática".

- **Decision**: alumno articuló mecanismo Terraform + coherencia con el "split-resource pattern" ya usado en `_server_side_encryption_configuration` y `_public_access_block`. Anotable: aterrizaje empírico del **patrón arquitectónico intra-bucket** — un revisor senior banca reconoce el patrón en un solo golpe de vista.

- **Consequences**: cobertura de 3 positivas (compliance + recuperación + coherencia arquitectónica) + 2 negativas (coste + irreversibilidad práctica) + 1 neutra (impacto cero en cliente). Articulación balanceada. "Practically irreversible" incorporado con precisión.

**Fichero final**: `decisions/ADR-015-enable-versioning-on-s3-uploads-bucket.md` (1991 bytes).

### ADR-013 — Remove public route table association from S3 VPC Endpoint

Cuarto ADR redactado en tiempo extra pactado en caliente, tras recalibración horaria del profesor. Método socrático mantenido con máxima disciplina a pesar de restricción temporal (~50 min para ADR + refactor HCL + apply + commit + push).

**Verificación empírica pre-redacción**: profesor pidió `terraform state show aws_vpc_endpoint.s3` ANTES de redactar el ADR, para verificar empíricamente si la asociación problemática era elemento de la lista `route_table_ids` del recurso o recurso separado (`aws_vpc_endpoint_route_table_association`). Aplicación limpia de la regla ⭐⭐⭐ #S12H-5 (`describe-*` sin filtro antes de HCL) en su variante schema — no adelantar el ADR sin saber empíricamente qué toca modificar.

**Hallazgo colateral no anticipado durante el state show**: `policy` del VPC Endpoint es totalmente permisiva (`Effect = "Allow"`, `Action = "*"`, `Principal = "*"`, `Resource = "*"`). Es la policy default AWS. **Deuda técnica potencial candidata a futuro ADR** (no A13 — otro ADR aparte, no lo tocamos hoy). Anotable para próxima sesión.

**Hallazgos operativos de la redacción**:

- **Context**: alumno articuló empíricamente las 3 route tables asociadas + propósito operativo del Gateway Endpoint + racional de por qué la asociación pública es "operationally redundant". Profesor propuso matiz opinable — "redundant" es suave, "operationally meaningless" más preciso. Alumno eligió (b) por precisión técnica.

- **Decision**: articulación del mecanismo Terraform exacto (`aws_route_table.public.id` fuera de la lista `route_table_ids`) + estado final consolidado. Sin matices.

- **Consequences**: cobertura equilibrada de 3 positivas + 1 negativa con hedging apropiado ("would need to be restored, though this scenario is unlikely") + 1 neutra ("Runtime behavior... remains unchanged"). Reformulaciones del alumno mejorando pistas del profesor en 2 frases (positiva 1 y 3).

**Fichero final**: `decisions/ADR-013-remove-public-route-table-from-s3-vpc-endpoint.md` (1873 bytes).

### Aterrizaje operativo del Bloque 4

**4 aplicaciones consecutivas del formato Michael Nygard** con creciente autonomía del alumno. En A14 aparecieron 2 saltos menores de método (guiones tipográficos + un matiz de Decision rozando Consequences). En A19 y A15 los saltos se redujeron a normalizaciones tipográficas mecánicas. En A13 la disciplina fue máxima — cero saltos de método, 3 reformulaciones del alumno mejorando pistas del profesor.

**Regla candidata #S12L-1** (aterrizaje al 4º intento): **cuando el alumno redacta un artefacto siguiendo un formato nuevo, la 4ª aplicación consecutiva es donde el formato aterriza sin fricción**. Consistente con el patrón "3 intentos para aterrizar" observado en S12-K con el mapping Cat 1/2/3/4 (aterrizado al 3er intento) y con la matización S12-J de #S12H-8 (aterrizada al 3er intento). Falta 1-2 aplicaciones más para promoción a locked.

## Bloque 5 — Refactor HCL de A15

Ejecución en ~5-10 min. Bloque corto por simplicidad del cambio (añadir un solo recurso).

### Salto de método detectado — alumno se adelantó a escribir HCL

Antes de que el profesor planteara el análisis Cat 1/2/3/4 del schema, alumno escribió el HCL completo por su cuenta:

```hcl
resource "aws_s3_bucket_versioning" "task_manager_uploads" {
  bucket = aws_s3_bucket.task_manager_uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

Explicitó: *"Vaya me adelanté mirando el Argument Reference"*. Anotable como **6º salto de método consecutivo del alumno del mismo patrón** (S12-K Grupo 1 EC2 + S12-K adelantarse a `validate` + adelantarse a plan post-import + hoy adelantarse a escribir HCL). Patrón consolidado: **"optimizar velocidad vs disciplina paso a paso"**.

Corrección aplicada por el profesor sin softening: análisis del HCL "al revés" — clasificar lo escrito aplicando el mapping Cat 1/2/3/4 y contrastar con Argument Reference. Racional del profesor: *"más útil didácticamente que reescribirlo"*. Aplicación limpia del principio "trabajar con la realidad, no defender el método por consistencia".

### Verificación línea por línea del HCL

Análisis contra la regla ⭐⭐⭐ #S12H-8 con matización S12-K:

- **`bucket = aws_s3_bucket.task_manager_uploads.id`** — INCORRECTO según #S12H-8. Schema de `aws_s3_bucket`: `id = bucket_name` = alias legible → atributo semántico `.bucket` es lo correcto. Profesor planteó verificación empírica: **releer los otros 2 recursos S3 del proyecto** (`_server_side_encryption_configuration`, `_public_access_block`) y verificar qué usan.

- **Verificación empírica del alumno**: *"ponen .bucket, ya lo he cambiado"*. Aplicación **9ª acumulada de #S12H-8** con matización S12-K aplicada correctamente. Anotable: la verificación empírica ganó a la intuición mecánica ("`.id` funciona técnicamente") — consolidación del patrón "atributo semánticamente correcto" en el alumno.

### Duda del alumno sobre "alias legible vs identificador propio opaco"

Alumno explicitó: *"no entiendo cuando dices alias legible o identificador propio opaco, no entiendo la diferencia"*. Duda legítima y bien planteada. Vocabulario introducido en S12-J y consolidado en S12-K, pero visto una sola vez desde entonces — natural que no esté aterrizado.

Aplicación limpia de la regla derivada personal del profesor consolidada en S12-K: **cuando emerja vocabulario técnico nuevo por mi lado en caliente, introducirlo explícitamente antes de usarlo**. Anotable: la duda del alumno fue el disparo de una explicación profunda con 3 casos empíricos + regla derivada + matización S12-K. Anotable como aplicación pedagógica: **una duda del alumno bien planteada = oportunidad didáctica de oro** (categoría ya identificada en sesiones anteriores).

### Análisis del schema de `aws_s3_bucket_versioning` — buen catch del alumno sobre `mfa_delete`

Alumno detectó `mfa_delete` en Argument Reference y articuló: *"pone mfa_delete - (Optional) Whether MFA delete is enabled in the bucket versioning configuration. Valid values: Enabled or Disabled. Pero tiene que estar MFA enabled"*. Aplicación limpia de la disciplina "consultar Argument Reference antes de decidir declarar/omitir".

Profesor decidió omisión con racional articulado: (a) workflow del proyecto es Terraform + IAM roles no cuenta raíz, (b) activar MFA delete complica destroy futuro, (c) no es requisito compliance en el nivel actual. Clasificación pactada: Cat 3 (sin línea "Defaults to") → schema absorbe realidad `Disabled` sin drift. **Predicción posteriormente refutada empíricamente** por el plan pre-apply (analizado en Bloque 6).

**HCL final pactado**:

```hcl
resource "aws_s3_bucket_versioning" "task_manager_uploads" {
  bucket = aws_s3_bucket.task_manager_uploads.bucket
  versioning_configuration {
    status = "Enabled"
  }
}
```

## Bloque 6 — Ciclo pactado del apply de A15 (primer `terraform apply` del roadmap)

Ejecución en ~20 min. **Milestone del módulo AWS brownfield**. Densidad emocional alta anticipada — atenuada empíricamente por disciplina de método intacta.

### Paso 1 — `terraform validate`

Ejecutado por el alumno tras verificación conjunta del HCL. Output: `Success! The configuration is valid.` ✓ Sin fricción.

### Paso 2 — Predicción escrita del plan

Alumno articuló predicción en 3 niveles:

- **Nivel 1**: `Plan: 1 to add, 0 to change, 0 to destroy` (create).
- **Nivel 2**: aparece "el s3_bucket, y propone el nuevo cambio en versioning con los atributos que hemos puesto en el HCL".
- **Nivel 3**: "esos atributos no los resuelve porque no están activados en AWS".

**Análisis crítico del profesor**:

- **Nivel 1** ✓ correcto.
- **Nivel 2** — imprecisión: el recurso base `aws_s3_bucket` YA está gestionado y no aparece en el plan como cambio, solo el nuevo `aws_s3_bucket_versioning`. Corrección articulada.
- **Nivel 3** — imprecisión conceptual importante: la distinción `resuelto durante plan` vs `(known after apply)` **no depende de "estar activado en AWS"**. Depende de: (a) valor literal en HCL → resuelto en plan, (b) atributo NO declarado y Computed → `(known after apply)`, (c) referencia a otro recurso ya existente → resuelto en plan.

Aterrizaje pedagógico del profesor: distinción **Computed / literal / referencia** aplicable al futuro trabajo IaC. Alumno confirmó comprensión: *"si clara"*. **Sin re-verificación de la comprensión** — anotable como posible salto de método del profesor (debería haber pedido re-articulación en 1 frase). Verificable en próximo apply si el alumno mantiene la distinción.

### Paso 3 — `terraform plan` ejecutado, verificación línea por línea

Plan output confirmó:

- **Nivel 1**: `Plan: 1 to add, 0 to change, 0 to destroy` ✓
- **Nivel 2**: solo `aws_s3_bucket_versioning.task_manager_uploads` como `+ create` ✓
- **Nivel 3**: `bucket = "toleflaco-task-manager-uploads-2026"` (referencia resuelta) ✓, `status = "Enabled"` (literal) ✓, `id = (known after apply)` ✓

**2 hallazgos empíricos NO anticipados en la predicción**:

**Hallazgo 1 — `region = "eu-west-1"`**: Terraform resolvió `region` en el plan (no `(known after apply)`), tomándolo del provider AWS declarado en `versions.tf`. Atributo no visto en Argument Reference al leerla — **patrón nuevo en AWS Provider v6+** (muchos recursos ganaron `region` como atributo explícito, útil para multi-region setups). Como no declarado y provider tiene default, absorbe sin drift. Sin acción.

**Hallazgo 2 — `mfa_delete = (known after apply)`**: refutación empírica de la clasificación Cat 3. Argument Reference decía `(Optional)` sin línea "Defaults to" → esperaba absorber como Cat 3. Plan muestra `(known after apply)` → es **Computed**. Aplicación **3ª empírica de la regla candidata #S12K-2** (Argument Reference vs plan real, cuando divergen gana el plan). **Con esta 3ª aplicación la regla queda madura para promoción a locked ⭐⭐⭐ en S12-M**. Patrón consistente en 3 sesiones distintas (S12-K con `instance_metadata_tags` + S12-K con defaults RDS + hoy con `mfa_delete`).

Aterrizaje operativo: nuestro racional para omitir `mfa_delete` sigue siendo correcto en resultado (no queremos activar MFA Delete), pero el mecanismo empírico es distinto al esperado. No causa drift ni requiere acción. Anotable para transferencia a entrevistas: **"Argument Reference documenta la intención del provider, no el schema real 100% — el plan pre-apply es la fuente de verdad"**.

### Paso 4 — Triple confirmación conjunta pre-apply

**1ª aplicación de la extensión de #31 al `terraform apply`** en la historia del roadmap. Formato explícito:

```
Tole confirma: SÍ plan de apply revisado y correcto según terraform plan
Claude confirma: SÍ — plan verificado línea por línea contra predicción. 1 recurso a crear (aws_s3_bucket_versioning.task_manager_uploads). Sin cambios en recursos existentes. Sin destroys. Sin drift oculto. 2 hallazgos empíricos benignos (region auto-resuelto por provider, mfa_delete Computed) sin impacto operativo. Configuración coherente con ADR-015 redactado.
Claude autoriza apply: SÍ — sin objeciones técnicas ni de método.
```

Anotable como **precedente operativo del ciclo protector** para todo el trabajo IaC banca futuro. La ceremonia añade ~30 segundos y protege de errores irreversibles.

### Paso 5 — `terraform apply` interactivo

Ejecutado sin `-auto-approve`. Terraform re-ejecutó el plan y presentó confirmación interactiva. Alumno escribió `yes`. Output:

```
aws_s3_bucket_versioning.task_manager_uploads: Creating...
aws_s3_bucket_versioning.task_manager_uploads: Creation complete after 2s [id=toleflaco-task-manager-uploads-2026]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Duración empírica: **2 segundos**. Anotable como referencia para futuras operaciones de `create` sobre atributos de configuración de bucket S3 — rápido, sin propagación asíncrona percibida por el usuario.

### Paso 6 — Verificación post-apply en 3 dimensiones

**Dimensión 1** — Terraform state: `terraform plan = No changes` ✓ (con predicción escrita por el alumno ANTES: `Predicción: No changes`, ⭐⭐⭐ #24 aplicada).

**Dimensión 2** — State file en S3: `serial = 36` ✓ (era 35 antes del apply, incremento correcto de +1).

**Dimensión 3** — Realidad AWS (consola): `Bucket Versioning: Enabled` + `MFA delete: Disabled` ✓. **Confirmación empírica adicional de la refutación de Cat 3 para `mfa_delete`** — la realidad AWS coincidió con lo esperado, pero el mecanismo empírico del schema fue distinto.

Coherencia total entre las 3 dimensiones. Sin drift entre HCL, state, y realidad AWS. **Milestone del módulo AWS brownfield cerrado empíricamente**.

## Bloque 10 — Commit + push (2 commits separados por concern)

Estrategia elegida: **2 commits separados** (documentación + infra) coherente con revisión de PR banca. Racional articulado por el profesor y aceptado por el alumno.

### Commit 1 — `docs(adr): add ADR-014, ADR-015 and ADR-019`

**Ficheros staged**: 3 ADRs. `s3.tf` explícitamente excluido del staging area (`git add decisions/` selectivo, aplicación limpia de la regla `NO git add .`).

**Verificación pre-commit**: `git diff --staged` con verificación conjunta línea por línea. 3 ficheros nuevos, contenido íntegro, todas las normalizaciones aplicadas (guiones ASCII, comillas ASCII, apóstrofes ASCII, cabeceras Markdown correctas). Detalle observado: los paths mostraron `infra/decisions/...` en lugar de `decisions/...` — normal (diff se muestra desde raíz del repo).

**Mensaje bilingüe**:

```
docs(adr): add ADR-014, ADR-015 and ADR-019

Add three new architecture decision records under decisions/:
- ADR-014 documents the exclusion of the AWSRevokeOlderSessions inline policy from Terraform scope (S12-H).
- ADR-015 enables versioning on the toleflaco-task-manager-uploads-2026 S3 bucket for GDPR/PCI DSS compliance (S12-I).
- ADR-019 omits the RDS master password from Terraform and formalizes manual management via AWS console and Bitwarden (S12-K).

---
Agregar ADR-014, ADR-015 y ADR-019

Agregar tres nuevos architecture decision records en decisions/:
- ADR-014 documenta la exclusion de la policy AWSRevokeOlderSessions del scope de Terraform (S12-H).
- ADR-015 activa versioning en el bucket S3 toleflaco-task-manager-uploads-2026 para cumplimiento GDPR/PCI DSS (S12-I).
- ADR-019 omite el password maestro de RDS en Terraform y formaliza la gestion manual via consola AWS y Bitwarden (S12-K).
```

Ejecutado con heredoc (`git commit -F- <<'EOF'`). Commit hash: `3a696c5`. 3 ficheros, 51 líneas insertadas.

**Verificación pre-push**: `git log -1 --format=full` — cuerpo bilingüe intacto, estructura EN + `---` + ES preservada, sin acentos ni ñ. Aterrizaje S12-H mantenido — **4ª sesión consecutiva sin amend**.

**Triple confirmación conjunta pre-push**: 9ª aplicación consecutiva de ⭐⭐⭐ #31. Formato explícito, ambas partes SÍ, autorización SÍ.

Push exitoso: `013102d..3a696c5 main -> main`.

### Commit 2 — `feat(infra): enable versioning on S3 uploads bucket per ADR-015`

**Ficheros staged**: `s3.tf` modificado (bloque `aws_s3_bucket_versioning` añadido). `.terraform.lock.hcl` no tocado por el apply — verificado.

**Verificación pre-commit**: `git diff --staged` mostrando cambio quirúrgico (solo un bloque añadido al final del fichero, después de `aws_s3_bucket_public_access_block`, con línea en blanco separadora coherente con estilo del fichero). Ningún otro cambio.

**Mensaje bilingüe** con referencia cruzada al ADR-015 + traza operativa del apply (`serial 35 → 36`):

```
feat(infra): enable versioning on S3 uploads bucket per ADR-015

Add a new aws_s3_bucket_versioning resource with status "Enabled" for the toleflaco-task-manager-uploads-2026 bucket, aligning the configuration with ADR-015. Applied via terraform apply, updating the remote state from serial 35 to 36. The bucket now has versioning managed fully under Terraform scope.

---
Activar versioning en el bucket S3 de uploads segun ADR-015

Agregar un nuevo recurso aws_s3_bucket_versioning con status "Enabled" para el bucket toleflaco-task-manager-uploads-2026, alineando la configuracion con ADR-015. Aplicado via terraform apply, actualizando el remote state de serial 35 a 36. El bucket tiene ahora versioning gestionado completamente bajo el scope de Terraform.
```

**Matiz opinable estilístico**: alumno redactó inicialmente el subject line ES con prefijo `feat(infra):` incluido, coherente sintácticamente pero incoherente con el patrón de las 4 sesiones anteriores (subject ES sin prefijo Conventional Commits). Profesor articuló el matiz. Alumno eligió (b) por coherencia histórica, quitando el prefijo. Aplicación limpia de la regla "coherencia con precedentes del proyecto > preferencia estilística in-caliente".

Commit hash: `c7d3ea1`. 1 fichero cambiado, 7 líneas insertadas.

**Verificación pre-push**: `git log -1 --format=full` — cuerpo bilingüe intacto. Traza del apply preservada. **5ª sesión consecutiva del aterrizaje S12-H sin amend**.

**Triple confirmación conjunta pre-push**: 10ª aplicación consecutiva de ⭐⭐⭐ #31.

Push exitoso: `3a696c5..c7d3ea1 main -> main`.

## Recalibración horaria del profesor (~08:10) y pacto de A13 en tiempo extra

Momento operativo importante de la sesión. Tras el push del Commit 2, profesor emitió resumen de cierre con estimación horaria incorrecta ("~1h 40min efectivos"). Alumno detectó la desviación: *"son las 8:10, vamos a seguir un poco más"*. Profesor recalibró: 2h 10min efectivos, no 1h 40min.

**Aplicación 1ª de ⭐⭐⭐ #S12E-1 al profesor en la sesión** — error empírico de cálculo, detectado por el alumno. Anotable como caso positivo de la asimetría de conocimiento: el alumno tiene el reloj externo real, el profesor tiene la percepción de la conversación pero no la referencia horaria fiable. **Regla derivada personal del profesor**: cuando se emita estimación de tiempo transcurrido, verificar contra reloj externo del alumno si es posible, o marcarla como "aproximado" explícitamente.

Alumno explicitó disponibilidad extendida: *"puedo estar hasta las 9"*. Recalibración: ~50 min efectivos disponibles, no 20 min como estimé inicialmente.

Análisis de candidatos ADR abiertos que cabían en 50 min honestos:
- A13 (RT VPC Endpoint): 1 recurso a modificar, ciclo completo estimado 30-40 min. **Cabe**. Patrón `change in-place` nuevo (no `create` como A15).
- A18: requiere RDS arrancada, +15 min AWS. NO cabe cómodamente.
- A20: mismo problema, requiere RDS arrancada. NO cabe.
- A16: recurso nuevo con `terraform import`, denso. NO cabe cómodamente.

Chequeo honesto explicitado por el profesor antes de proponer A13: densidad emocional del primer apply ya consumida, segundo apply en la misma sesión mete tensión operativa, milestone ya hecho y consolidado. **3 opciones presentadas con racional articulado**: (a) atacar A13 completo, (b) redactar ADR-013 sin apply, (c) cierre limpio ahora. Alumno eligió (a). Pacto: corte firme a las 09:00 si no cerrado.

Anotable como caso positivo de aplicación de la regla operativa "presentar opciones con racional articulado, dejar decisión al alumno sin defender preferencia del profesor".

## Bloque 4bis, 5bis y 6bis — ADR-013 + refactor HCL + segundo apply del roadmap

### Redacción de ADR-013 (analizada arriba en el Bloque 4)

### Refactor HCL — eliminación de `aws_route_table.public.id` de `route_table_ids` en `main.tf`

Ejecutado por el alumno tras verificación conjunta del ADR. Estado del bloque post-edición confirmado con `grep -A 15 "aws_vpc_endpoint" main.tf`:

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.private_1a.id,
    aws_route_table.private_1b.id
  ]
  tags = {
    Name = "task-manager-vpce-s3"
  }
}
```

Cambio quirúrgico. Sin salto de método por adelantamiento (contraste con Bloque 5 del apply A15).

### Ciclo pactado del apply de A13

**`terraform validate`** → `Success!` ✓

**Predicción escrita del plan** — alumno articuló inicialmente: `Plan: 0 to add, 0 to change, 1 to destroy`. **INCORRECTO**.

**Aplicación de STOP del profesor**: la lista `route_table_ids` es un atributo del recurso `aws_vpc_endpoint.s3` que persiste — no se destruye el recurso, se modifica un atributo. Correcto categorizarlo como `change`, no `destroy`.

**Corrección del alumno**: `Plan: 0 to add, 1 to change, 0 to destroy`. ✓

**Aterrizaje conceptual explicitado por el profesor** — distinción categórica en Terraform:
- `add` → recurso nuevo (`+ create`).
- `change` → recurso persiste, atributos modificados in-place (`~ update`).
- `destroy` → recurso eliminado (`- destroy`).
- `add + destroy` → destroy + create replacement (`-/+ destroy and then create replacement`) por cambio en atributo Cat 4.

Anotable como **aterrizaje empírico de la clasificación de acciones Terraform**. El alumno había visto ejemplos de `create` (S12-A hasta hoy con A15) pero no había ejecutado nunca un `change` in-place. La confusión inicial es natural — el atributo cambió, no el recurso.

**`terraform plan` ejecutado**: `~ update in-place` sobre `aws_vpc_endpoint.s3`. Único cambio: `- "rtb-07f9363299f58b0b3"` de la lista `route_table_ids`. 2 elementos preservados (RTs privadas). 21 atributos sin cambio + 1 bloque sin cambio. Sin destroys, sin replacements, sin drift oculto.

**Triple confirmación conjunta pre-apply** — 2ª aplicación de la extensión de #31 al `apply` en la misma sesión.

**`terraform apply` interactivo** con `yes`. Output: `Modifications complete after 6s`. **`Apply complete! Resources: 0 added, 1 changed, 0 destroyed.`** ✓

Duración empírica del `change` in-place: **6 segundos**. Mayor que el `create` del versioning (2s) por la naturaleza de la operación en AWS API (disassociate operation requiere validación de rutas activas).

**Verificación post-apply**:
- Dimensión 1: `plan = No changes` ✓ (predicción escrita antes: `Predicción: No changes`).
- Dimensión 2: `serial = 37` ✓ (era 36, incremento +1).
- Dimensión 3: no ejecutada por tiempo (consola AWS opcional, saltable por presión temporal). Anotable como recorte operativo aceptable.

### Commit + push del A13 (Commit 3 de la sesión)

Estrategia elegida: **commit único agrupado** (ADR-013 + HCL). Racional articulado por el profesor: hay solo 1 ADR + 1 fichero HCL modificado, la separación no aporta valor. Diferente de A15 (donde separamos por concern por haber 3 ADRs + 1 HCL). Aplicación limpia del principio "separar cuando aporta, agrupar cuando no".

**Mensaje bilingüe**:

```
feat(infra): remove public route table association from S3 VPC endpoint per ADR-013

Remove the public route table from the route_table_ids of the aws_vpc_endpoint.s3 resource, leaving only private_1a and private_1b as associations. Applied via terraform apply, updating the remote state from serial 36 to 37. The endpoint now scopes exclusively to private subnets as defined in ADR-013.

---
Eliminar asociacion de la route table publica del VPC endpoint S3 segun ADR-013

Eliminar la route table publica de route_table_ids en el recurso aws_vpc_endpoint.s3, dejando solo private_1a y private_1b como asociaciones. Aplicado via terraform apply, actualizando el remote state de serial 36 a 37. El endpoint queda ahora limitado exclusivamente a las subnets privadas segun ADR-013.
```

**Matiz opinable estilístico**: alumno redactó inicialmente el subject line ES con "remover" (calco del inglés "remove"). Profesor articuló matiz — "Eliminar" es verbo español más natural. Alumno eligió (a) "Eliminar". Aplicación limpia de la regla "coherencia idiomática + naturalidad del verbo".

Commit hash: `7f6637a`. 2 ficheros modificados, 17 insertions + 1 deletion.

**Verificación pre-push**: `git log -1 --format=full` — cuerpo bilingüe intacto. **6ª sesión consecutiva del aterrizaje S12-H sin amend** (contabilizando las 3 aplicaciones limpias de hoy).

**Triple confirmación conjunta pre-push**: 11ª aplicación consecutiva de ⭐⭐⭐ #31.

Push exitoso: `c7d3ea1..7f6637a main -> main`.

## Cierre de sesión

**Chequeo de tiempo final**: 06:00 → 08:47 = **2h 47min efectivos**. Techo pactado: 2h 30min. **Desviación +17min** por A13 pactada en caliente. Anotable dentro de rango aceptable, sin señal de sobrecarga en el cierre.

**Estado del working tree**: limpio, sin ficheros pendientes de commit. Bitácora S12-L pactada en frío al día siguiente.

## Métricas de la sesión

### Logro operativo

- **4 ADRs formales** creados en `decisions/`: ADR-013, ADR-014, ADR-015, ADR-019 (1873 + 1406 + 1991 + 1946 = 7216 bytes total).
- **2 `terraform apply` reales** ejecutados con protocolo completo.
- **State serial**: 35 → 36 → 37. Dos incrementos verificados empíricamente.
- **3 commits limpios** pusheados a `origin/main`: `3a696c5`, `c7d3ea1`, `7f6637a`. Cero amend en la sesión.
- **Total 33 recursos gestionados** en Terraform state (+1 por versioning).
- **ADRs abiertos restantes**: A16, A17, A18, A20 (de 8 iniciales a 4 finales — 50% de cierre en una sesión).

### Reglas y candidatas aplicadas

- **11ª aplicación consecutiva de ⭐⭐⭐ #31** en git push.
- **1ª y 2ª aplicaciones de la extensión de #31 al `terraform apply`** en la historia del roadmap.
- **3ª aplicación empírica de la regla candidata #S12K-2** (Argument Reference vs plan real, con `mfa_delete`). **Madura para promoción a locked ⭐⭐⭐ en S12-M**.
- **5ª aplicación consecutiva de candidata #S12I-2** (recordar plan de bloques antes del warmup). Aterrizaje sólido.
- **9ª aplicación acumulada de ⭐⭐⭐ #S12H-8** con matización S12-K en la referencia `.bucket` de A15.
- **Aterrizaje empírico de la distinción `add / change / destroy`** categorías Terraform en A13.
- **Aplicación limpia del mapping Cat 1/2/3/4** en `mfa_delete` (refutado como Computed empíricamente).
- **1ª aplicación de la regla candidata #S12L-1** (formato Michael Nygard aterriza al 4º intento consecutivo).

### Errores del profesor

- **3 violaciones consecutivas de la regla derivada personal** (vocabulario técnico sin introducción explícita): "extensión de #31" (martes 15 sep), "ADR" como abreviatura (martes 15 sep), "priorización ADR preliminar tentativa" (miércoles 16 sep temprano). Total 5 violaciones consecutivas contando las 2 de S12-K ("opaco" + "Optional Force"). **Patrón consolidado que merece regla operativa fijable para próxima sesión — candidata a locked ⭐⭐⭐ del profesor**.
- **1ª aplicación de ⭐⭐⭐ #S12E-1 al profesor** por error de cálculo horario (~08:10 reportado como ~07:40, ~30 min de desviación). Detectado por el alumno.
- **Salto de método menor no re-verificado**: tras corregir la distinción Computed/literal/referencia en Nivel 3 de la predicción de A15, no pedí re-articulación en 1 frase para consolidar aterrizaje. Anotable para S12-M en próximas correcciones conceptuales.

### Errores del alumno

- **Salto de método del alumno en Bloque 5**: adelantarse a escribir HCL antes del análisis Cat 1/2/3/4 pactado. **6º salto consecutivo del mismo patrón** ("optimizar velocidad vs disciplina paso a paso"). Corregido con reencuadre didáctico "análisis al revés". Sin daño operativo.
- **Predicción inicial incorrecta del plan de A13** como `1 to destroy` en vez de `1 to change`. Autocorregido tras STOP del profesor. Aterrizaje conceptual sólido resultante.
- **Uso de `remover` (calco del inglés) en subject line ES del commit 3**. Corregido a `Eliminar` tras matiz del profesor. Aplicación limpia de la disciplina lingüística.

### Aprendizajes empíricos oro para futuras sesiones

1. **Densidad emocional del primer apply del roadmap NO degradó la disciplina de método**. Sueño corto + tema trabajo + primer apply real → ejecución limpia sin recortes de calidad. Evidencia empírica dura de que el ciclo pactado protege bajo carga externa. Transferible a narrativa entrevista banca: *"cuando el operador humano tiene el día malo, el ciclo pactado sigue funcionando"*.

2. **La 4ª aplicación consecutiva de un formato nuevo es donde aterriza sin fricción**. Consistente con Cat 1/2/3/4 (3er intento en S12-K), matización S12-J de #S12H-8 (3er intento en S12-K), y ahora formato Nygard (4º intento en S12-L). Regla candidata #S12L-1 formulada.

3. **Aplazar sesión completa a día siguiente cuando el alumno tiene ventana insuficiente + sobrecarga reconocida es preferible a forzar recorte**. Primer aplazamiento pactado del roadmap. Precedente operativo transferible.

4. **La regla candidata #S12K-2 (Argument Reference vs plan real) queda madura para locked ⭐⭐⭐** con 3 aplicaciones empíricas distintas en 2 sesiones. Formulación consolidada: *"la Argument Reference documenta la intención declarada del provider, no el schema real 100%. El plan expone el schema real. Cuando divergen, gana el plan"*.

5. **Deuda técnica emergente durante `terraform state show` de A13**: policy default totalmente permisiva del VPC Endpoint S3 (`Action = "*"`, `Principal = "*"`, `Resource = "*"`). **Candidato futuro ADR** — anotable para próxima sesión. NO tocado hoy por scope.

6. **La ceremonia de triple confirmación conjunta pre-apply funciona operativamente como red de seguridad**. Añade ~30 segundos al ciclo, protege de errores irreversibles. Anotable como precedente transferible a cualquier equipo IaC banca.

7. **Introducción del vocabulario "authoritative source of truth"** en el contexto arquitectónico de Bitwarden (ADR-019). Anotable para transferencia a narrativa entrevistas banca — vocabulario correcto de arquitectura de datos.

8. **El patrón de recurso separado por atributo** (`aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block`) aterrizado empíricamente desde el otro lado — no importando, creando desde HCL. Patrón operativo del 90% del trabajo IaC real en banca.

9. **La distinción `add / change / destroy` como clasificación de acciones sobre recursos completos, NO sobre atributos individuales**. Aterrizada empíricamente en A13 tras autocorrección del alumno. Transferible a análisis de plans complejos en el futuro.

10. **El aterrizaje S12-H se mantiene** 5ª sesión consecutiva sin amend en redacción bilingüe (S12-I + S12-J + S12-K + S12-L con 3 commits limpios). Falta 1 aplicación más para consolidar como aterrizaje robusto en próximas sesiones.

### Deudas de proceso pendientes (Bloque 11 en frío)

- Actualizar checklist de imports/apply en el repo (si existe).
- Redactar bitácora S12-L en frío (este documento es borrador funcional del profesor, requiere revisión y adaptación por el alumno antes de commitear — mismo racional que S12-K).
- Documentar la 3ª aplicación de #S12K-2 en el catálogo de reglas si aplica (madura para locked ⭐⭐⭐).
- Anotar candidato ADR futuro sobre policy permisiva del VPC Endpoint S3.

### Cosas anotables como positivas sobresalientes

1. **Milestone del módulo AWS brownfield cerrado empíricamente**. Primer y segundo `terraform apply` del roadmap ejecutados con protocolo completo, sin drift, sin sorpresas peligrosas.

2. **Bajo carga externa reconocida (sueño corto + tema trabajo)**, disciplina de método intacta. 3 commits limpios, 0 amend, 11ª aplicación consecutiva de #31 sin fricción.

3. **Autocorrección del alumno en predicción de A13** — tras STOP del profesor, alumno rearticuló correctamente sin necesidad de dictado. Aterrizaje empírico de la clasificación de acciones Terraform.

4. **Alumno eligió opción (a) atacar A13 completo en tiempo extra** con racional operativo (aprovechar el momento de disciplina aterrizada). Decisión honesta y bien calibrada — no forzada por el profesor.

5. **Regla candidata #S12L-1 formulada empíricamente**: formato Michael Nygard aterrizó al 4º intento consecutivo. Consistente con patrones anteriores (Cat 1/2/3/4 al 3º, matización S12-J al 3º). Anotable para próximas introducciones de vocabulario.

---

**Bitácora escrita por el profesor en modo "notas borrador"** a petición del alumno tras el push del Commit 3. **Este documento requiere revisión y adaptación por el alumno antes de commitear**. No es producto final — es andamiaje para acelerar el paso "en frío" sin sacrificar la reflexión personal. Aplicable el mismo racional que S12-J y S12-K.
