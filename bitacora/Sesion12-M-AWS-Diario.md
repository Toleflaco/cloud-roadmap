# Bitácora S12-M — AWS Roadmap

**Fecha**: miércoles 16 sep 2026, tarde (16:30–~18:15 aprox, ~2h)
**Sitio**: WSL2, casa
**Hueco desde S12-L**: mismo día, S12-L cerró ~09:00
**Estado emocional al arrancar**: bajo (tema trabajo/dinero)
**Tipo de sesión**: corta, un solo ADR, ritmo recortado por cansancio acumulado del día

## Resumen

Primera sesión post-milestone. Se priorizó un único ADR (A21, VPC Endpoint S3 policy) en lugar de los 2-4 planteados en el prompt de continuación, por tiempo y estado disponibles. Se descartó tocar RDS (A18, A20) para evitar coste operativo y variables adicionales en una sesión corta.

## Trabajo realizado

- **ADR-021** creado y cerrado: policy del VPC Endpoint S3 restringida de `Principal/Action/Resource = "*"` (full access default) a policy scoped al rol `task-manager-ec2-role`, acciones `ListAllMyBuckets`, `ListBucket`, `PutObject`, `GetObject`, sobre el bucket `toleflaco-task-manager-uploads-2026` y sus objetos.
- Ciclo pactado completo aplicado: predicción escrita antes del `plan` (correcta en `change` in-place, recurso, atributo `policy`) → verificación línea por línea del plan → triple confirmación pre-apply → `apply` limpio (0 added, 1 changed, 0 destroyed) → verificación post-apply en 3 dimensiones (plan `No changes`, serial 37→38, consola AWS).
- Commit único agrupando `main.tf` + ADR-021. Mensaje bilingüe correcto al primer intento. Triple confirmación pre-push. Push limpio: `e938f9a..e1aa287`.

## Aprendizajes empíricos

- **Concepto `Sid`** introducido explícitamente por primera vez: identificador de statement dentro de una IAM policy, sin efecto funcional, solo organizativo.
- **Dato empírico nuevo**: la policy default "full access" del VPC Endpoint traía `Version = "2008-10-17"` (versión IAM más antigua, no un placeholder). No anticipado en la preparación de la sesión.
- **Predicción de #S12K-2 confirmada de nuevo**: atributo `Optional` sin `ForceNew` en Argument Reference → `change` in-place confirmado empíricamente en el `plan` real. Aplicación consistente con S12-K/S12-L.
- **Aplicación 3ª de la triple confirmación pre-apply** (tras las 2 de S12-L) — extensión de #31 sigue aterrizada sin fricción.
- **Aplicación 12ª consecutiva de #31 en git push** — sin refutación.
- **Aterrizaje S12-H sostenido 6ª sesión consecutiva** — redacción bilingüe correcta al primer intento sin amend.
- **Detectado, no corregido (fuera de scope)**: las reglas de ingress del SG (`ec2_ssh_home`, `ec2_http_home`) siguen apuntando a la IP antigua `88.11.202.24/32`, mientras la IP actual de casa es `88.11.252.248`. `terraform plan` no lo marca (compara contra state, no contra conectividad real). Candidato a ADR o fix rápido en sesión futura — no priorizado hoy.

## Estado al cierre

- **Serial**: 38.
- **34 recursos gestionados** (sin cambio de conteo — A21 fue modificación in-place, no recurso nuevo).
- **5 ADRs cerrados** en total: ADR-013, ADR-014, ADR-015, ADR-019, ADR-021.
- **Commit final**: `e1aa287 feat(infra): restrict s3 vpc endpoint policy per ADR-021`.
- **RDS**: `stopped`, sin tocar. Deadline auto-arranque aproximado sigue en ~20 sep.
- **Candidatos ADR pendientes**: A16 (key pair import), A17 (root volume encryption, diferido a sesión dedicada), A18 (RDS gp2→gp3), A20 (skip_final_snapshot).
- **Nuevo candidato sin numerar**: SG ingress rules con IP de casa desactualizada (detectado en S12-M, no priorizado).

## Nota para la próxima sesión

No se generó prompt de continuación formal en S12-M por decisión explícita (sesión corta). Al retomar, releer esta bitácora + la de S12-L, y repriorizar entre A16/A18/A20 (A17 sigue diferido) más el hallazgo nuevo de la IP del SG.
