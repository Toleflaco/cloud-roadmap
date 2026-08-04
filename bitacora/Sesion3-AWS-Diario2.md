# Sesión 3 — AWS: EC2 + RDS PostgreSQL + Security Groups referenciados

**Fecha:** 3 ago 2026
**Duración total:** ~2.5h partidas en dos partes (parte 1 conceptual por la tarde, parte 2 ejecución por la noche)
**Estado:** COMPLETADA. Arquitectura EC2 pública → RDS privada con SG referenciado funcionando, migraciones Flyway aplicadas.

---

## Contexto de la sesión

Planificada como sesión única de EC2 + RDS + SG referenciado + Flyway. En la tarde, tras ~4h de estudio acumulado entre otro roadmap y este, se partió honestamente al llegar al paso Key pair — el bloque conceptual gordo (Security Groups referenciados) requería cabeza fresca. Reanudada por la noche con energía restablecida, se completó de un tirón: EC2 lanzada, RDS creada, SG referenciado configurado, migraciones aplicadas, verificación empírica en la BD.

Ningún fallo bloqueante en el camino. Sí varios matices operativos que se documentan como lecciones.

---

## Conceptos consolidados

### EC2 — anatomía del acceso SSH en 4 capas

Cadena que atraviesa un `ssh -i clave.pem ubuntu@<ip>` desde WSL hasta obtener prompt:

1. **Internet Gateway (IGW):** puerta de entrada de la VPC desde internet.
2. **Route Table:** dirige el paquete a la subnet correcta. Regla `0.0.0.0/0 → igw` en subnets públicas permite tanto entrada como retorno.
3. **Security Group:** firewall pegado a la interfaz. Verifica `TCP:22 desde <IP>/32`.
4. **cloud-init + sshd:** cloud-init consultó al arranque el Instance Metadata Service (`http://169.254.169.254`) y depositó la clave pública en `/home/ubuntu/.ssh/authorized_keys`. `sshd` autentica contra ella.

Este mapa mental es la herramienta primaria para depurar cualquier fallo de conexión: recorrer las 4 capas y aislar dónde se rompe.

### Security Groups — CIDR vs referenciado

Toda regla inbound = protocolo + puerto + source. El source puede ser:

- **CIDR:** una IP o rango (`0.0.0.0/0` = internet entero, `<mi-ip>/32` = solo mi máquina).
- **Otro Security Group:** "cualquier recurso con este SG puesto".

**El patrón referenciado es el punto pedagógico central del día.** Comparación:

| | SG por CIDR | SG referenciado |
|---|---|---|
| Regla | `Source: 10.0.4.74/32` | `Source: sg-task-manager-ec2-sg` |
| Escalado | Editar regla por cada EC2 nueva | Cero cambios, basta ponerle el SG a la nueva |
| IP privada cambia | Regla obsoleta | Sigue funcionando |
| Expresa | Coordenada física | Identidad lógica |

**Frase ⭐⭐⭐ para entrevistas:** *"El SG de la BD acepta puerto 5432 solo desde el SG del backend, no por CIDR, para desacoplar identidad de topología de red y sobrevivir a cambios de IP y escalado horizontal."*

### CPU burstable — familia t

- Baseline: `t3.micro` = 20% de una vCPU sostenido.
- Bajo baseline → acumula créditos. Sobre baseline → gasta créditos, corre al 100%.
- Créditos agotados → dos modos:
  - **Standard** (t2 default): throttle a baseline, sin cobros extra.
  - **Unlimited** (t3 default): sigue a 100%, cobra por hora de over-usage. Vive en Advanced Details → Credit specification.

**Encaje:** perfecto para picos cortos + valles (Spring Boot arrancando, dev/staging, batches). Mal para carga sostenida a CPU alta (200 req/s constantes → familias `c` o `m`).

### Coste EC2 vs RDS 24/7 fuera de free tier

| Recurso | Total mensual estimado |
|---|---|
| EC2 t3.micro + 8GB EBS + IP pública | ~$12.60 |
| RDS db.t4g.micro + 20GB storage + backups | ~$17-18 |

**Por qué RDS es más caro** — patrón general de servicios gestionados AWS:

1. Pagas la operación gestionada: parches automáticos, backups, snapshots, Multi-AZ failover, métricas.
2. Storage RDS gp3 más caro que EBS gp3 ($0.115 vs $0.08 por GB).
3. **RDS parada se reinicia sola a los 7 días** — no la puedes dejar parada indefinidamente. EC2 sí. Para "no gastar entre sesiones": EC2 stop, RDS destroy + snapshot final si quieres conservar.

Patrón general: servicio gestionado ~30-50% más caro que autogestionado en EC2, a cambio de quitarte trabajo operativo. Aplica también a MSK (Kafka), ElastiCache (Redis), ALB (nginx), EKS (K8s).

**Ventajas de RDS para entrevistas de banca/consultorías:**
- Multi-AZ failover automático en 60-120s vs restore manual de backup a las 3 AM.
- Auto minor version upgrade para CVEs vs ventana de mantenimiento planificada.
- Evidencia de cumplimiento (PCI-DSS, ISO 27001, ENS) preconstruida — auditorías más rápidas.

### DB Subnet Group

RDS exige subnets en al menos **2 AZs distintas** aunque sea single-AZ. Motivo: preserva la opción de activar Multi-AZ failover sin recrear infraestructura. Regla dura: **bases de datos SIEMPRE en subnets privadas, sin IP pública, sin excepciones**.

### Key pairs

- Formato para clientes OpenSSH: `.pem`. `.ppk` es para PuTTY.
- Algoritmo: **ED25519** preferido (moderno, corto, rápido). RSA sigue por compatibilidad.
- Manipulación tras descarga: `mv` de Windows Downloads a `~/.ssh/`, `chmod 600`. Downloads sincroniza a nube y es objetivo de malware.
- **Backup en Bitwarden**. Perder el `.pem` sin backup = sin acceso a la EC2 con ese key pair (recuperación posible con Session Manager, Instance Connect, o reasignación de EBS, pero requiere prevención antes).

### IOPS

Input/Output Operations Per Second. Techo de operaciones lectura/escritura al disco por segundo. Referencia mental:

- HDD mecánico: ~100-150 IOPS.
- gp2 20 GB: 60 IOPS baseline (obsoleto).
- **gp3 base: 3.000 IOPS sin importar tamaño**.
- io2 (crítico producción): hasta 256.000 IOPS.

**Regla 2026:** gp3 siempre. No hay motivo para gp2. Diagnóstico útil: si la app va lenta y CPU + RAM libres, sospechoso #1 es techo de IOPS del disco.

---

## Lecciones operativas (matices descubiertos por el camino)

### AWS Free Plan (nuevo modelo, jul 2025) ≠ 12 meses free tier clásico

Cuenta `ManuFlaco` creada tras 15 jul 2025 = está en el nuevo Free Plan, no en el clásico:

- $100 en créditos al registro + hasta $100 más completando 5 actividades ($20 c/u): launch+terminate EC2, configurar RDS, deploy Lambda, probar Bedrock, budget alert.
- **Duración: 6 meses desde apertura O hasta agotar créditos**, lo que ocurra primero. Al expirar, 90 días para pasar a Paid Plan antes de que AWS cierre la cuenta y borre todo.
- Deadline concreto en esta cuenta: **1 feb 2027** (182 días desde creación).
- El badge "Free tier eligible" en instance types sigue existiendo pero significa "elegible para pagar con créditos", no "gratis por horas". Cada hora consume créditos.

**Consecuencia operativa:** la disciplina de apagar recursos al terminar cada sesión pasa de "buena práctica" a "condición para llegar al final del roadmap AWS + K8s con la misma cuenta". Corriendo solo 2-3h por sesión y destruyendo RDS al cerrar, $100 duran cómodamente.

### Prefijos reservados en nombres

Intento de crear SG con nombre `sg-task-manager-ec2` → rechazado con error:

> `Value (sg-task-manager-ec2) for parameter GroupName is invalid. Group names may not be in the format sg-*.`

AWS reserva prefijos para IDs generados por él: `sg-`, `ami-`, `vpc-`, `subnet-`, `i-`, `vol-`, etc. Convención personal aplicada: **sufijo `-sg`** (`task-manager-ec2-sg`, `task-manager-db-sg`) — deja claro que es SG cuando aparece en listados mezclado.

### La trampa del "Public access" en RDS

Al crear la RDS desde el formulario, AWS **automáticamente** metió una regla inbound en el SG referente a la IP pública actual del navegador (`95.121.136.184/32`). Es AWS "ayudando" al caso de uso principiante: conectar desde el portátil con DBeaver/psql local.

Es exactamente lo contrario del patrón profesional. La regla se eliminó y se sustituyó por el SG referenciado desde `task-manager-ec2-sg`. Confirmado que `Internet access gateway: Disabled` (renombrado de "Publicly accessible: No") — la RDS no tiene IP pública, la regla del CIDR era además sin efecto real. Aun así se elimina porque ensucia y enseña mal hábito.

**Regla:** después de crear una RDS, revisar el SG y confirmar que la única regla inbound es referencia al SG del backend. Cero CIDRs.

### PostgreSQL 18 en RDS

RDS ofrece PostgreSQL 18.3 hoy (day-1 GA). El monolito `task-manager-api` en local usa PostgreSQL 16. Las migraciones Flyway aplicaron sin problema — DDLs estándar son compatibles 16→18. En producción real, alinear versión local ↔ RDS reduce sorpresas.

Confirmado desde output: `PostgreSQL 18.3 on aarch64-unknown-linux-gnu` → RDS corre sobre ARM (Graviton) porque elegimos `db.t4g.micro`. Para el cliente da igual: el protocolo PostgreSQL sobre TCP es indistinto de arquitectura. **Regla:** para RDS gestionada, ARM (Graviton) es gratis en decisión — no hay superficie donde te penalice. Aprovechar siempre.

### Conflicto de versiones Flyway 10 vs 11 en el plugin Maven

Al añadir `flyway-maven-plugin:10.20.1` con Spring Boot 4.0.6 en el pom, ClassLoader mezcla dos versiones de `flyway-core`:

- Plugin trae 10.20.1.
- Spring Boot 4.0.6 arrastra transitivamente 11.14.1.

Error: `IncompatibleClassChangeError: class org.flywaydb.core.internal.NullFlywayTelemetryManager can not implement org.flywaydb.core.FlywayTelemetryManager, because it is not an interface`. En Flyway 11 esa clase pasó de interface a class.

**Fix:** alinear el plugin y su dependencia `flyway-database-postgresql` a la versión que ya trae Spring Boot (11.14.1). Regla general: cuando se añade un plugin Maven de una librería que Spring Boot ya gestiona, comprobar la versión con `mvn dependency:tree | grep <lib>` y alinear.

### El truco del prompt EC2 con IP privada

El prompt de la EC2 es `ubuntu@ip-10-0-4-74`. La IP `10.0.4.74` es la **privada** interna (encaja en subnet pública `10.0.0.0/20`). La pública era `108.131.104.90` — es la "cara externa" que el IGW pone para conversar con internet. Detalle que confunde al principio: la máquina se ve a sí misma con IP privada.

### El wizard EC2 no persiste borradores

Al cerrar/cancelar el wizard "Launch instance", nada se guarda. Al retomar hay que rellenar los ~4 primeros campos de nuevo. Compensa hacer la sesión de un tirón cuando se abre el wizard, o cancelar consciente sabiendo que hay que rehacer. El key pair sí persiste (es recurso separado), solo hay que seleccionarlo del desplegable en la nueva pasada.

---

## Recursos AWS creados

| Recurso | Nombre / ID | Config clave |
|---|---|---|
| Key pair | `task-manager-key` | ED25519, .pem, en `~/.ssh/` con 600 |
| EC2 | `task-manager-ec2` | Ubuntu 24.04 LTS x86_64, t3.micro, subnet pública eu-west-1a, IP pública auto |
| Security Group EC2 | `task-manager-ec2-sg` | Inbound: SSH TCP:22 desde `<mi-ip>/32` |
| DB Subnet Group | `task-manager-db-subnet-group` | Subnets privadas eu-west-1a + eu-west-1b |
| RDS | `task-manager-db` | PostgreSQL 18.3, db.t4g.micro (Graviton), 20 GiB gp3, single-AZ, autoscaling OFF, backup retention 1 día, encryption default, deletion protection OFF |
| Security Group RDS | `task-manager-db-sg` | Inbound: PostgreSQL TCP:5432 desde `task-manager-ec2-sg` (SG referenciado) |
| Endpoint RDS | `task-manager-db.clcuwqagmsx3.eu-west-1.rds.amazonaws.com` | Puerto 5432, dbname `taskmanager`, user `postgres` |

**VPC subyacente:** `task-manager-vpc` (`vpc-0d36eccf71cddeda7`), creada en Sesión 2. Detectado en Sesión 3 typo del nombre original (`task-manage-vpc` sin la `-r`). Renombrado el tag Name — el VPC ID no cambia, no rompe nada.

---

## Verificación empírica (evidencia auditoríable)

Ejecutado desde EC2 tras `flyway:migrate`:

```
$ psql -h $RDSHOST -U postgres -d taskmanager -c "\dt"
                 List of relations
 Schema |         Name          | Type  |  Owner
--------+-----------------------+-------+----------
 public | categories            | table | postgres
 public | flyway_schema_history | table | postgres
 public | refresh_tokens        | table | postgres
 public | tasks                 | table | postgres
 public | users                 | table | postgres
(5 rows)

$ psql -h $RDSHOST -U postgres -d taskmanager -c "SELECT version, description, installed_on FROM flyway_schema_history ORDER BY installed_rank;"
 version |                      description                      |        installed_on
---------+-------------------------------------------------------+----------------------------
 1       | create users                                          | 2026-08-03 21:32:27.899226
 2       | create categories                                     | 2026-08-03 21:32:27.971738
 3       | create tasks                                          | 2026-08-03 21:32:28.007099
 4       | create refresh tokens                                 | 2026-08-03 21:32:28.043508
 5       | add updated at to audited tables                      | 2026-08-03 21:32:28.072369
 6       | add version to audited tables                         | 2026-08-03 21:32:28.100497
 7       | add created by and last modified by to audited tables | 2026-08-03 21:32:28.127767
 8       | add deleted at to soft deletable tables               | 2026-08-03 21:32:28.153386
(8 rows)
```

8 migraciones aplicadas entre las 21:32:27 y 21:32:28 UTC (execution time 00:00.087s reportado por Flyway). 4 tablas de dominio + `flyway_schema_history`.

---

## Cadenas de red validadas empíricamente

**SSH desde WSL a la EC2:**

```
WSL → internet → IGW task-manager-vpc → Route Table pública (0.0.0.0/0 → igw) → SG EC2 (TCP:22 desde <mi-ip>/32) → cloud-init/sshd → prompt ubuntu@ip-10-0-4-74
```

**psql desde la EC2 a la RDS:**

```
EC2 → resolución DNS del endpoint a IP privada 10.0.128.x o 10.0.144.x → red interna VPC (nunca cruza IGW) → SG RDS (TCP:5432 desde task-manager-ec2-sg) → motor PostgreSQL 18.3 → prompt psql
```

Nunca el WSL tocó directamente la RDS. Nunca la RDS tuvo IP pública. Arquitectura EC2-pública-como-bastión + RDS-privada-con-SG-referenciado funcionando de libro.

---

## Cierre y limpieza

Al terminar la sesión, para no gastar créditos del Free Plan:

- **RDS:** destroy (Actions → Delete → sin final snapshot, sin retain backups, escribir `delete me`). Tarda 5-10 min pero puede quedar corriendo en background.
- **EC2:** stop (no terminate). Preserva el disco EBS con el repo clonado y Java/Maven instalados. Cobra ~$0.64/mes por los 8 GB EBS mientras esté parada.
- **IP pública:** al parar la EC2, AWS libera la IP. Al arrancar de nuevo mañana asigna IP nueva. La regla SG (`SSH desde My IP`) sigue OK, solo hay que usar la IP nueva.

**Costes estimados de esta sesión:** ~$0.10-0.20 de créditos (RDS + EC2 corriendo ~2h + IP pública). Créditos remaining tras la sesión: aún cerca de $100.

**Bonus del Free Plan:** al lanzar y terminar EC2 + configurar RDS se ganan $20 × 2 = **$40 adicionales en créditos** (activities). Los créditos aparecen en el balance con delay de horas o días.

---

## Deuda pendiente / próxima sesión

- **Sesión 4:** avance según Roadmap-Post-Git-Bash.md.
- **Activar billing access para IAM user `tole`:** hoy `tole` ve "Access denied" en billing (esperado, root restringe por default). Toca desde root: Account settings → activate IAM user and role access to Billing information.
- **ADR-A2 (planificado):** justificar `t3.micro` (EC2, x86) vs `t2.micro` vs `t4g.micro`; `db.t4g.micro` (RDS, ARM) vs `db.t3.micro`. Argumento clave: EC2 x86 evita fricción con imágenes Docker de nicho, RDS ARM es free-decision porque no ejecutas binarios dentro.
- **ADR-A3 (planificado):** RDS gestionada vs PostgreSQL en EC2. Argumentos Multi-AZ, backups, evidencia auditoría para banca; hoy no compensa a coste fuera de free tier.
- **ADR-A4 (planificado):** patrón SG referenciado. Documentar la decisión con la frase ⭐⭐⭐.
- **Corregir modelo mental permanente:** el "12 meses free tier" de todas las guías antiguas ya no aplica a cuentas post-jul 2025. Cualquier cálculo de coste asume consumo de créditos del Free Plan.

---

## Frases ⭐⭐⭐ consolidadas de la sesión

- *"El SG de la BD acepta el puerto 5432 solo desde el SG del backend, no por CIDR, para desacoplar identidad de topología de red y sobrevivir a cambios de IP y escalado horizontal."*
- *"Servicio gestionado en AWS cuesta ~30-50% más que autogestionar en EC2, a cambio de operación (parches, backups, HA). En banca compensa por Multi-AZ failover automático, auto minor version upgrade para CVEs, y evidencia lista para auditorías."*
- *"Bases de datos siempre en subnets privadas, sin excepciones. Si un desarrollador necesita conectar desde su portátil, lo hace vía bastión, no exponiendo el puerto al mundo."*

---

## Comandos útiles para retomar en la próxima sesión

Arrancar la EC2:

```bash
# En consola AWS: EC2 → Instances → check task-manager-ec2 → Instance state → Start instance
# Copiar la nueva Public IPv4 address del detalle de instancia
export EC2_IP="<nueva-ip>"
ssh -i ~/.ssh/task-manager-key.pem ubuntu@$EC2_IP
```

Actualizar SG si tu IP de casa cambió:

```
EC2 → Security Groups → task-manager-ec2-sg → Edit inbound rules → SSH → Source: My IP → Save
```

Si además retomas RDS (recrear desde cero cada vez porque se destruyó):

```
Consola RDS: 8-15 min. Recordar: db.t4g.micro, gp3 20GB, autoscaling OFF,
Initial database name = taskmanager, SG referenciado desde task-manager-ec2-sg.
```
