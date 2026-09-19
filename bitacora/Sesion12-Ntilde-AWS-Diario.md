# Bitácora S12-Ñ — AWS Roadmap

**Fecha**: viernes 18 sep 2026, mañana (~06:30–~09:15 aprox, ~2h 45min)
**Sitio**: WSL2, desde Madrid (residencia temporal, no Nestares)
**Hueco desde S12-N**: ~11.5h (S12-N cerró el jueves ~19:00)
**Estado emocional al arrancar**: "bueno, ahí vamos" (mejor que el bajo del arranque de S12-N)
**Tipo de sesión**: dedicada a A17, densidad media-alta, un ADR cerrado con hallazgos empíricos genuinos post-apply

## Resumen

Sesión dedicada al cierre de **A17** (root volume encryption del EC2), única deuda técnica del módulo AWS diferida explícitamente a sesión propia por su naturaleza `destroy + create replacement`. Bloque 3 crítico completado con procedimiento pactado en frío antes de tocar HCL: verificación empírica de contenido en el EC2 (nada a preservar), elección de Estrategia A (recreación limpia via Terraform), pacto de rollback con snapshot preventivo, y verificación de disponibilidad de key pair `.pem` local. ADR-025 redactado antes del refactor HCL (excepción pactada por complejidad), con dos iteraciones de corrección hacia vocabulario Terraform estándar y eliminación de afirmaciones no formalizadas ("encryption-at-rest posture"). Apply completado con éxito en ~24s (destroy 11s + create 13s), verificación post-apply en 3 dimensiones limpia. Un commit pusheado a `origin/main`. Fix IP del SG **NO abordado** por diseño (alumno en Madrid con IP de tránsito). Aplicación 7ª de triple confirmación pre-apply y 16ª de triple confirmación pre-push, ambas consecutivas sin refutación.

## Trabajo realizado

- **ADR-025** cerrado: cifrar root EBS volume de `aws_instance.task_manager_ec2` estableciendo `encrypted = true` dentro del bloque `root_block_device`, sin declarar `kms_key_id` (default AWS-managed `aws/ebs`).
- **Bloque 3 completo** — procedimiento pactado en frío antes de tocar HCL: verificación empírica de contenido a preservar en EC2 (`describe-instances` + `get-console-output` → nada de usuario, solo actualizaciones automáticas de snap), elección de Estrategia A, pacto de rollback con snapshot preventivo `snap-05adfec989a3bb3ec` sobre el volumen `vol-0a213f4a54ca358e8`, confirmación de `.pem` local en `~/.ssh/task-manager-key.pem`.
- **ADR-025 redactado antes del refactor HCL** (excepción pactada por complejidad del destroy+create): estructura Michael Nygard estándar, dos iteraciones de corrección eliminando "encryption-at-rest posture" (política no formalizada) y sustituyendo jerga interna "Category 4" por vocabulario Terraform estándar `ForceNew`.
- **Retoque post-apply del ADR-025**: tras el hallazgo de que la AMI está hardcoded (no vía data source) y de que el EC2 no recibe IP pública por diseño (`map_public_ip_on_launch = false`), Consequences reformulado antes del commit para reflejar la realidad HCL.
- Ciclo pactado completo aplicado: predicción escrita → `plan` → verificación línea por línea → triple confirmación pre-apply → `apply` sin `-auto-approve` → verificación post-apply en 3 dimensiones.
- 1 commit limpio pusheado a `origin/main`: `b8a40d9`. Mensaje bilingüe correcto al primer intento sin amend (8ª sesión consecutiva).
- **Snapshot preventivo del root EBS** (`snap-05adfec989a3bb3ec`) tomado antes del apply como salvaguarda — nueva práctica S12-Ñ candidata a formalizar en futuros destroy+create de recursos con potencial contenido.

## Aprendizajes empíricos nuevos

- **Hallazgo A17 (ADR-025) — duración del apply para destroy+create de EC2**: `t3.micro` con root de 8 GiB completó en **~24 segundos** (11s destroy + 13s create), muy por debajo de la predicción del warmup de "2-5 min anclado contra los ~3 min de ADR-023". **Refutación empírica clara**. Explicación: los 3 min de ADR-023 eran migración física de storage type (gp2→gp3) sobre volumen RDS de datos — operación distinta y más costosa. El destroy+create de un EC2 pequeño con volumen root pequeño es fundamentalmente API-driven provisioning, no operación pesada de datos. Regla candidata **#S12Ñ-1**: duración de destroy+create de EC2 pequeño es del orden de decenas de segundos, no minutos.
- **Hallazgo A17 — IP pública no depende solo de subnet pública**: subnet en public route table + IGW **NO garantiza** IP pública. Requiere `map_public_ip_on_launch = true` en la subnet **o** `associate_public_ip_address = true` en la instancia. Verificado: `public_1a` tiene `map_public_ip_on_launch = false` explícito en HCL, y el EC2 nuevo `i-0d757274b5a24ace7` está `running` sin IP pública. **Refutación empírica** de la predicción de Bloque 3 Punto 3.2 sobre "el nuevo EC2 recibirá IP pública nueva cuando arranque". Regla candidata **#S12Ñ-2**. Anotación adicional: el diseño intencional sin IP pública sugiere acceso vía SSM Session Manager (coherente con `amazon-ssm-agent` observado en console output del EC2 viejo), pero no está documentado en ADR — candidata de deuda técnica para sesión futura.
- **Hallazgo A17 — `kms_key_id` default sin declararlo**: el plan mostró `+ kms_key_id = (known after apply)` sin haber declarado el atributo en HCL. Post-apply verificado en `describe-volumes` que el volumen nuevo `vol-013ad60da26b47031` tiene `KmsKeyId = arn:aws:kms:eu-west-1:750392809244:key/0e86512f-b3e0-4f75-be9a-850a113ff19d` — la AWS-managed `aws/ebs` asignada automáticamente. Takeaway: declarar `encrypted = true` sin `kms_key_id` no deja el volumen sin key — AWS resuelve la default automáticamente, y Terraform captura el ARN en el state.
- **Hallazgo A17 — bloques stub en destroy+create**: en un `-/+` Terraform imprime bloques normalmente ocultos (`capacity_reservation_specification`, `cpu_options`, `credit_specification`, `enclave_options`, `maintenance_options`, `primary_network_interface`, `private_dns_name_options`) porque los muestra "yéndose" del recurso viejo. En un `~` (change in-place) estos permanecen ocultos. Anotable como interpretación del output del plan.
- **Numeración de ADRs — clarificación empírica**: confirmado con `grep` sobre `decisions/*.md` que **ningún ADR referencia códigos Axx internos de candidato**. La numeración de ADRs es **cronológica secuencial** (siguiente número libre en el orden de cierre), NO por código de candidato. Los códigos Axx viven solo en tracking interno de sesiones y prompts de continuación, no en los ADRs formales. Precedente: ADR-022 cerró candidato A16, no fue ADR-016. Alumno tenía intuición contraria que fue corregida.

## Aterrizajes / aplicaciones acumuladas

- **Triple confirmación pre-apply extendida (⭐⭐⭐ #31 aplicada al apply)**: 7ª aplicación consecutiva sin refutación (1 en esta sesión, acumulando desde S12-L).
- **Triple confirmación pre-push (⭐⭐⭐ #31)**: 16ª aplicación consecutiva sin refutación.
- **Redacción bilingüe correcta al primer intento (S12-H)**: 8ª sesión consecutiva sin `amend`. Objetivo S12-Ñ cumplido.
- **Locked ⭐⭐⭐ #S12I-2 (recordar plan de bloques ANTES del warmup)**: aplicada al arranque de S12-Ñ tras su promoción formal en S12-N. Primera aplicación como regla locked.
- **Verificación conjunta línea por línea del HCL antes de `validate`** (⭐⭐⭐ #S12F-10): aplicada al `git diff ec2.tf` post-refactor.
- **Verificación conjunta línea por línea del `plan`** (⭐⭐⭐ #S12F-10 extendida al plan): aplicada al output de `terraform plan`, contrastado punto por punto contra predicción escrita en 7 dimensiones.
- **Redacción de ADR antes de tocar HCL** (excepción pactada por complejidad del cambio): aplicada por primera vez en el módulo. Pendiente evaluación en próxima sesión de si compensa reintroducirla como práctica opcional para cambios destroy+create sobre recursos complejos.
- **Snapshot preventivo antes del apply**: nueva práctica S12-Ñ. Coste ~5 céntimos/mes por 8 GiB. Candidata a formalizar como regla para destroy+create de recursos con potencial contenido de usuario.

## Autocorrecciones (honestidad)

- **Predicción warmup B refutada**: anticipé "2-5 min esperado ~3 min" para el apply, real fue ~24s. Reajuste mental para futuros EC2 pequeños: decenas de segundos, no minutos.
- **Predicción Bloque 3 Punto 3.2 refutada**: anticipé "el EC2 nuevo recibirá IP pública nueva cuando arranque tras el create". Real: no la recibe por diseño de subnet (`map_public_ip_on_launch = false`). El EC2 viejo tampoco la tenía running, mi interpretación previa de "es porque está stopped" era incorrecta.
- **Frase Consequences original del ADR-025 sobre AMI data source**: asumí `data "aws_ami"` con `most_recent = true`. Real: AMI hardcoded `ami-04df7d76c1b804451`. Retocado antes del commit.
- **Frase Consequences original sobre public IP**: asumí IP pública automática. Retocada tras hallazgo empírico.
- **Path errors del profesor**: en dos ocasiones pasé paths absolutos desde raíz del repo (`infra/decisions/*.md`, `infra/rds.tf infra/ec2.tf`) al alumno que estaba en `infra/`. Ambos fallaron. Patrón recurrente a corregir por parte del profesor.

## Estado al cierre

- **Serial**: 44.
- **34 recursos gestionados** (mismo conteo que S12-N: A17 sustituyó EC2 sin añadir/quitar recursos, solo replacement in-place).
- **9 ADRs cerrados** en total: ADR-013, ADR-014, ADR-015, ADR-019, ADR-021, ADR-022, ADR-023, ADR-024, **ADR-025**.
- **Commit final**: `b8a40d9 feat(infra): enable encryption on ec2 root ebs volume per ADR-025`.
- **RDS**: sigue `stopped` desde S12-N. No tocada en toda la sesión. Deadline auto-arranque aproximado ~24 sep (6 días de margen desde cierre S12-Ñ).
- **EC2 nuevo**: instance ID `i-0d757274b5a24ace7`, root volume `vol-013ad60da26b47031` con `Encrypted: True` y KMS key `aws/ebs`. Estado `running`. Sin IP pública (por diseño de subnet).
- **Snapshot preventivo** `snap-05adfec989a3bb3ec` sobre volumen viejo `vol-0a213f4a54ca358e8` — en la cuenta hasta borrado manual (candidato a cleanup en sesión futura, ~5 céntimos/mes).
- **Candidatos ADR pendientes**: 
  - **Fix IP del SG** (sin numerar, diferido a próxima sesión desde Nestares con IP casa estable).
  - **Candidata Axx post-A17** (nueva, sin numerar): EC2 en subnet "pública" sin IP pública asignada. Probable diseño SSM Session Manager (coherente con `amazon-ssm-agent` en console output). Falta ADR que documente racional. Verificar si `iam_instance_profile` ya tiene `AmazonSSMManagedInstanceCore`.

## Nota para la próxima sesión

**Módulo AWS técnicamente cerrado** salvo el fix IP del SG y la candidata Axx post-A17 (documentar diseño sin IP pública). Ambas se abordarán desde Nestares en próxima sesión (S12-O), esperada sábado 19 o domingo 20 sep. Fix IP del SG requiere estar conectado desde IP casa estable (`88.11.x.x` con posible rotación /16 del ISP respecto al último `88.11.252.248` visto en S12-L). La candidata Axx post-A17 puede abordarse en la misma sesión o en una posterior. Con esas dos cerradas, el módulo AWS queda listo para transición a certificaciones (SAA + DVA en orden estratégico, con AIF-C01 en paralelo si ya está avanzada). Estado emocional al cierre estable, sesión densa pero sin señales S12-C ("me explota la cabeza") — un uso de "muchas cosas seguidas" recogido y respondido con recorte de scope en Bloque 3. Aplicación 7ª de triple confirmación pre-apply y 16ª de pre-push consecutivas sin refutación, ambas confirmadas como reglas plenamente locked.
