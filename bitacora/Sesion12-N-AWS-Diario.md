# Bitácora S12-N — AWS Roadmap

**Fecha**: jueves 17 sep 2026, tarde (13:41–~19:00 aprox, ~5h)
**Sitio**: WSL2, desde Madrid (residencia temporal, no Nestares)
**Hueco desde S12-M**: ~28h (S12-M cerró el miércoles ~18:15)
**Estado emocional al arrancar**: bajo (tema trabajo/dinero)
**Tipo de sesión**: larga, densa, tres ADRs cerrados con imprevistos empíricos genuinos

## Resumen

Segunda sesión post-milestone. Priorización acordada al arranque: fix IP del SG diferido a Nestares (por estar en Madrid, no tenía sentido tocar con IP de tránsito), A17 diferido siempre a sesión dedicada, y foco en A16 + A18 + A20 con A18/A20 aprovechando ventana RDS arrancada compartida. Los tres ADRs cerrados con Camino B consolidado y triple confirmación pre-apply extendida (aplicaciones 4ª, 5ª y 6ª consecutivas tras las 3 de S12-L/S12-M).

## Trabajo realizado

- **ADR-022** cerrado: importar key pair `task-manager-key` como recurso Terraform (`aws_key_pair.task_manager_key`) en `ec2.tf`, sustituyendo string literal en `key_name` del EC2 por referencia semántica al recurso.
- **ADR-023** cerrado: migrar `storage_type` de RDS de `gp2` (default implícito) a `gp3` explícito, dejando `iops` y `storage_throughput` sin declarar (defaults AWS 3000 IOPS / 125 MiB/s).
- **ADR-024** cerrado: habilitar snapshot final en destroy de RDS (`skip_final_snapshot = false` + `final_snapshot_identifier = "task-manager-db-final-snapshot"`).
- Ciclo pactado completo aplicado en los tres: predicción escrita → `plan` → verificación línea por línea → triple confirmación pre-apply → `apply` → verificación post-apply en 3 dimensiones.
- 3 commits limpios pusheados a `origin/main`: `0385c8e`, `9ae08ca`, `dd6e8d6`. Mensajes bilingües correctos al primer intento sin amend (7ª sesión consecutiva).
- RDS parada al terminar (`aws rds stop-db-instance`), coste operativo cortado. Nuevo deadline auto-arranque aproximado ~24 sep.

## Aprendizajes empíricos nuevos

- **Hallazgo A16 (ADR-022)**: importar una `aws_key_pair` existente y declarar su `public_key` en HCL **fuerza destroy + create replacement**, no cambio in-place. Causa: la API de AWS **nunca** devuelve el material público de una key pair ya existente (`describe-key-pairs` no lo incluye), por lo que el `import` deja `public_key` vacío en el state, y declararlo lo interpreta como valor nuevo que fuerza recreación. Solución empírica: recuperar la clave pública localmente del `.pem` con `ssh-keygen -y -f <fichero>.pem`. Verificado post-apply que el EC2 en ejecución mantiene asociación con el key pair name tras la recreación del objeto — sin impacto funcional.
- **Hallazgo A18 (ADR-023)**: `terraform apply` sobre RDS con `apply_immediately = false` (default) puede devolver `Apply complete!` **con éxito aparente sin aplicar el cambio realmente** — solo lo deja aceptado en `PendingModifiedValues`, en cola para la ventana de mantenimiento (`sun:01:39-sun:02:09` UTC). Verificado en la sesión: primer apply devolvió éxito en 1m15s pero `describe-db-instances` seguía mostrando `gp2`; `PendingModifiedValues` mostraba `StorageType: gp3`. Segundo apply con `apply_immediately = true` aplicó de verdad en 2m58s. Takeaway: en RDS, `Apply complete!` no garantiza por sí mismo que el cambio esté vivo — con `apply_immediately = false`, verificar contra `PendingModifiedValues` antes de dar por hecho el cambio.
- **Hallazgo A20 (ADR-024)**: `terraform apply` completó en **0 segundos**, en fuerte contraste con los ~3 minutos de A18 sobre el mismo recurso. Explicación: `storage_type` dispara migración física real del storage subyacente; `skip_final_snapshot` y `final_snapshot_identifier` solo alteran metadata que gobierna comportamiento futuro de destroy, sin trabajo inmediato en AWS. Takeaway: la duración del apply en RDS refleja la operación física involucrada, no el hecho de modificar el recurso.
- **Distinción `deletion_protection` vs `skip_final_snapshot`**: son dos capas de protección independientes y complementarias. `deletion_protection = true` bloquea el destroy en sí mismo; `skip_final_snapshot = false` protege los datos si el destroy sí llega a ocurrir. Aterrizado conceptualmente en la discusión previa a ADR-024.
- **Distinción `+` vs `~` en el diff del plan**: no depende de si el argumento "es nuevo en el HCL", depende de si el state ya tenía o no un valor previo registrado. Ejemplo empírico: `apply_immediately` apareció como `+ true` la primera vez y como `~ false -> true` la segunda (después de que el primer apply ya hubiera fijado `false` en el state).
- **`.id` de `aws_key_pair` NO es opaco**: excepción al patrón general de recursos AWS. La Attribute Reference declara literalmente `id - The key pair name`. Coincide con `.key_name`. Aun así, `.key_name` es semánticamente correcto para la referencia (matización S12-K de #S12H-8 sigue guiando: usar el atributo semánticamente correcto, no el `.id` como comodín aunque funcione).
- **Diferencia terminológica respecto al prompt de continuación de S12-L**: el atributo real del provider es `storage_throughput`, no `throughput` como se anticipaba en la preparación.

## Aterrizajes / aplicaciones acumuladas

- **Triple confirmación pre-apply extendida (⭐⭐⭐ #31 aplicada al apply)**: aplicaciones 4ª, 5ª (con A18-segundo intento) y 6ª de A20, 3 más en esta sesión. Total acumulado post-S12-L: 6 aplicaciones consecutivas sin refutación.
- **Triple confirmación pre-push (⭐⭐⭐ #31)**: 3 aplicaciones más (13ª, 14ª, 15ª consecutivas).
- **Redacción bilingüe correcta al primer intento (S12-H)**: 7ª sesión consecutiva sin `amend`.
- **Candidata #S12I-2 (recordar plan de bloques ANTES del warmup)**: aplicada 3 veces en esta sesión (al inicio, al recolocar tras dejar IP del SG diferida, y al arrancar A18). Total acumulado post-S12-L: superadas ampliamente las 6 aplicaciones consecutivas. **Promoción a locked ⭐⭐⭐ formalizada en esta sesión.**
- **Candidata #S12K-2 (Argument Reference vs schema real, gana el plan)**: aplicada en A18 (predicción correcta de que `iops`/`storage_throughput` no aparecen en diff si no se declaran) y refutada parcialmente en A16 (`public_key` sí requerido pese a no mencionar `ForceNew` en la Argument Reference — hallazgo empírico). Regla sigue en pie con matización nueva: verificar el schema real siempre, no asumir por descarte.
- **Regla candidata #S12K-3 (`skip_final_snapshot` verificable)**: aplicación empírica confirmada en A20. Cambio in-place, sin recreación, sin operación física. Coherente con la hipótesis original.

## Estado al cierre

- **Serial**: 43.
- **34 recursos gestionados** (34 tras A16: import del key pair añadió 1 recurso al state pero no cambió el número de recursos gestionados de infraestructura porque A16 estaba ya "existente" — verificar conteo exacto con `terraform state list | wc -l` al arrancar mañana si hace falta).
- **8 ADRs cerrados** en total: ADR-013, ADR-014, ADR-015, ADR-019, ADR-021, ADR-022, ADR-023, ADR-024.
- **Commit final**: `dd6e8d6 feat(infra): enable rds final snapshot on deletion per ADR-024`.
- **RDS**: `stopping` al cerrar. Deadline auto-arranque aproximado ~24 sep.
- **Candidatos ADR pendientes**: **A17** (root volume encryption, diferido a sesión dedicada — objetivo S12-Ñ mañana), **fix IP del SG** (sin numerar aún, diferido a próxima sesión desde Nestares).

## Nota para la próxima sesión

Sesión S12-Ñ ya pactada para **mañana viernes 18 sep por la mañana**: sesión dedicada a **A17** (root volume encryption del EC2). A17 es la única deuda técnica que requiere sesión propia con procedimiento pactado en frío previamente — implica `destroy + create replacement` del EBS root, con procedimiento snapshot manual → recreación → detach → attach. **NO abordar sin pactar procedimiento explícito en frío al arrancar mañana.** El prompt de continuación de esta sesión cubre el arranque de S12-Ñ centrado en A17.
