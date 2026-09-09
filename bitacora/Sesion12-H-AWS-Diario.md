# Sesión 12-H — Import brownfield bloque de identidad IAM para EC2 (Role + customer-managed Policy + Attachment + Instance Profile) y aterrizaje de reglas #S12H-1 (warmup ≤ 2 preguntas) + #S12H-5 (`get-*` sin filtro antes de HCL)

**Fecha:** martes 8 septiembre 2026 (ventana matutina 07:00-09:15, ~2h 15min) + miércoles 9 septiembre 2026 (ventana matutina 06:30-08:30, ~2h). Sesión partida en dos días por interrupción externa: la tarde del 8 sep se rompió una tubería en casa de Tole y la sesión no pudo reanudarse el mismo día.
**Duración total:** ~4h 15min honestas repartidas en dos ventanas. Estimación inicial del prompt de continuación: 2h. Sobrepaso x2 explicable por (a) primera vez con JSON dentro de HCL en el roadmap (heredoc + jsonencode), (b) 4 fallos de método del profesor corregidos sobre la marcha con aterrizaje de reglas nuevas, (c) descubrimiento AWS reveló más recursos de los anticipados (customer-managed Policy + inline `AWSRevokeOlderSessions` no previstos), (d) interrupción externa de 21h entre días.
**Estado:** Cierre limpio del bloque de identidad IAM con 4 imports (Role + Policy customer-managed + Attachment + Instance Profile). Total 26/26 recursos gestionados (14 red + 7 seguridad + 1 VPC Endpoint + 4 IAM). `terraform plan` global = `No changes`, serial **29**. Commit `f395d8b` pusheado a `origin/main` limpio con triple confirmación conjunta ejecutada (5ª vez consecutiva desde S12-F, pero con **dos `git commit --amend` previos por bugs en el mensaje** — la ceremonia cazó el bug, es su función). RDS: `stopped` verificado al arrancar ambos días, sin auto-arranque durante la sesión. IP casa: `88.11.202.24` sin rotación. Bloque S3 uploads + EC2 + RDS NO entraron — pactado explícitamente para S12-I por límite de tiempo. Sesión con **densidad pedagógica alta**: 5 reglas candidatas nuevas descubiertas, 2 promocionadas a locked ⭐⭐⭐, 4 fallos de método del profesor asumidos sin softening con reglas derivadas.

## Objetivo pedagógico

Cerrar el bloque de identidad para EC2 (arrastrado desde S12-G) importando los recursos IAM que gestionan la cadena de autenticación de la instancia EC2 hacia S3: Role, policy attachments, Instance Profile. Objetivos empíricos paralelos: (i) estrenar JSON dentro de HCL en dos sintaxis distintas (heredoc para `assume_role_policy` del Role, `jsonencode()` para `policy` de la customer-managed Policy) verificando empíricamente cuál es más fiel al brownfield; (ii) verificar si el schema `Optional + Computed` locked en S12-G aplica también a atributos IAM (`tags` vs `tags_all`, `assume_role_policy`, `managed_policy_arns`); (iii) validar empíricamente por primera vez la regla operativa candidata "referencias HCL con atributo semánticamente correcto según el schema del destino" en contexto donde `id = name` (Role) e `id = arn` (Policy) crean falso positivo — usar `.id` como comodín funciona pero es antipatrón.

## Bloque 0 — Verificación al arranque + Bloque 0 mini de retomo día 2

Regla nueva S12-F obligatoria: **sesión interrumpida > 6h = Bloque 0 completo, no pase directo**. Aplicada dos veces:

### Bloque 0 arranque 8 sep (hueco de 2 días desde S12-G)

- `git log --oneline -5` → HEAD en `6e40c94 docs(bitacora): add S12-G diary, update checklist, add S12-H continuation prompt`, `origin/main` sincronizado.
- `git status` → `working tree clean`.
- `terraform state list | wc -l` → **22**.
- `terraform plan` → `No changes`, 22 recursos refreshed.
- `aws s3 cp - | jq '.serial'` → **25**.
- `aws rds describe-db-instances` → `stopped`.
- IP casa `curl -s https://ifconfig.me` → `88.11.202.24`. Sin rotación.
- Hueco < 7 días: no requiere refresco de vocabulario básico.
- Margen sobre deadline RDS auto-arranque (~12-13 sep): 4-5 días. Cómodo.

### Bloque 0 mini retomo 9 sep (hueco de ~21h por rotura de tubería)

- `git status` → `iam.tf` **untracked** (matiz importante: nunca commiteado, no modified). Coherente porque `iam.tf` fue fichero nuevo creado en S12-H, no edición de `main.tf`.
- `git log --oneline -3` → HEAD sigue en `6e40c94`.
- `terraform state list | wc -l` → **23** (22 previos + Role importado el día anterior).
- Serial `.serial` → **26** (25 + 1 mutación por import Role).
- RDS `stopped`.

Todo cuadró exactamente con lo esperado del estado al cierre del día anterior. Retomo limpio.

## Bloque 1 — Warmup extendido y su reformulación en caliente (regla nueva #S12H-1)

Warmup pactado en el prompt: 5 preguntas de repaso de S12-G. Ejecutadas las 3 primeras con respuesta parcial + fallo grave en pregunta 1 (predicción `assume_role_policy` Optional+Computed que resultaría empíricamente **falsa** — es Required, no Optional). Alumno solicitó explícitamente cambio de método: **"estos warmups me cuestan un mundo y nos lleva mucho tiempo, no podemos hacerlo de otra manera para no perder tanto tiempo??"**.

Profesor reconoció error de método sin softening: **5 preguntas densas al inicio consumen 25-30 min sin producir infraestructura y llevan al alumno a frustración antes de arrancar el Bloque 2**. Reformulación en caliente adoptada:

> **Regla nueva #S12H-1 (candidata → locked al cierre):** Warmup máximo 2 preguntas, 5 min techo. Filtro estricto para cada pregunta: **"si el alumno falla esta pregunta, ¿escribe HCL corrupto en los próximos 30 minutos?"** Si la respuesta es no, la pregunta no va al warmup. Todo lo demás (trazabilidad de sesiones, criterios de promoción, formulaciones memorables) va al cierre de la sesión (bitácora) o se expone directamente en el bloque conceptual sin preguntar.

Warmup reformulado in-situ a 2 preguntas:

| # | Tema | Predicción alumno | Realidad | Resultado |
|---|------|-------------------|----------|-----------|
| A (crítica) | Referencia HCL para `role` del Instance Profile desde el Role: escribe la línea completa `<atributo> = <expresión>` sabiendo que hay que usar `.name`, no `.id` | `aws_iam_instance_profile=aws_iam_role.name` | Dos errores: (a) lado izquierdo lleva **nombre del atributo** dentro del bloque (`role`), no tipo del recurso. (b) lado derecho necesita **tres partes** (`<tipo>.<address>.<atributo>`), no dos. Correcto: `role = aws_iam_role.ec2_task_manager.name` | Fallada. Regla operativa derivada: **toda referencia HCL a otro recurso tiene tres partes obligatorias separadas por puntos**. Aterrizado con refuerzo directo. |
| B | Categoría de bug que `terraform validate` NO caza (semánticos vs sintácticos) | "errores semánticos" | Correcto en categoría. Precisión operativa añadida: `validate` valida sintaxis HCL + tipos declarados en el schema. NO valida **el significado de las referencias**. Los dos bugs históricos (S12-F comillas literales, S12-G `.id` omitido) pasaron validate limpio porque son semánticos. | Aprobado con complementos. |

Warmup real ejecutado en ~10 min vs 15-20 min planificados originalmente (con 5 preguntas habrían sido ~30 min). Mejora clara. **Regla #S12H-1 promocionable a locked ⭐⭐⭐ al cierre por aplicación única pero con impacto operativo evidente** — es más filosófica que empírica, aplica a método pedagógico global.

## Bloque 2 — Introducción conceptual IAM Role + Instance Profile + Policy Attachment (fallo de analogía a Kubernetes corregido en caliente)

Regla máximo 3 conceptos con verificación entre cada uno (S12-F) respetada. Tres conceptos:

1. **IAM Role**: identidad AWS con permisos, sin credenciales fijas, asumida temporalmente vía STS. Diferencia con IAM User (que sí tiene credenciales fijas). **Fallo de método del profesor**: introducción con analogía a Kubernetes Service Account. Alumno subió excerpt del mensaje con el bloque de la analogía y anunció **"no sé nada de Kubernetes"**. Kubernetes es literalmente el siguiente módulo del roadmap. Analogía inservible.

    Reformulación en caliente por el profesor con analogía al propio task-manager-api del alumno:

    | Tu task-manager-api (Fase 5.5) | AWS (IAM Role para EC2) |
    |---|---|
    | Cliente hace `POST /auth/login` con credenciales | EC2 hace `AssumeRole` contra STS |
    | Le devuelves un JWT con TTL corto | STS devuelve credenciales temporales (access key + secret + session token) TTL ~1h |
    | Cliente usa refresh token para renovar sin volver a loguear | AWS SDK v2 dentro del Spring Boot pide credenciales nuevas a IMDSv2 automáticamente |
    | El JWT lleva `authorities` que dicen qué puede hacer | El Role define qué puede hacer una vez asumido, vía policies attached |

    Diferencia clave: en la app tú programaste el flujo, en AWS el SDK v2 lo hace solo. Por eso el código Spring no ve un access key nunca — la instancia asume el Role al arrancar, el SDK renueva credenciales cíclicamente, el código solo llama `s3Client.putObject(...)`.

    **Regla derivada del fallo**: **cuando se necesite analogía técnica al perfil backend del alumno, verificar antes que la tecnología comparada ya está en su modelo mental. Kubernetes, Docker Swarm, service mesh, etc., son fuera de scope hoy — usar sistemas que el alumno ya conoce (su propia app Spring, JWT, OAuth2, Java servlets)**.

    Verificación empírica: `aws iam list-roles --query 'Roles[?contains(RoleName, task-manager)]'`. Output confirmó `task-manager-ec2-role` con ARN `arn:aws:iam::750392809244:role/task-manager-ec2-role`, creado 4 ago 2026 18:46:08 UTC (Fase 3 aprox).

2. **Instance Profile**: envoltorio del Role específicamente para EC2. Cardinalidad 1-a-1 con Role. En consola AWS aparecen fusionados con el mismo nombre — en Terraform/API son dos recursos separados. Trampa histórica de API vieja de EC2.

    Verificación empírica: `aws iam list-instance-profiles-for-role --role-name task-manager-ec2-role`. Output confirmó Instance Profile `task-manager-ec2-role` (mismo string que el Role), CreateDate `2026-08-04T18:46:08+00:00` **idéntico al Role al segundo** — prueba de operación atómica de la consola web al crear ambos. Bonus regalado por el `--output json`: JSON de la trust policy embebido en el output (`Principal.Service: ec2.amazonaws.com`, `Action: sts:AssumeRole`).

3. **Policy Attachment**: relación many-to-many entre Roles y Policies. Recurso Terraform separado `aws_iam_role_policy_attachment` (patrón moderno, análogo a las reglas SG modernas de S12-F). Cardinalidad de cada attachment individual: 1-a-1.

    Vocabulario nuevo introducido explícitamente ANTES de usarse (regla S12-D locked): AWS-managed policy vs customer-managed policy vs inline policy.

## Bloque 3 — Descubrimiento realidad IAM (fallo de método del profesor y sorpresa gorda)

### Fallo del profesor: 3 comandos AWS CLI ejecutados sin explicación previa

Profesor pidió al alumno ejecutar 3 comandos AWS CLI consecutivos (`get-role-policy`, `get-policy`, `get-policy-version`) sin explicar qué hace cada uno. Alumno pegó los outputs con la observación: **"no sé exactamente lo que haces con esos tres comandos"**. Viola regla S12-D locked ("todo concepto se explica antes de usarse").

Reparación en caliente: profesor documentó qué hace cada uno + admitió el error de método. Además, dentro de los 3 comandos, **profesor pidió el 3º con parámetro incorrecto** (`--version-id v1` cuando el metadato del comando 2 decía `DefaultVersionId: v2`). Sin repararlo, el JSON traducido a HCL en Bloque 5 habría sido la versión vieja de la policy → drift post-import.

**Regla derivada** (candidata):

> **Regla nueva #S12H-3 (candidata):** Cuando un comando lee metadatos que incluyen `DefaultVersionId` (o campos análogos que apuntan a otra versión/revisión), leer el output ANTES de escribir el siguiente comando que dependa de esa versión. Nunca hardcodear versión asumida. Variante concreta de la regla ⭐⭐⭐ #17 aplicada a inputs del descubrimiento AWS.

### Sorpresa gorda del descubrimiento

Prompt S12-H anticipaba "1-3 policies attached, probable candidata AWS-managed genérica (`AmazonS3ReadOnlyAccess` o `AmazonS3ReadWriteAccess`)". Realidad AWS:

- **1 policy attached, `customer-managed`** con ARN `arn:aws:iam::750392809244:policy/task-manager-s3-uploads-rw` (el `750392809244` en la cuenta indica customer-managed, no AWS-managed que tendría `aws` en la cuenta). Contenido activo v2 con 3 statements: `ListAllMyBuckets`, `ListSpecificBucket`, `ReadWriteObjects`. **Predicción teórica del profesor falsa**: enseñanza directa aplicando regla ⭐⭐⭐ #S12E-1 ("empírico controlado es la única fuente de verdad").

- **1 inline policy inesperada**, `AWSRevokeOlderSessions`, con `Effect: Deny`, `Action: *`, `Resource: *`, `Condition: DateLessThan aws:TokenIssueTime = "2026-08-04T19:11:54.699Z"`. Auto-generada por AWS cuando alguien pulsó el botón "Revoke sessions" en la consola web del Role 25 min después de crearlo (18:46 → 19:11). Predicción teórica del profesor "array vacío en inline policies" **falsa** también.

### Análisis y decisión pactada — Opción B para la inline policy

Dos caminos analizados conjuntamente:

- **Opción A**: importar tal cual como `aws_iam_role_policy.revoke_older_sessions`. Cumple regla ⭐⭐⭐ #S12G-4 (brownfield strict). Coste: JSON con timestamp hardcoded queda congelado en HCL; si alguien vuelve a pulsar "Revoke sessions" desde consola, AWS actualiza la inline con nuevo timestamp → **drift permanente garantizado**.

- **Opción B**: excluir del scope Terraform como se excluyó el default SG en S12-F. Anotar decisión pactada como candidato ADR-A14: "Inline policies auto-generadas por consola AWS (`AWSRevokeOlderSessions`, `AWSDenyAll`, etc.) no se importan a Terraform por diseño — su ciclo de vida es de gestión AWS, no de IaC".

Alumno eligió **Opción B**. Decisión pactada:

> **Deuda técnica candidata ADR-A14**: `aws_iam_role_policy.revoke_older_sessions` (inline policy `AWSRevokeOlderSessions`) excluida explícitamente del scope Terraform. Ciclo de vida gestionado dinámicamente por AWS mediante el botón "Revoke sessions" de consola. Importar generaría drift permanente. Análogo al `sg-01f966cb344439254` (default SG) excluido en S12-F.

### Regla derivada del fallo de descubrimiento del Role (aterrizada en Bloque 4)

Profesor afirmó al final de Bloque 2 que "el Role no tiene `description` porque no aparece en el output". **Afirmación falsa** — el output venía de `list-roles --query '[RoleName,Arn,CreateDate]'`, el filtro `--query` **descarta description por diseño**. Nunca ejecutó `get-role` sin filtro. La afirmación no verificada empíricamente causó bug de omisión en el HCL del Role.

## Bloque 4 — Import IAM Role con heredoc + drift descubierto post-import + corrección + regla nueva #S12H-5 aterrizada por caso positivo

### Escritura del HCL

Address pactado: `aws_iam_role.ec2_task_manager`. Atributos declarados (versión inicial):
- `name = "task-manager-ec2-role"` (Optional, declarar por ⭐⭐⭐ #10).
- `assume_role_policy` como heredoc `<<-POLICY ... POLICY`.
- `tags = { Name = "task-manager" }` (bug — debería ser `Project`).

**Verificación conjunta línea por línea (locked ⭐⭐⭐ #S12F-10, aplicación #1 de la sesión) cazó bug real**: tag `Name = "task-manager"` en HCL vs realidad AWS `Project = "task-manager"` (output `list-role-tags` que Tole había ejecutado). Sin la regla, plan post-import querría eliminar tag `Project` y añadir `Name`.

Corrección aplicada. Delimitador del heredoc cambiado a `POLICY` (opcional, por autodocumentación). Verificación pase 2 cerrada limpia. `terraform validate` OK.

### Ciclo pactado ejecutado

1. Predicción plan pre-import (4 sub-predicciones): alumno acertó las 4 (`+ create`, `1 to add / 0 to change / 0 to destroy`, 22 recursos refreshing sin cambios, `tags_all` aparecerá — con duda en el porqué).
2. `terraform plan` → confirmó las 4 predicciones. Refuerzo del profesor sobre `tags` vs `tags_all`: **`tags` es Optional puro (declaras tú), `tags_all` es Computed puro (Terraform calcula sumando `tags` + `default_tags` del provider)**. Coinciden cuando no hay `default_tags` a nivel provider. `tags_all` nunca se declara en HCL.
3. `terraform import aws_iam_role.ec2_task_manager task-manager-ec2-role` → limpio. Peculiaridad IAM confirmada: `id = name` en Role.
4. Predicción plan post-import (4 sub-predicciones): alumno predijo `No changes`. **Predicción falsa** — plan salió con `~ update in-place` proponiendo eliminar el atributo `description` que AWS tenía y HCL no declaraba.

### Drift descubierto y aterrizaje de regla #S12H-5 por caso positivo real

Output del plan post-import:

```
- description = "IAM Role attached to task-manager-ec2 instance. Grants read/write access to toleflaco-task-manager-uploads-2026 S3 bucket via task-manager-s3-uploads-rw policy." -> null
```

**Traceback del fallo del profesor**: afirmación no verificada en Bloque 2 ("description: no aparece → no tiene"). Comandos ejecutados durante el descubrimiento: `list-roles` con `--query 'Roles[?...].[RoleName,Arn,CreateDate]'` (filtro descarta description), `list-instance-profiles-for-role` (no incluye description del Role en la respuesta estándar), `list-role-tags` (solo tags). **Nunca ejecutó `aws iam get-role --role-name task-manager-ec2-role` sin filtro**. Reparación en caliente sin softening.

Regla derivada:

> **Regla nueva #S12H-5 (candidata → locked S12-H):** Antes de escribir HCL de un recurso, ejecutar `aws <service> get-<resource>` sin `--query` para leer TODOS los atributos, no solo los que interesan superficialmente. `list-*` con `--query` no sustituye a `get-*` completo — filtros descartan atributos silenciosamente. Es hija directa de ⭐⭐⭐ #S12F-10 (verificación línea por línea) y ⭐⭐⭐ #S12E-1 (empírico > teórico): la verificación línea por línea no basta si **el descubrimiento AWS previo fue incompleto** — puedes verificar carácter a carácter contra un output que no contenía todo lo que existe en AWS.

Aplicación #1 (caso positivo real): drift capturado, corregido añadiendo `description = "..."` con el string exacto del output completo de `get-role`.

Verificación conjunta pase 3 (locked ⭐⭐⭐ #S12F-10, aplicación #3 de la sesión): OK. `terraform plan` post-corrección → `No changes`. Bloque 4 cerrado. State serial **26**, `state list = 23`.

## Bloque 5 — Import customer-managed Policy con `jsonencode()` (dumpeo de traducción y su reparación en Ejercicio B)

### Fallo del profesor: dumpeo de la traducción JSON → HCL completa

Profesor introdujo `jsonencode()` como función built-in de HCL y **le dio al alumno el bloque HCL del `jsonencode({...})` ya traducido íntegramente** del JSON de la policy customer-managed (con `=` en lugar de `:`, claves sin comillas, comas correctas en listas). Alumno pegó bloque con dos bugs mecánicos triviales (`jsondecode` en vez de `jsonencode`, `Version = "2012-10-07"` en vez de `2012-10-17`) que se corrigieron rápido, y observó honestamente: **"fue fácil, me diste el contenido del jsonencode({...})"**.

Fallo de método del profesor asumido sin softening: violó contrato pedagógico ("Claude da pistas, no soluciones. Alumno escribe cada línea."). Solo aterrizó `jsonencode` conceptualmente (existe, se opone a `jsondecode`), no operativamente. Regla derivada:

> **Regla nueva #S12H-6 (candidata):** Cuando el bloque HCL tiene una traducción mecánica reversible (JSON → HCL, YAML → HCL, etc.), NO dumpear la traducción completa. Dar el original + reglas de traducción y que el alumno traduzca. Verificar traducción antes de validate. Antipatrón "no facilitar la parte donde está el aprendizaje real, aunque sea mecánica".

### Corte de sesión pactado a las 09:15

Alumno anunció que a las 09:15 debía salir. Pactado corte con Ejercicio B (reescribir `Statement` desde JSON aplicando reglas de traducción, ~15 min en caliente sin llegar a import) para aterrizar `jsonencode` realmente antes del cierre. Decisión pactada:

- Ejercicio B ejecutado: alumno borró `Statement` completo, reescribió aplicando reglas explícitas del profesor (8 reglas cortas: `:` → `=`, claves sin comillas, valores string con comillas, objetos `{}`, listas `[]`, comas opcionales entre pares, comas obligatorias entre elementos de lista).
- **`terraform validate` cazó bug**: coma faltante entre `}` de Statement 1 y `{` de Statement 2. Error CLI: `Missing item separator ... Expected a comma to mark the beginning of the next item.`
- **Fallo secundario del profesor**: verificación línea por línea del pase 6 (S12F-10) no cazó la coma faltante — dije "comas entre statements 1-2 y 2-3 ✓" cuando en realidad no había coma entre 1 y 2. Ojo cansado al final de la sesión larga. Aterrizaje: la regla depende de que la verificación se ejecute con atención real, no mecánicamente.

Regla derivada del fallo secundario:

> **Regla nueva #S12H-7 (candidata):** En listas de objetos multilínea (statements IAM, blocks anidados, arrays JSON en HCL), releer específicamente los cierres `}` seguidos de `{` siguiente. Es el punto exacto donde falta la coma en el 95% de los bugs de este tipo, y donde el newline oculta visualmente la ausencia. Corolario práctico de locked ⭐⭐⭐ #S12F-10.

Corrección aplicada por el alumno. `terraform validate` → `Success!`. Sesión cortada a las 09:15 con HCL del Policy escrito+validado pero SIN import. Working tree sucio con `iam.tf` untracked. Estado pactado explícitamente para retomo posterior.

### Retomo 9 sep 06:30 — ciclo de import Policy ejecutado limpio

Tras Bloque 0 mini de verificación, ciclo pactado ejecutado sin incidentes:

1. Predicción plan pre-import (alumno): las 4 correctas al primer intento. Confirmación de aprendizaje aterrizado por 4ª iteración del ciclo en la sesión.
2. `terraform plan` pre-import → `+ create`. Anticipación empírica de `id = arn` en Policy visible en el output.
3. `terraform import aws_iam_policy.s3_uploads_rw arn:aws:iam::750392809244:policy/task-manager-s3-uploads-rw` → limpio. **Confirmación empírica**: `id = arn` en Policy (peculiaridad IAM, distinta del Role donde `id = name`).
4. Predicción plan post-import (profesor esta vez, aplicación 2 de #S12H-5 como aplicación normal): `No changes`. Riesgo residual solo en `policy` (semánticamente denso), atributos ya declarados desde output completo de `get-policy`.
5. `terraform plan` post-import → `No changes` ✓. **Regla #S12H-5 aplicación 2 (normal) exitosa**. State serial **27**, `state list = 24`.

## Bloque 6 — Import Policy Attachment con referencia `.id` corregida a `.name`/`.arn` (nueva regla #S12H-8)

### Fallo original: `.id` como comodín

Alumno escribió HCL usando `.id` como comodín en las dos referencias:

```hcl
role       = aws_iam_role.ec2_task_manager.id
policy_arn = aws_iam_policy.s3_uploads_rw.id
```

Profesor **se saltó la verificación conjunta línea por línea** (locked ⭐⭐⭐ #S12F-10) y dejó al alumno ejecutar `validate` y `plan` directos. Ambos salieron OK porque en IAM `id = name` (Role) e `id = arn` (Policy) — coincidencia por peculiaridad del schema.

**Fallo detectado post-plan**: el HCL funcionaba pero rompía la convención Terraform de usar el atributo semánticamente correcto según el schema del recurso destino. Análisis honesto compartido con el alumno:

- `id = name` en Role es peculiaridad IAM. Otros recursos AWS NO lo tienen (`aws_vpc.id = "vpc-0d36..."` ≠ name).
- `id = arn` en Policy es peculiaridad IAM. La convención comunidad es usar `.name` cuando el schema pide name y `.arn` cuando pide ARN.
- Usar `.id` como comodín "porque funciona igual" impide aterrizar la diferencia entre `id`, `name`, `arn` en el schema del provider.

Alumno preguntó explícitamente: **"en la policy es arn??"**. Refuerzo con regla mnemónica derivada:

> **Regla nueva #S12H-8 (candidata):** Referencias HCL a recursos deben usar el atributo semánticamente correcto según el schema del destino, no el `.id` como comodín, aunque coincidan por peculiaridades del provider. Reglas mnemónicas para IAM: Role (`id = name` → usar `.name`), Policy (`id = arn` → usar `.arn`). Nunca `.id` en referencias entre recursos IAM cuando existe atributo semánticamente correcto.

Corrección aplicada:

```hcl
role       = aws_iam_role.ec2_task_manager.name
policy_arn = aws_iam_policy.s3_uploads_rw.arn
```

**Confirmación empírica directa**: `terraform plan` con la corrección produce **exactamente el mismo string resuelto** que con `.id`. Dos rutas HCL distintas, mismo resultado semántico. Solo la corregida es correcta convencionalmente.

### Ciclo de import ejecutado

1. Predicción plan pre-import (alumno): 3 sub-predicciones correctas.
2. `terraform import aws_iam_role_policy_attachment.ec2_task_manager_s3_uploads_rw task-manager-ec2-role/arn:aws:iam::750392809244:policy/task-manager-s3-uploads-rw` — **ID compuesto** con formato `<role_name>/<policy_arn>` (verificado en docs oficiales del provider). Import limpio.
3. Confirmación empírica: `id` del attachment en state = literalmente el ID compuesto completo. No opaco, concatenación textual.
4. Predicción plan post-import (alumno): `No changes`, sin drift por atributos ocultos (schema del attachment tiene solo 2 atributos declarables, ambos Required — no hay superficie para atributos ocultos). Regla #S12H-5 **no aplica aquí porque no hay huecos**. Justificación correcta del alumno.
5. `terraform plan` post-import → `No changes` ✓. State serial **28**, `state list = 25`.

**Regla #S12H-8 aplicación #1 como caso normal** (aterrizada tras corrección).

## Bloque 7 — Import Instance Profile (sin sorpresas)

Verificación empírica pre-HCL con `get-instance-profile` completo (aplicación 3 de #S12H-5 como caso normal): output confirmó `Path: /` (default, omitir), `Tags: []` (vacío, omitir), atributos requeridos únicos `name` y `role`.

HCL escrito por el alumno (aplicación #2 de #S12H-8 como caso normal):

```hcl
resource "aws_iam_instance_profile" "ec2_task_manager" {
  name = "task-manager-ec2-role"
  role = aws_iam_role.ec2_task_manager.name
}
```

Verificación conjunta pase 8 de S12F-10: cerrada limpia.

Ciclo pactado condensado (profesor propuso comprimir pasos repetitivos tras 3 iteraciones del ciclo en la sesión, alumno cómodo con la mecánica):

1. `terraform validate` → OK.
2. `terraform plan` pre-import → `+ create` sobre Instance Profile, `Plan: 1 to add, 0 to change, 0 to destroy`.
3. `terraform import aws_iam_instance_profile.ec2_task_manager task-manager-ec2-role` — ID = name. **Punto de atención**: mismo string que el `id` del Role, pero Terraform distingue por address distinto.
4. `terraform plan` post-import → `No changes` ✓. State serial **29**, `state list = 26`.

**Confirmación empírica de #S12H-5 aplicación 3** (caso normal, sin drift): descubrimiento completo con `get-instance-profile` sin filtro produjo cobertura suficiente.

## Bloque 8 — Higiene + commit + push con 3 amend consecutivos (triple confirmación cazó dos bugs)

### `terraform fmt` sin efecto — anotación operativa

Profesor asumió durante toda la sesión que había desalineación de `=` en los bloques y anunció `terraform fmt` como paso obligatorio de higiene. Ejecutado: **sin output**. Ningún fichero modificado. Los `=` estaban alineados por convención Terraform desde el principio.

Anotación honesta: **no afirmar convenciones sin verificarlas empíricamente**. Aplica también a estilo, no solo a semántica. La asunción "faltaba higiene" era teórica sin base. Anotado como fallo menor de método del profesor.

### Ciclo git con 3 intentos de commit por bugs en el mensaje

Contenido del commit: 66 líneas, 4 bloques (Role + Policy + Attachment + Instance Profile), coherente con las decisiones pactadas (Opción B para inline policy, regla #S12H-8 aplicada, description del Role corregido).

`git add iam.tf` → `git status` → `git diff --staged` (aplicación #9 de S12F-10): snapshot limpio, sin bugs residuales de sesiones anteriores no reintroducidos (tag `Name`/`Project` correcto, `Version = "2012-10-17"` correcto, `jsonencode` no `jsondecode`, comas entre statements presentes).

**Primer commit (hash `abd7fda`) fallido**: alumno redactó mensaje sin separación línea en blanco entre asunto y cuerpo, sin estructura bilingüe EN/`---`/ES, con acentos en la parte ES (`importó`, `corrección`), y con cuerpo incompleto (omitidas decisiones ADR-A14 y aprendizajes empíricos).

Triple confirmación cazó los 4 problemas antes de push. `git commit --amend` propuesto con mensaje limpio de estructura EN + `---` + ES sin acentos.

**Segundo commit (hash `de714c1`) también fallido**: alumno reabrió editor con `--amend` y en lugar de borrar el mensaje viejo, pegó el nuevo debajo. Resultado: dos asuntos concatenados, tres bloques (viejo + EN + ES) en vez de dos, acentos residuales del mensaje viejo.

Triple confirmación cazó el bug secundario. Instrucciones explícitas al alumno para segundo `--amend`: **borrar TODO el mensaje actual en el editor (`ggdG` en Vim) antes de pegar el nuevo**.

**Tercer commit (hash `f395d8b`) limpio**: estructura Conventional Commits + bilingüe + sin acentos ni ñ + cuerpo completo con decisiones y aprendizajes. Verificación con `git log -1 --format=full` OK.

### Triple confirmación (5ª aplicación consecutiva)

```
Tole confirma: SÍ cuerpo del commit revisado y correcto.
Claude confirma: SÍ — mensaje limpio, estructura bilingüe correcta, cuerpo completo.
Claude autoriza push: SÍ.
```

`git push` → `6e40c94..f395d8b main -> main`. Push limpio.

**Regla ⭐⭐⭐ #31 aterrizada 5ª vez consecutiva**. Aterrizaje mixto en esta sesión: **caso positivo real 2 veces** (cazó 4 problemas en el 1er commit + cazó bug de concatenación en el 2º commit) + **caso normal 1 vez** (3er commit limpio). Sin la ceremonia, `origin/main` tendría historial permanente con bugs de formato. Aterrizaje por caso positivo real es más raro que por caso normal — es una sesión de peso para la regla.

## Aprendizajes empíricos consolidados en S12-H

### Promociones desde candidatas a **locked ⭐⭐⭐**

1. **⭐⭐⭐ #S12H-1 (locked S12-H):** Warmup máximo 2 preguntas, 5 min techo. Filtro estricto: "si el alumno falla esta pregunta, ¿escribe HCL corrupto en los próximos 30 minutos?" Todo lo demás va al cierre (bitácora) o al bloque conceptual sin preguntar. Aterrizada por aplicación única con impacto operativo evidente (warmup reformulado in-situ de 5 preguntas a 2 preguntas, ahorro ~20 min, alumno pudo entrar al Bloque 2 con energía en lugar de con frustración).

2. **⭐⭐⭐ #S12H-5 (locked S12-H):** Antes de escribir HCL de un recurso, ejecutar `aws <service> get-<resource>` sin `--query` para leer TODOS los atributos. `list-*` con filtros descarta atributos silenciosamente. La verificación línea por línea no basta si el descubrimiento AWS previo fue incompleto. **3 aplicaciones mixtas en la sesión** (1 caso positivo real cazando drift `description` en Role + 2 aplicaciones normales exitosas en Policy e Instance Profile). Criterio 3-5 aplicaciones mixtas para locked cumplido.

3. **⭐⭐⭐ #31 aterrizada 5ª vez** (locked S12-F): triple confirmación conjunta pre-push. Sesión de peso — aterrizaje por caso positivo real (2 veces, cazando bugs de formato en 1er y 2º amend) + caso normal 1 vez (3er amend limpio). Consolidación total.

### Nuevas reglas empíricas de S12-H (candidatas para promoción futura)

4. **⭐⭐⭐ #S12H-3 (candidata):** Cuando un comando lee metadatos que incluyen `DefaultVersionId` (o campos análogos que apuntan a otra versión/revisión activa), leer el output ANTES de escribir el siguiente comando que dependa de esa versión. Nunca hardcodear versión asumida. Variante concreta de la regla ⭐⭐⭐ #17 aplicada a inputs del descubrimiento AWS. **1 aplicación en S12-H (caso positivo real, cazó el bug del profesor con `--version-id v1`)**.

5. **⭐⭐⭐ #S12H-6 (candidata):** Cuando el bloque HCL tiene una traducción mecánica reversible (JSON → HCL, YAML → HCL, etc.), NO dumpear la traducción completa. Dar el original + reglas de traducción y que el alumno traduzca. Antipatrón "no facilitar la parte donde está el aprendizaje real, aunque sea mecánica". **1 aplicación en S12-H (caso positivo real, alumno detectó el dumpeo y demandó corrección con "fue fácil, me diste el contenido")**.

6. **⭐⭐⭐ #S12H-7 (candidata):** En listas de objetos multilínea (statements IAM, blocks anidados, arrays JSON en HCL), releer específicamente los cierres `}` seguidos de `{` siguiente. Es el punto exacto donde falta la coma en el 95% de los bugs de este tipo, y donde el newline oculta visualmente la ausencia. Corolario práctico de locked ⭐⭐⭐ #S12F-10. **1 aplicación en S12-H (caso positivo real cazado por `validate` cuando la ceremonia S12F-10 falló por ojo cansado del profesor)**.

7. **⭐⭐⭐ #S12H-8 (candidata):** Referencias HCL a recursos deben usar el atributo semánticamente correcto según el schema del destino, no el `.id` como comodín, aunque coincidan por peculiaridades del provider. Reglas mnemónicas IAM: Role (`id = name` → `.name`), Policy (`id = arn` → `.arn`). **2 aplicaciones normales en S12-H** (Attachment corregido tras primer intento con `.id`, Instance Profile escrito directamente con `.name`). Falta al menos 1-2 aplicaciones más para promoción a locked.

8. **⭐⭐⭐ #S12H-analogías (candidata operativa)**: Cuando se necesite analogía técnica al perfil backend del alumno, verificar antes que la tecnología comparada ya está en su modelo mental. Kubernetes, Docker Swarm, service mesh, etc., son fuera de scope hoy en su roadmap — usar sistemas que el alumno ya conoce (su propia app Spring Boot, JWT, OAuth2, Java servlets). Aterrizada por caso positivo real (alumno detectó "no sé nada de Kubernetes"). **1 aplicación en S12-H**.

## Estado exacto al cierre de S12-H

Terraform:
- CLI 1.15.8, provider AWS 6.59.0 (~> 6.58 en versions.tf).
- Backend S3 con `use_lockfile = true`.
- State en `s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate`, serial **29**, lineage sin cambios, resources = **26**.
- `terraform plan` global = `No changes`.

Ficheros infra/:
- `versions.tf` — sin cambios.
- `main.tf` — 22 recursos (14 red + 7 seguridad + 1 VPC Endpoint), sin cambios en S12-H.
- `iam.tf` — **fichero nuevo creado en S12-H, 66 líneas, 4 recursos IAM**.
- `.terraform.lock.hcl` — sin cambios.

Recursos en state (26):
- **Red (14, desde S12-E)**: `aws_vpc.main`, 4 subnets, `aws_internet_gateway.task_manager`, 3 RTs, `aws_route.public_to_igw`, 4 associations.
- **Seguridad (7, desde S12-F)**: 2 contenedores SG + 3 reglas ec2 + 2 reglas db.
- **Conectividad interna (1, desde S12-G)**: `aws_vpc_endpoint.s3` con 3 RTs asociadas.
- **Identidad IAM (4, nuevos en S12-H)**:
  - `aws_iam_role.ec2_task_manager` (name `task-manager-ec2-role`, `assume_role_policy` para Principal `ec2.amazonaws.com`, description declarado, tag `Project`).
  - `aws_iam_policy.s3_uploads_rw` (customer-managed, ARN `arn:aws:iam::750392809244:policy/task-manager-s3-uploads-rw`, 3 statements: ListAllMyBuckets + ListSpecificBucket + ReadWriteObjects, versión activa v2).
  - `aws_iam_role_policy_attachment.ec2_task_manager_s3_uploads_rw` (binding Role↔Policy).
  - `aws_iam_instance_profile.ec2_task_manager` (envoltorio EC2 del Role).

Commits desde S12-G:
- `f395d8b feat(infra): import iam identity resources for ec2 task manager` (con mensaje bilingüe correcto tras 2 amend previos fallidos).

Pendiente commitear en frío:
- `bitacora/Sesion12-Import-Checklist.md` con casillas IAM (Role + Policy + Attachment + Instance Profile) tachadas.
- `bitacora/Sesion12-H-AWS-Diario.md` (este documento).

RDS: `stopped`. **Próximo deadline auto-arranque ~15-16 sep** (contador reseteado el 6 sep en S12-G, +7 días desde ahora). Si S12-I se hace después del 15 sep, arrancar+parar manual antes de tocar Terraform.

Deuda técnica anotada acumulada:
- **S12-G #1** (candidato ADR-A13): RT pública asociada al VPC Endpoint sin valor operativo. Corrección diferida a primer apply del roadmap.
- **S12-H #1** (candidato ADR-A14): Inline policy `AWSRevokeOlderSessions` excluida del scope Terraform por diseño (auto-generada por consola AWS, timestamp hardcodeado, gestión dinámica AWS).

## Pendientes para S12-I (~2h estimadas, matutinas)

Bloque de aplicación (S3 uploads bucket + subrecursos) + arranque bloque de cómputo si sobra tiempo. Recursos AWS pendientes de import (5-7 según decisiones):

1. **S3 uploads bucket** (`aws_s3_bucket.task_manager_uploads` con name `toleflaco-task-manager-uploads-2026`).
2. **S3 bucket policy** (`aws_s3_bucket_policy` — verificar si existe con `aws s3api get-bucket-policy`).
3. **S3 bucket versioning** (`aws_s3_bucket_versioning`).
4. **S3 bucket encryption** (`aws_s3_bucket_server_side_encryption_configuration`).
5. **S3 bucket public access block** (`aws_s3_bucket_public_access_block`).
6. **EC2 instance** `task-manager-ec2` — probablemente S12-J.
7. **RDS instance** `task-manager-db` — probablemente S12-J.

**Prioridad si el tiempo se acorta**: S3 bucket + subrecursos hoy, EC2 + RDS a S12-J. Cerrar bloques coherentes por sesión.

### Verificaciones empíricas esperadas en S12-I

- **`aws_s3_bucket`**: recurso maestro con muy pocos atributos declarables (name, force_destroy, tags). Los detalles (versioning, encryption, ACL) están **desagregados** en subrecursos separados desde AWS provider 4.x. Patrón moderno análogo a SGs modernas y attachments modernos.
- **Descubrimiento con `aws s3api get-bucket-*` sin filtro** aplicando locked ⭐⭐⭐ #S12H-5. Comandos anticipados:
  - `aws s3api get-bucket-versioning --bucket toleflaco-task-manager-uploads-2026`.
  - `aws s3api get-bucket-encryption --bucket toleflaco-task-manager-uploads-2026`.
  - `aws s3api get-public-access-block --bucket toleflaco-task-manager-uploads-2026`.
  - `aws s3api get-bucket-policy --bucket toleflaco-task-manager-uploads-2026` (puede no existir — no toda bucket tiene policy explícita).
  - `aws s3api get-bucket-tagging --bucket toleflaco-task-manager-uploads-2026`.
- **Predicción teórica sobre Optional+Computed** en atributos S3: probable en `versioning_configuration.status`, `server_side_encryption_configuration.rule.apply_server_side_encryption_by_default.sse_algorithm`, `public_access_block_configuration.*`. Verificar empíricamente aplicando ⭐⭐⭐ #S12F-1.
- **Address propuestos**: `aws_s3_bucket.task_manager_uploads`, `aws_s3_bucket_versioning.task_manager_uploads`, `aws_s3_bucket_server_side_encryption_configuration.task_manager_uploads`, `aws_s3_bucket_public_access_block.task_manager_uploads` (todos con el mismo address local para coherencia).
- **Aplicación #3 de regla candidata #S12H-8** (referencias `.name`/`.arn` no `.id`): probable en `aws_s3_bucket_versioning.bucket = aws_s3_bucket.task_manager_uploads.id` — **atención**: en S3 el `id = bucket_name`, el atributo del schema del subrecurso es `bucket` que pide el nombre. Verificar peculiaridad del schema.

### Reglas operativas OBLIGATORIAS para S12-I

- **Al arrancar**: Bloque 0 completo con los 5 comandos habituales. Esperado: serial 29, `state list = 26`, RDS `stopped`, IP `88.11.202.24` (si rotó no bloquea S3 pero anotar).
- **Warmup MÁXIMO 2 preguntas**, 5 min techo — locked ⭐⭐⭐ #S12H-1 no negociable. Preguntas críticas para S12-I: (i) diferencia entre patrón viejo (`aws_s3_bucket` con bloques anidados `versioning`, `server_side_encryption_configuration`) y patrón moderno (recursos separados por concern), (ii) referencia HCL correcta al bucket desde subrecursos (`bucket = aws_s3_bucket.<address>.id` — peculiaridad S3 análoga a IAM Role `.name`).
- Ciclo pactado obligatorio con predicción escrita en cada paso.
- Vocabulario nuevo (S3 versioning states, SSE-S3 vs SSE-KMS, public access block variantes) introducido explícitamente antes de aparecer. Máximo 3 conceptos consecutivos.
- **`aws s3api get-*` sin filtro antes de HCL para cada subrecurso** (locked ⭐⭐⭐ #S12H-5).
- Verificación conjunta línea por línea del HCL antes de validate (locked ⭐⭐⭐ #S12F-10).
- Triple confirmación conjunta obligatoria antes de git push (locked ⭐⭐⭐ #31).
- **Bitácora S12-H releída antes del warmup** — regla operativa 48-72h.

### Cosas que NO hacer en S12-I

- NO importar el bucket `toleflaco-terraform-state-2026` — bootstrap manual documentado.
- NO importar MongoDB Atlas — provider distinto.
- NO importar la deuda técnica S12-G #1 (RT pública en VPC Endpoint) — corrección diferida a apply.
- NO usar el patrón viejo `aws_s3_bucket` con bloques anidados (`versioning`, `server_side_encryption_configuration`). Solo recursos separados modernos.
- NO tocar EC2 ni RDS todavía — cierre S3 primero.
- NO importar policies inline de bucket si aparecen — analizar caso por caso como se hizo con `AWSRevokeOlderSessions`.
- NO ejecutar apply de nada — reglas ⭐⭐⭐ #14 + #17.
- NO dumpear traducciones JSON → HCL completas (regla candidata #S12H-6 aplicada).
- NO usar analogías a tecnologías fuera del modelo mental del alumno (regla candidata #S12H-analogías aplicada).

## Meta-observaciones de método

1. **Densidad pedagógica alta en una sola sesión**: 5 reglas candidatas nuevas + 2 promociones a locked + 4 fallos de método del profesor asumidos sin softening. Ratio "aterrizajes de regla por hora" ~1.5, sensiblemente por encima de S12-G (~1.0). Explicable por primera vez con JSON en HCL + primera vez con customer-managed IAM + primera vez con ID de import compuesto.

2. **Warmup reformulado en caliente por petición del alumno**. Alumno explicitó dificultad con el formato original ("estos warmups me cuestan un mundo"). Profesor reconoció fallo de método sin softening y reformuló in-situ. Regla operativa aterrizada: **cuando el alumno pide cambio de método por fricción real (no capricho), aceptar y reformular en caliente, no defender el método por consistencia con el prompt de continuación**. El prompt es intención (regla ⭐⭐⭐ #25 de S12-D), no dogma.

3. **4 fallos de método del profesor en una sesión**. Sin softening:
   - (a) Analogía a Kubernetes cuando el alumno no lo conoce.
   - (b) 3 comandos AWS CLI ejecutados sin explicar qué hacen.
   - (c) Afirmación no verificada "description no aparece → no tiene" (basada en `list-*` con filtro, no en `get-*` completo).
   - (d) Dumpeo de la traducción JSON → HCL completa privando al alumno del aprendizaje operativo de `jsonencode`.
   
   Los 4 fueron cazados: (a) por el alumno con "no sé nada de Kubernetes", (b) por el alumno con "no sé exactamente lo que haces con esos tres comandos", (c) por el post-import plan del Role (drift `description`), (d) por el alumno con "fue fácil, me diste el contenido". Los 4 produjeron reglas derivadas anotadas. Coincidencia: **todos los fallos son de "asumir en lugar de verificar/explicar"**. Regla meta emergente: el profesor asume con confianza injustificada cuando la sesión lleva ritmo largo — mismo antipatrón que la regla ⭐⭐⭐ #S12E-1 aplicada al lado del profesor.

4. **Interrupción externa por rotura de tubería el 8 sep tarde**. Alumno no pudo reanudar el mismo día. Retomo 9 sep 06:30 con Bloque 0 mini. Estado exactamente cuadró con el pactado al cierre del día anterior — evidencia empírica de que el "prompt de retomo mental" al final de la sesión partida funciona. Sin drama.

5. **Triple confirmación pre-push aplicada 5ª vez consecutiva, con 2 amend previos cazando bugs de formato**. Es la primera vez que la ceremonia caza bugs no en el diff sino en el mensaje del commit. Extensión operativa: la regla protege el histórico contra bugs semánticos **y** contra bugs de formato/estructura del mensaje. Formulación memorable extendida: **"triple confirmación caza tanto el bug de código como el bug de comunicación sobre el código"**.

6. **`terraform fmt` sin efecto — asunción teórica del profesor sin base**. Anotado como fallo menor de método. Análogo al caso (c) del punto 3. Ambos son casos de "afirmar sin verificar".

7. **Duración real ~4h 15min vs pactada inicialmente 2h**. Sobrepaso x2 aceptado por el alumno sin drama, distribuido en dos ventanas por interrupción externa. Aprendizaje operativo: **sesiones con densidad pedagógica alta (5+ reglas candidatas descubiertas) requieren margen de tiempo o partición explícita en 2 ventanas**. Estimación futura para bloques con "primera vez con X" (JSON en HCL, customer-managed policy, ID compuesto) debería ir por 3h en lugar de 2h.

8. **Bitácora escrita por el profesor en modo "notas borrador"** a petición del alumno (opción implícita: ahora en caliente tras el push). **Este documento requiere revisión y adaptación por el alumno antes de commitear**. No es producto final — es andamiaje para acelerar el paso "en frío" sin sacrificar la reflexión personal.
