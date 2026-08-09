# ADR-A5 — Persistencia relacional: RDS gestionada en lugar de Postgres autoinstalado en EC2

**Fecha:** 8 agosto 2026
**Estado:** Accepted
**Deciders:** Manuel Toledano Delgado (Tole)
**Sesiones relacionadas:** AWS Sesión 3 (creación inicial de RDS `task-manager-db`), Sesión 6 (recreación completa tras `DeleteDBInstance` accidental y consolidación de la decisión con configuración robusta).

## Context

El proyecto `task-manager-api` (Spring Boot 4, Java 21) usa PostgreSQL como base de datos relacional principal para el dominio transaccional (usuarios, tareas, categorías, autenticación). En entorno de desarrollo local corre PostgreSQL en el WSL2 del desarrollador. Al mover el despliegue a AWS con EC2 (`task-manager-ec2`), hay que decidir dónde vive la base de datos productiva.

Este ADR nace en un contexto muy concreto que conviene explicitar: **el proyecto es una plataforma de aprendizaje activo del ecosistema AWS**, orientada a portfolio para búsqueda de empleo en el mercado Java backend español (banca, fintech, consultoras grandes). Uno de los objetivos explícitos del roadmap post-Git/Bash es entender cómo se comunican los servicios gestionados de AWS entre sí en un despliegue realista. Esa motivación pedagógica es parte legítima del contexto de esta decisión, y no se oculta detrás de justificaciones técnicas de eficiencia o coste que no fueron las que realmente pesaron.

Dicho esto, la decisión debe ser también técnicamente defendible en una entrevista o revisión arquitectónica formal, no solo justificable por "quería aprenderlo". Por eso el análisis siguiente evalúa la elección desde ambos ángulos.

Se consideraron dos alternativas realistas:

1. **PostgreSQL autoinstalado directamente en la EC2** (`apt install postgresql-18` en `task-manager-ec2`). El proceso `postgres` corre como servicio systemd en la misma instancia que la aplicación; los datos viven en el disco EBS de la EC2 (o en un volumen EBS adicional montado). La aplicación conecta vía `localhost:5432`.

2. **Amazon RDS gestionada** con motor PostgreSQL. Una instancia RDS separada (`task-manager-db`) corre en una subnet privada de la VPC; AWS gestiona el ciclo de vida: patching menor automático, backups automatizados con retención configurable, snapshots manuales, restore point-in-time dentro del período de retención, deletion protection opcional, opcional Multi-AZ para alta disponibilidad. La aplicación conecta vía el endpoint DNS de la instancia (`task-manager-db.clcuwqagmsx3.eu-west-1.rds.amazonaws.com:5432`).

Se descartaron dos alternativas más de forma temprana, sin evaluación profunda:

- **Aurora Serverless v2 con motor PostgreSQL-compatible**. Escala capacidad computacional automáticamente y factura por ACU consumidos. Descartada por coste base: incluso en reposo, Aurora Serverless v2 factura un mínimo del orden de ~$45/mes en las configuraciones típicas, muy por encima del presupuesto autoimpuesto de menos de 5€/mes para el módulo AWS del roadmap.
- **Sustituir Postgres por MongoDB Atlas para todo** (colapsar toda la persistencia en la BD documental que ya usa el proyecto para el activity log). Descartada porque el modelo de dominio transaccional (relaciones entre usuarios, tareas y categorías con integridad referencial, transacciones ACID) se expresa naturalmente en un modelo relacional; forzarlo a documentos generaría fricción de modelado sin beneficio. Además, el objetivo pedagógico del proyecto es precisamente demostrar polyglot persistence en un mismo servicio.

Los criterios que pesaron en la decisión, ordenados por relevancia real (no ideal):

1. **Valor pedagógico y de portfolio.** Aprender el patrón que las empresas del mercado objetivo (banca, fintech, consultoras) esperan como estándar. En ese sector, RDS gestionada es baseline: Postgres autoinstalado en EC2 es antipatrón salvo excepciones muy específicas.
2. **Resiliencia operativa.** Backups automáticos, restore point-in-time, deletion protection y patching gestionado sin intervención manual del desarrollador.
3. **Superficie de administración mínima.** Sin `apt`, sin `postgresql.conf`, sin `pg_hba.conf`, sin scripts de backup a cron, sin gestión de espacio de disco a mano.
4. **Coste.** RDS `db.t4g.micro` con 20 GB de storage entra dentro del Free Tier / créditos AWS iniciales del proyecto. Diferencia marginal frente a Postgres en la EC2 en este dimensionamiento; deja de ser diferenciador.

## Decision

Usaremos **Amazon RDS gestionada** con motor PostgreSQL 18.3 sobre `db.t4g.micro` (ARM Graviton), configuración single-AZ, 20 GB gp3, backup retention de 7 días, deletion protection habilitada, y encryption at rest con la clave KMS `aws/rds`. La instancia (`task-manager-db`) vive en una DB Subnet Group con dos subnets privadas (`eu-west-1a` + `eu-west-1b`), con Public Access deshabilitado y un Security Group (`task-manager-db-sg`) que solo acepta tráfico entrante en el puerto 5432 desde el Security Group de la capa de aplicación (`task-manager-ec2-sg`) — modelo referenciado, no CIDRs.

La aplicación conecta con un usuario aplicativo (`task_manager_app`) distinto del master user (`postgres`), con permisos mínimos sobre el schema `public` de la base de datos lógica `task_manager`. Las credenciales viven en variables de entorno en la EC2 (`DB_URL`, `DB_USERNAME`, `DB_PASSWORD`), leídas desde `~/.secrets` mediante `set -a; source ~/.secrets; set +a` antes de arrancar la aplicación.

## Consequences

### Positivas

- **Backups automatizados con retención configurable de 7 días.** Sin intervención humana, sin script de `pg_dump` a cron. Restore point-in-time dentro de la ventana de retención con granularidad de 5 minutos. Consolidado empíricamente en Sesión 6 tras el incidente de `DeleteDBInstance` accidental de la Sesión 3.
- **Deletion protection como fricción intencional al borrado destructivo.** Un `Delete DB instance` desde consola requiere desactivar primero el flag; los botones `Stop` y `Delete` están adyacentes en el menú Actions de RDS y el error de clic es real (documentado en el diario de Sesión 6). Deletion protection convierte un accidente reversible en un accidente que requiere dos pasos conscientes.
- **Patching menor automatizado.** Actualizaciones de la rama menor de PostgreSQL (18.3 → 18.4 → ...) se aplican en la ventana de mantenimiento configurada, sin intervención. Actualizaciones mayores requieren aprobación explícita.
- **Separación clara de responsabilidades entre capa de aplicación y capa de datos.** La instancia EC2 puede ser reemplazada, escalada o replicada horizontalmente sin tocar la base de datos. La base de datos puede ser respaldada, restaurada o migrada sin tocar la aplicación. Cada capa evoluciona independientemente.
- **Modelo de seguridad de red profesional documentado en Sesión 6.** El Security Group de RDS acepta 5432 solo desde el Security Group de la capa de aplicación (modelo referenciado). La regla persiste correctamente aunque cambien instancias, IPs o se escale horizontalmente. Es el patrón esperado en cualquier revisión arquitectónica AWS seria.
- **Encryption at rest sin coste adicional** usando la clave KMS `aws/rds` por defecto. Requisito estándar en auditorías de banking/fintech.
- **Alineamiento con el mercado objetivo.** En una entrevista técnica en banca o consultora grande, "usamos Postgres en la EC2 con backups manuales" es una respuesta que requiere justificar; "usamos RDS gestionada con Multi-AZ" es la respuesta baseline esperada.
- **Recuperación del incidente de Sesión 3 fue trivial.** Al descubrir vía CloudTrail que la instancia había sido borrada 5 días antes, la recreación completa consistió en: wizard de la consola con parámetros equivalentes, reaplicación automática de las 8 migraciones Flyway al arrancar la aplicación, y recreación manual del usuario aplicativo con sus GRANTs. Total ~40 minutos. Con Postgres autoinstalado en una EC2 destruida, la recuperación habría requerido lanzar EC2 nueva, instalar el paquete, editar `postgresql.conf` y `pg_hba.conf`, restaurar de un `pg_dump` (si existía), y depurar diferencias de configuración entre instancias — proceso significativamente más frágil y más lento.

### Negativas

- **Coste base no nulo aunque la aplicación no reciba tráfico.** RDS factura por hora de instancia y por GB de storage aunque la instancia esté ociosa. Con `db.t4g.micro` + 20 GB dentro de los créditos AWS del proyecto, el coste corriente es cero, pero al agotar créditos habrá coste base incluso sin uso. Con Postgres en la propia EC2, si la EC2 está parada, no hay coste ni de compute ni de storage adicional.
- **Vendor lock-in de configuración.** Los parámetros específicos de RDS (parameter groups, option groups, opciones de red RDS Proxy si se añadiese) no son portables a Postgres estándar en otro entorno. Una hipotética migración a Kubernetes con un `postgres` operator o a un proveedor cloud alternativo requeriría reconstruir esa configuración.
- **Latencia de red entre app y BD** frente a `localhost`. Con la EC2 y la RDS en la misma región y AZ (`eu-west-1a`), la latencia intra-AZ es del orden de sub-milisegundo, imperceptible en la práctica; se documenta como consecuencia teórica no como problema real.
- **Superficie de configuración específica de RDS que hay que conocer.** Parameter Groups, Option Groups, DB Subnet Groups, Reserved Instances, Multi-AZ, Read Replicas, snapshots manuales vs automatizados, Performance Insights, Enhanced Monitoring... El desarrollador tiene que aprender vocabulario y mecánica específicos de AWS RDS que no aplican a un Postgres estándar. Trade-off aceptado dado el objetivo pedagógico explícito del proyecto.
- **Dependencia de la disponibilidad regional de AWS.** Un fallo de RDS en `eu-west-1` afecta al proyecto. Mitigable con Multi-AZ (deshabilitada actualmente por coste) o Cross-Region Read Replicas (fuera de scope). Con Postgres en la propia EC2, el fallo sería del mismo tipo (una instancia EC2 en una AZ), no mejor.
- **La motivación principal fue pedagógica.** Este ADR se firma sabiendo que la razón real del proyecto fue "aprender AWS", no un análisis coste-beneficio riguroso frente a alternativas. En un proyecto empresarial real la decisión requeriría añadir análisis de TCO a 3 años, requisitos de compliance concretos (PCI DSS, SOC 2, ISO 27001) y necesidades de HA/DR explícitas. Se documenta honestamente para que el ADR sirva de instrumento formativo real y no de racionalización.

### Neutrales

- **La app usa el mismo cliente JDBC estándar** (`org.postgresql:postgresql`) sin cambios frente a un Postgres estándar. Si en el futuro se migra fuera de RDS, el código de acceso a datos no cambia; solo cambia la URL de conexión.
- **Flyway funciona igual contra RDS que contra Postgres local.** Las 8 migraciones V1-V8 se aplican sin modificación. Verificado empíricamente en Sesiones 3 y 6.
- **RDS es un servicio de AWS gestionado, no una tecnología de base de datos**. La decisión aquí no es "PostgreSQL vs otro motor" sino "cómo desplegamos PostgreSQL". Si el criterio "aprender AWS" cambiase, la decisión "PostgreSQL como motor" no requeriría revisión.

## Related decisions

- **ADR-A1 (Accepted, 2026-08-02)** — VPC custom con separación explícita entre subnets públicas y privadas. Precondición de red que permite ubicar RDS en subnets privadas sin exposición a internet.
- **ADR-A4 (Accepted, 2026-08-08)** — Credenciales AWS con Instance Profile y SDK v2. Cierra la coherencia arquitectónica del proyecto en el acceso a servicios AWS.

## References

- AWS documentation: [Amazon RDS User Guide — Backup and restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_CommonTasks.BackupRestore.html)
- AWS Well-Architected Framework — Reliability Pillar, section "Backup data".
- PostgreSQL documentation: [PostgreSQL on Amazon RDS versions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- Diarios internos: `bitacora/Sesion3-AWS-Diario.md`, `bitacora/Sesion6-AWS-Diario.md`.
