# Sesión 3 — AWS: EC2 + RDS PostgreSQL (parte 1: conceptos)

**Fecha:** 3 ago 2026
**Duración:** ~1h de trabajo conceptual (dentro de una jornada más larga con otro roadmap)
**Estado:** partida honestamente. Conceptos cubiertos, ejecución en consola pendiente.

## Contexto y decisión

La Sesión 3 original planificaba lanzar EC2 t3.micro + RDS db.t3.micro, configurar Security Groups referenciados EC2→RDS, y aplicar migraciones Flyway del monolito `task-manager-api` contra la RDS. Al llegar al paso Key pair del wizard de Launch instance, con ~4h acumuladas de estudio en el día entre otro roadmap y este, se decidió cerrar aquí antes de tocar los bloques críticos (Security Groups referenciados y Flyway sobre RDS) que requieren cabeza fresca.

**Regla aplicada:** techo 4h/día, no forzar concentración en el bloque pedagógico gordo de la sesión. Ningún recurso facturable creado — Key pair aún no descargado, instancia no lanzada.

## Conceptos cubiertos

### EC2 — el modelo mental

Alquiler de ordenadores por horas. Piezas de una instancia:

- **AMI** (Amazon Machine Image): plantilla de disco de arranque con SO preinstalado. Equivalente a una ISO post-instalada. Read-only — al lanzar se copia al disco EBS individual de la instancia.
- **Instance type**: tamaño del hardware virtual (`t3.micro` = 2 vCPU + 1 GB RAM).
- **Key pair**: par SSH asimétrico. AWS guarda la pública, tú te quedas con la privada.
- **VPC + subnet**: dónde vive la instancia (encaja con la Sesión 2).
- **Security Group**: firewall pegado a la interfaz de red.

### Anatomía del acceso SSH a una EC2 pública

El paquete SSH atraviesa 4 capas, cualquiera puede fallar:

1. **Internet Gateway** — puerta de entrada de la VPC desde internet.
2. **Route Table** — dirige el paquete a la subnet correcta (`0.0.0.0/0 → igw` en públicas).
3. **Security Group** — firewall de la instancia decide si el paquete entra (TCP:22 desde IP autorizada).
4. **cloud-init + sshd** — cloud-init consultó el Instance Metadata Service (`http://169.254.169.254`) al arrancar y depositó la clave pública en `/home/ubuntu/.ssh/authorized_keys`. `sshd` autentica contra esa pública.

Este mapa mental es la herramienta primaria para depurar cualquier fallo de conexión: recorrer las 4 capas y aislar dónde se rompe.

### Security Groups — reglas y sources

Dos listas: **inbound** (entrada) y **outbound** (salida, por defecto "permitir todo").

Regla inbound = protocolo + puerto + source. El source puede ser:

- Un **CIDR** (`0.0.0.0/0`, `<mi-ip>/32`).
- **Otro Security Group** ← el modo referenciado, pendiente para la parte 2.

En el wizard, "Type: SSH" es azúcar de UI que rellena `Protocol=TCP, Port=22`.

**Regla operativa SSH:** source `My IP` (`/32`) siempre, nunca `0.0.0.0/0`. Al cambiar de red hay que editar la regla, pero el atajo "My IP" en la consola autodetecta. Timeout mudo al hacer SSH (sin `Connection refused`) suele ser el SG bloqueando por IP obsoleta.

### CPU burstable y créditos (familia `t`)

- Baseline: `t3.micro` = 20% de una vCPU sostenido.
- Bajo baseline → acumula créditos. Sobre baseline → gasta créditos, corre al 100%.
- Créditos agotados → dos modos:
  - **Standard** (t2 default): throttle a baseline, sin cobros extra.
  - **Unlimited** (t3 default): sigue a 100%, cobra por hora de over-usage. Sale de la consola en Advanced Details → Credit specification.

**Encaje con cargas reales:**
- Buena para picos cortos + valles (Spring Boot arrancando, servicios internos poco usados, dev/staging, batches nocturnos).
- Mala para carga sostenida a CPU alta (ej. 200 req/s constantes). Para eso: familias `c` (compute-optimized) o `m` (general purpose), no burstable.

### Coste comparado EC2 vs RDS (fuera de free tier, 24/7)

| Recurso | Total mensual estimado |
|---|---|
| EC2 t3.micro + 8GB EBS + IP pública | ~$12.60 |
| RDS db.t3.micro + 20GB storage + backups | ~$16-18 |

**Por qué RDS es más caro** — patrón que se repite en TODOS los servicios gestionados de AWS:

1. Pagas por la operación gestionada: parches, backups, snapshots, Multi-AZ failover, métricas.
2. Storage RDS gp3 es más caro por GB que EBS gp3 ($0.115 vs $0.08).
3. **RDS parada se reinicia sola a los 7 días** — no la puedes dejar parada indefinidamente. La EC2 sí. Para "no gastar entre sesiones": EC2 se para (stop), RDS es más seguro destruirla + snapshot final.

**Patrón general:** servicio gestionado ~30-50% más caro que autogestionado en EC2, a cambio de quitarte trabajo operativo. Aplica también a MSK (Kafka), ElastiCache (Redis), ALB (nginx), EKS (K8s).

**Ventajas de RDS para venderlo en entrevistas de banca/consultorías:**
- Multi-AZ failover automático (~60-120s) vs restore manual de backup a las 3AM.
- Auto minor version upgrade para CVEs vs ventana de mantenimiento planificada.
- Evidencia de cumplimiento (PCI-DSS, ISO 27001, ENS) preconstruida — auditorías más rápidas.

### Key pairs — dos formas

- **A. Crear en AWS** (rápido, primera vez): AWS genera el par, te descargas la privada `.pem` una única vez, se queda con la pública. Fricción baja, la privada "tocó" infra de AWS.
- **B. Importar tu clave pública** (profesional): generas con `ssh-keygen -t ed25519` en tu WSL, subes solo la pública. La privada nunca sale de tu máquina.

Formato para clientes OpenSSH (Linux/WSL/macOS): `.pem`. `.ppk` es para PuTTY, no aplica.
Algoritmo recomendado: **ED25519** (moderno, corto, rápido). RSA sigue siendo default por compatibilidad histórica.

**Manipulación del `.pem` tras descarga:** moverlo de `C:\...\Downloads\` a `~/.ssh/`, `chmod 600`. Downloads es zona de tránsito con sincronización a nube automática y objetivo de malware; `~/.ssh/` es la convención universal Linux y única ruta que respeta `~/.ssh/config`.

**Backup de la privada:** en gestor de contraseñas (Bitwarden en mi caso). Perder la privada sin backup = no puedes reentrar a la EC2 con ese key pair. Recuperación posible con Systems Manager Session Manager, EC2 Instance Connect, o recreación de instancia con reasignación de EBS — pero requiere prevención antes del incidente.

### Tags

Pares clave-valor pegados a recursos AWS. No afectan al funcionamiento — sirven para:
- Filtrado en consola.
- Cost Explorer agrupa la factura por tag (con cost allocation tags activadas).
- Automatización por scripts.

`Name` es una tag más, especial solo porque la consola la usa como columna visible por defecto.

## Estado del wizard EC2

Pantalla "Launch an instance" abierta. Progreso:

- Name: `task-manager-ec2` — hecho.
- Application and OS Images: Ubuntu Server 24.04 LTS x86_64 (`ami-04df7d76c1b804451`) — hecho.
- Instance type: `t3.micro` — hecho (default con free tier eligible).
- Key pair: **PENDIENTE crear**. Al retomar: `task-manager-key`, ED25519, `.pem`.
- Network settings: **PENDIENTE**. Aquí va el SG con SSH desde My IP.
- Storage: default 8 GB gp3 — pendiente confirmar.
- Advanced details: pendiente. Ver `Credit specification` para conocer dónde vive Unlimited/Standard.

**Nada facturable creado en esta sesión.** El wizard no persiste como borrador — al retomar se rellena de nuevo (5 min con conceptos frescos).

## Deuda pendiente para próxima sesión

### Ejecución técnica (Sesión 3 parte 2)

1. Completar wizard EC2 desde Key pair hasta Launch.
2. Descargar `.pem`, mover a `~/.ssh/`, `chmod 600`, backup en Bitwarden.
3. SSH desde WSL para verificar cadena IGW → RT → SG → sshd.
4. Crear **DB Subnet Group** (concepto nuevo: RDS necesita al menos 2 subnets en AZs distintas para poder ofrecer Multi-AZ, aunque no lo activemos).
5. Lanzar RDS `db.t3.micro` en las subnets privadas.
6. **Security Groups referenciados** — bloque pedagógico gordo: SG de RDS acepta puerto 5432 solo desde el SG de la EC2 (no CIDR). Este es el modelo profesional; verificar que sin esa regla no conecta, y con ella sí.
7. Aplicar migraciones Flyway del monolito `task-manager-api` contra la RDS desde la EC2.
8. **Cierre obligatorio:** parar EC2 (o quitar IP pública), destruir RDS + snapshot final.

### Renombrado VPC

Detectado que la VPC de la Sesión 2 se llama `task-manage-vpc` (typo, falta `-r`). Cambiar tag `Name` a `task-manager-vpc` en consola VPC → Your VPCs → editar. El VPC ID no cambia, no rompe nada. Pendiente de confirmar si se hizo durante la sesión (interrumpido antes de verificar).

### ADRs pendientes

- **ADR-A2 (planificado):** justificar `t3.micro` vs `t2.micro` vs `t4g.micro` para el rol de aprendizaje. Argumentos: Nitro > Xen, 2 vCPU > 1 vCPU, x86 evita fricción con imágenes Docker de nicho, coste equivalente en free tier.
- **ADR-A3 (planificado):** RDS gestionada vs PostgreSQL en EC2 para el proyecto. Argumentos: Multi-AZ, backups, evidencia auditoría — aunque a coste hoy no compensa fuera de free tier.

## Retomar rápido al empezar próxima sesión

1. Verificar renombrado VPC (si no se hizo).
2. Abrir consola EC2 → Launch instance → rellenar rápido hasta Key pair (5 min con conceptos ya conocidos).
3. Entrar a Network settings — **arranque conceptual del día siguiente**. Aquí es donde se decide el SG de la EC2 y donde toca detenerse a explicar la diferencia entre SG referenciado y CIDR abierto, antes de RDS.

## Notas para diario personal

- Regla de 4h respetada, buena decisión de parar antes de forzar el bloque crítico cansado.
- El wizard EC2 tiene ~20 min de UI cuando los conceptos ya están claros. La sesión "corta" real (EC2 + RDS + SG + Flyway) es probablemente 90 min limpios sin fatiga acumulada.
- Bloque conceptual denso hoy: EC2, AMIs, burstable, key pairs, coste comparado, tags, anatomía SSH. Suficiente material para una sesión conceptual completa por sí misma.
