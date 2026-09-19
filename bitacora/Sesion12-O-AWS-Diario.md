# Bitácora S12-O — AWS Roadmap

**Fecha**: sábado 19 sep 2026, tarde (~12:15–~[hora cierre] aprox, ~[duración])
**Sitio**: WSL2, desde Nestares
**Hueco desde S12-Ñ**: ~27h (S12-Ñ cerró el viernes ~09:15)
**Estado emocional al arrancar**: "vamos tirando" (sin euforia, sin señal explícita)
**Tipo de sesión**: cierre del módulo AWS, densidad media, dos deudas cerradas (fix IP SG + ADR-026 acceso interactivo diferido)

## Resumen

Sesión de cierre del módulo AWS. Cerradas las dos deudas pendientes del prompt de continuación de S12-Ñ: fix IP casa en las ingress rules del SG de EC2, y candidata Axx post-A17 (acceso interactivo vía SSM) resuelta vía **ADR-026** como deuda documentada y diferida a módulo futuro de networking. El bloque de decisión SSM disparó una señal S12-C parcial del alumno ("joder ayer solo era cambiar la ip de la casa de Nestares, y ahora otra vez más cosas") por scope creep del profesor al desplegar tres opciones con costes NAT/endpoints en vez de aplicar Opción 2 simplificada como sugería el prompt. Recorte de scope acordado a mitad de sesión: cerrar solo las dos deudas básicas sin abrir módulo de networking. Cuatro commits pusheados a `origin/main` en un único push. Aplicación 8ª de triple confirmación pre-apply y 17ª de triple confirmación pre-push, ambas consecutivas sin refutación. **Cambio de plan post-módulo**: el alumno decide en Bloque 4 pasar a repaso Kafka + Kafka avanzado en la próxima sesión, en lugar de arrancar certificaciones AWS (SAA + DVA + AIF-C01) como estaba pactado. Cambio a reflejar en próximo prompt de continuación.

## Trabajo realizado

- **ADR-026** cerrado (Opción 2 simplificada tras señal S12-C): aceptar el estado actual como deuda documentada, sin cambios de HCL, decisión del método de acceso (SSM vía VPC endpoints, SSM vía NAT Gateway, o SSH vía IP pública) diferida a módulo futuro de networking cuando haya uso funcional real de la EC2. Estructura Michael Nygard estándar. Corrección pre-commit del puerto en Context: `HTTP (80)` → `HTTP (8080)`, alineando con la realidad de `ec2_http_home` (`from_port = 8080`).
- **Fix IP del SG aplicado**: `cidr_ipv4` en `aws_vpc_security_group_ingress_rule.ec2_ssh_home` y `aws_vpc_security_group_ingress_rule.ec2_http_home` de `88.11.202.24/32` a `88.11.252.248/32`. Cambio Cat 2 (update in-place vía API `ModifySecurityGroupRules`), sin destroy/create. La IP nueva coincide con la última IP conocida de S12-L (`88.11.252.248`), sin rotación /16 del ISP en el intervalo.
- **Verificación empírica del role IAM**: `aws iam list-attached-role-policies --role-name task-manager-ec2-role` confirma que `AmazonSSMManagedInstanceCore` NO está adjuntada. Única policy: `task-manager-s3-uploads-rw` (custom). Refuta la hipótesis de "diseño SSM completo, sólo faltaba doc".
- **Deuda `.gitignore` detectada y arreglada**: no ignoraba `*.tfplan`. Añadida entrada. Detectada al hacer `git status` post-plan-con-`-out` (aparecía `tfplan-s12o-fix-ip.tfplan` como untracked).
- **Reformateo `terraform fmt` aplicado y separado en commit propio**: `main.tf` (policy JSON del VPC endpoint S3 con `Sid`/`Effect`/`Action` desalineados por presencia de `Principal = { ... }` nested) y `ec2.tf` (bloque `key_pair` con `key_name` desalineado de `public_key`). Drift preexistente detectado por `terraform fmt -check -recursive` tras editar `main.tf`.
- **Ciclo pactado completo aplicado**: predicción escrita → `plan` → verificación conjunta línea por línea → triple confirmación pre-apply → `apply` con plan congelado (`-out=tfplan-s12o-fix-ip.tfplan`) → verificación post-apply en 3 dimensiones (plan `No changes`, serial 44 → 45, `describe-security-group-rules` con nuevos CIDR).
- **Cuatro commits pusheados en un único push a `origin/main`** (patrón "un commit por razón lógica"):
  1. `f0f3ee5 chore(git): ignore terraform plan files`
  2. `41c3078 fix(infra): update home ip in ec2 security group ingress rules` (bilingüe)
  3. `52b3ef8 style(infra): apply terraform fmt normalization to main.tf and ec2.tf` (bilingüe)
  4. `3f5088b docs(adr): add ADR-026 defer ec2 interactive access implementation` (bilingüe)
- **`git add -p` usado por primera vez para split de fichero mixto**: separación limpia de cambio funcional (fix IP) y reformateo (policy JSON) en `main.tf` respondiendo `y y n` a los 3 hunks presentados.

## Aprendizajes empíricos nuevos

- **Hallazgo S12-O — nombre vs realidad de `ec2_http_home`**: el recurso se llama `ec2_http_home` pero tiene `from_port = 8080` y `to_port = 8080`, no 80. Nombre histórico o aspiracional (puerto HTTP estándar), regla funcional en 8080 (puerto típico de Spring Boot). Anotable para lectores futuros; el nombre no puede cambiarse sin destroy+create de la regla, y no compensa. Regla candidata **#S12O-1**: verificar `from_port`/`to_port` reales en `describe-security-group-rules`, no confiar en el nombre lógico Terraform.
- **Hallazgo S12-O — `terraform fmt` y alineación con objetos nested**: `fmt` NO alinea los `=` a lo largo de un grupo de atributos cuando un objeto nested (como `Principal = { ... }`) rompe el grupo. Detectado en el policy JSON del VPC endpoint S3: `Sid`/`Effect`/`Action` se desalinean respecto a `Resource` cuando `Principal` está entre medias. Regla candidata **#S12O-2**.
- **Hallazgo S12-O — duración del apply Cat 2 (update in-place) sobre reglas SG**: 0s por regla (bajo el mínimo de resolución del reporter Terraform). Confirmación empírica del contraste con destroy+create de EC2 en S12-Ñ (~24s): cambios Cat 2 vía API `ModifySecurityGroupRules` son casi instantáneos frente a operaciones de provisioning que requieren creación de recursos nuevos. Complementa la regla candidata **#S12Ñ-1**.
- **Hallazgo S12-O — SSM Session Manager requiere policy IAM explícita**: el role IAM `task-manager-ec2-role` no tiene `AmazonSSMManagedInstanceCore` adjuntada (única policy: `task-manager-s3-uploads-rw`). Sin esa policy, SSM no funciona **aunque la EC2 tuviera conectividad a internet o VPC endpoints SSM**. El acceso vía SSM requiere: (a) `AmazonSSMManagedInstanceCore` en el role, (b) conectividad de la EC2 a los endpoints SSM (vía IP pública, NAT, o VPC endpoints), y (c) `amazon-ssm-agent` corriendo en la instancia (presente por defecto en AMIs Ubuntu recientes). Punto (a) faltaba.
- **Hallazgo S12-O — costes de acceso interactivo EC2 sin IP pública**: SSM vía VPC endpoints ~21 USD/mes (3 endpoints x ~7 USD), SSM vía NAT Gateway ~32 USD/mes, IP pública para SSH cero coste añadido pero rompe el diseño "sin IP pública". Costes no triviales para infra de roadmap sin uso funcional real. Motivó la Opción 2 (deuda diferida) del ADR-026.

## Aterrizajes / aplicaciones acumuladas

- **Triple confirmación pre-apply extendida (⭐⭐⭐ #31 aplicada al apply)**: 8ª aplicación consecutiva sin refutación (1 en esta sesión, acumulando desde S12-L).
- **Triple confirmación pre-push (⭐⭐⭐ #31)**: 17ª aplicación consecutiva sin refutación (1 en esta sesión con 4 commits apilados en un único push).
- **Redacción bilingüe correcta al primer intento (S12-H)**: 9ª sesión consecutiva sin `amend`. Objetivo S12-O cumplido con los 3 commits bilingües (fix, style, docs); el `chore` no llevaba body por naturaleza del cambio.
- **Locked ⭐⭐⭐ #S12I-2 (recordar plan de bloques ANTES del warmup)**: 2ª aplicación como regla locked. Aplicada al arranque.
- **Locked ⭐⭐⭐ #S12H-1 (warmup MAX 2 preguntas, 5 min techo)**: aplicada, warmup dentro del techo con 2 preguntas exactas (predicción categoría Cat 2 fix IP + hipótesis SSM).
- **Verificación conjunta línea por línea del HCL antes de `validate`** (⭐⭐⭐ #S12F-10): aplicada al `git diff` post-fix IP y post-reformateo.
- **Verificación conjunta línea por línea del `plan`** (⭐⭐⭐ #S12F-10 extendida al plan): aplicada al output del plan congelado, contrastado contra predicción escrita en 5 dimensiones.
- **`git log -1 --format=full` obligatorio entre `commit` y `push`** (⭐⭐⭐ #30): aplicado tras cada uno de los 4 commits.
- **`git diff --staged` obligatorio antes de `commit`**: aplicado antes de los 4 commits.
- **Uso de `-out` en `terraform plan` para congelar el plan**: aplicado tras corrección del primer intento sin `-out`.

## Autocorrecciones (honestidad)

- **Scope creep del profesor en Bloque 3**: prompt decía "candidata ADR nueva. Redactar ADR corto..." si SSM no estaba configurada. El profesor desplegó tres opciones con análisis de coste NAT Gateway (~32 USD/mes) y VPC endpoints (~21 USD/mes), arrastrando al alumno hacia una decisión de módulo de networking no pactada. Señal S12-C parcial del alumno ("joder ayer solo era cambiar la ip") detectada y validada. Recorte de scope acordado: Opción 2 simplificada (ADR corto de deuda diferida, cero cambios HCL). Patrón recurrente a corregir por parte del profesor: **ajustarse al scope pactado en el prompt de continuación en vez de re-escalar decisiones a mitad de sesión**.
- **Predicciones no dadas antes de comandos en Bloque 0**: 4 comandos ejecutados por el alumno sin predicción escrita previa (`git status`, `git log`, `terraform state list`, `aws s3 cp .../serial`). Todos de solo lectura, riesgo cero, pero el hábito del ciclo pactado no aplicado consistentemente. Alumno cumplió a partir del recordatorio del profesor.
- **Alumno "no me acuerdo" para valor anterior de `cidr_ipv4` en warmup B**: el valor `88.11.202.24/32` estaba escrito 5 veces en el hilo y en el prompt de continuación. Señal de cansancio o de escribir predicciones por cumplir el ritual. Aviso metodológico del profesor. Recuperación posterior consciente.
- **`terraform plan` primer intento sin `-out=tfplan.file`**: el propio Terraform advirtió al final del output ("Terraform can't guarantee to take exactly these actions..."). Repetido con `-out=tfplan-s12o-fix-ip.tfplan` para congelar y respetar patrón de sesiones previas.
- **`Ctrl+Alt+L` (IntelliJ HCL formatter) aplicado sin diagnóstico previo tras detección de drift `terraform fmt`**: el profesor había pedido `terraform fmt -diff -check` para entender qué cambiaba. Alumno reformateó directo. Coincidencia empírica: IntelliJ HCL plugin y `terraform fmt` coincidieron en este caso (verificado con `git diff` posterior). Aviso metodológico: la coincidencia no siempre está garantizada; el hábito correcto es diagnóstico antes de reformatear.
- **Puerto 80 residual en Context del ADR-026 (pre-commit)**: escrito como "HTTP (80)" en el primer draft. Regla real del SG es 8080. Detectado por el profesor en verificación pre-commit; corregido con `git restore --staged` + edición + re-`add`. ADR final consistente con la infra real.
- **Respuesta incorrecta al punto 7 del checklist de arranque**: alumno declaró "bitácora S12-Ñ ya commiteada/pusheada en frío: sí", pero `git log --oneline -3` en Bloque 0 mostró que no estaba. Bitácora existía en disco, fue commiteada y pusheada en Bloque 0 (`351010c`). Regla implícita para adelante: si el checklist pregunta "ya commiteado/pusheado", la respuesta se apoya en `git log`, no en memoria.

## Estado al cierre

- **Serial**: 45.
- **34 recursos gestionados** (sin cambio en conteo: solo update in-place de 2 ingress rules).
- **10 ADRs cerrados** en total: ADR-013, ADR-014, ADR-015, ADR-019, ADR-021, ADR-022, ADR-023, ADR-024, ADR-025, **ADR-026**.
- **Commits pusheados en esta sesión** (4, en un único push):
  - `f0f3ee5 chore(git): ignore terraform plan files`
  - `41c3078 fix(infra): update home ip in ec2 security group ingress rules`
  - `52b3ef8 style(infra): apply terraform fmt normalization to main.tf and ec2.tf`
  - `3f5088b docs(adr): add ADR-026 defer ec2 interactive access implementation`
- **Adicional commiteado y pusheado en Bloque 0**: `351010c docs(bitacora): add S12-Ntilde diary and update import checklist` (bitácora S12-Ñ, subida al arranque tras detectar discrepancia con la respuesta del checklist).
- **RDS**: sigue `stopped` desde S12-N. Deadline auto-arranque aproximado ~24 sep (5 días desde cierre S12-O). Alumno decide dejarlo `stopped` y confiar en su memoria para pararlo el 24 si auto-arranca. Sin acción automatizada.
- **EC2**: `i-0d757274b5a24ace7` sigue `running` con root volume `vol-013ad60da26b47031` cifrado (herencia S12-Ñ). Sin IP pública, sin SSM (documentado en ADR-026).
- **SG ingress rules** (`sg-036772953179b5905`): `ec2_ssh_home` (SSH 22) y `ec2_http_home` (TCP 8080) con `cidr_ipv4 = 88.11.252.248/32` (IP casa Nestares, coincide con última IP conocida de S12-L).
- **Snapshot preventivo** `snap-05adfec989a3bb3ec` ya borrado en S12-Ñ (no confundir con esta bitácora).
- **`.gitignore`**: ahora ignora `*.tfplan`. Fichero plan congelado `tfplan-s12o-fix-ip.tfplan` en el working directory local, no versionado.
- **Deudas conocidas que sobreviven al cierre del módulo AWS**:
  - Acceso interactivo EC2 no implementado (SSM o SSH). Documentado en ADR-026. Se reabre cuando haya uso funcional real de la EC2.
  - Aparente contradicción nombre vs realidad en regla `ec2_http_home` (nombre sugiere puerto 80, regla real 8080). Anotado en aprendizajes; sin acción — el ADR-026 ya refleja 8080.

## Nota para la próxima sesión

**Módulo AWS oficialmente cerrado** tras cierre de las dos últimas deudas (fix IP SG + ADR-026 acceso interactivo diferido). Ambas deudas se abordaron en una sola sesión desde Nestares con IP casa estable, como estaba previsto.

**Cambio de plan post-módulo**: el alumno decide en Bloque 4 pasar a **repaso Kafka + Kafka avanzado** en lugar de arrancar certificaciones AWS (SAA + DVA + AIF-C01) como estaba pactado en el prompt de continuación de S12-O. Cambio a reflejar en el próximo prompt de continuación, que ya tendrá prefijo distinto (S13-A o similar) al no ser continuación del módulo AWS.

RDS `stopped` y confianza en la memoria del alumno para pararlo el 24 si auto-arranca son la vía elegida — sin sistema automatizado. Si Kafka mañana no toca la infra AWS, RDS puede permanecer `stopped` sin interacción.

Señal S12-C parcial en Bloque 3 detectada y respondida con recorte de scope, ejemplo empírico del uso correcto de la regla. Estado emocional al cierre estable, sesión cerrada dentro de plan tras recorte. Aplicación 8ª de triple confirmación pre-apply y 17ª de pre-push consecutivas sin refutación, ambas confirmadas como reglas plenamente locked.
