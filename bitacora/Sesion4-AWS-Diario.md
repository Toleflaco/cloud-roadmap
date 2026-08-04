# Sesión 4 — IAM Roles + S3: una EC2 accede a un bucket sin credenciales

**Fecha:** 4 agosto 2026
**Duración estimada:** ~2h (teoría 45min + práctica 60min + debugging didáctico 15min)
**Estado:** Completada

## Objetivo pedagógico

Interiorizar el patrón dorado de "backend Java en AWS": una aplicación corriendo en EC2 accede a servicios de AWS (S3, RDS, SQS, etc.) **sin ninguna credencial escrita en la máquina**, obteniéndolas dinámicamente de un IAM Role adjunto. Este patrón aparece en toda oferta senior de Java + AWS.

Arco pedagógico:

1. **Antes**: `aws s3 ls` en la EC2 → `NoCredentials`.
2. **Cambio**: adjuntar Role vía consola.
3. **Después**: `aws s3 ls` funciona sin haber configurado nada en la máquina.

Los tres estados verificados empíricamente.

## Modelo mental IAM

### Los tres tipos de identidad

| Identidad | Qué es | Credenciales | Uso típico |
|---|---|---|---|
| **IAM User** | Humano o sistema externo | Fijas (password, access keys) | Personas, CI/CD externo |
| **IAM Group** | Contenedor organizativo | No tiene | Agrupar Users por rol laboral |
| **IAM Role** | Set de permisos asumible | Temporales (~6h) al asumir | Servicios AWS, apps en EC2 |

Analogía Spring Security:
- IAM User ↔ `User` con password.
- IAM Group ↔ agrupación de Users con Authorities comunes.
- IAM Role ↔ **novedad AWS**: un "rol" que una máquina o servicio asume sin credenciales. No existe equivalente directo en Spring Security clásico. Lo más cercano es el patrón "identidad delegada del entorno" (ej: en `task-manager-microservices`, task-service confía en el header `X-User-Id` inyectado por el gateway — no valida el JWT él mismo).

### Autenticación vs Autorización — dos capas separadas

Reforzado empíricamente hoy:

- **`NoCredentials`** = fallo de autenticación. Sin identidad, IAM ni siquiera evalúa permisos.
- **`AccessDenied`** = fallo de autorización. Identidad válida, pero falta permiso concreto.

Los ARN en los mensajes de error confirman en qué fase estás. Por ejemplo:
```
User: arn:aws:sts::750392809244:assumed-role/task-manager-ec2-role/i-031f9ec92618edea1
is not authorized to perform: s3:ListAllMyBuckets
```

- `sts` (no `iam`) → credencial temporal.
- `assumed-role` → la EC2 asumió el Role.
- El instance ID identifica exactamente qué máquina lo asumió.

## Estructura de una policy

Documento JSON con statements. Cada statement:

```json
{
  "Effect": "Allow" | "Deny",
  "Action": "servicio:Operación" | ["servicio:Op1", "servicio:Op2"],
  "Resource": "ARN concreto" | "*"
}
```

**Sintaxis crítica:** la acción es `servicio:PascalCase`, no el método del SDK. Ejemplos:

| SDK Java | IAM policy |
|---|---|
| `s3.putObject(request)` | `"s3:PutObject"` |
| `s3.getObject(request)` | `"s3:GetObject"` |
| `ec2.startInstances(request)` | `"ec2:StartInstances"` |

Fácil confundirse — no es la misma capa.

### ARNs (Amazon Resource Names)

Formato general: `arn:aws:servicio:region:cuenta:tipo/id`.

S3 es un caso especial (namespace global histórico, ahora también regional):
```
arn:aws:s3:::nombre-del-bucket        ← el bucket como recurso
arn:aws:s3:::nombre-del-bucket/*      ← los objetos dentro
arn:aws:s3:::*                        ← todos los buckets (para ListAllMyBuckets)
```

### Familias de ARN en S3 — trampa clásica

Descubierto empíricamente hoy: **las acciones S3 se dividen en tres familias con ARN distintos**.

| Familia | Acciones típicas | ARN necesario |
|---|---|---|
| Sobre la **cuenta** | `s3:ListAllMyBuckets` | `*` (obligado, no acota más) |
| Sobre el **bucket** | `s3:ListBucket`, `s3:GetBucketLocation` | `arn:aws:s3:::bucket` (sin `/*`) |
| Sobre los **objetos** | `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` | `arn:aws:s3:::bucket/*` (con `/*`) |

Una policy que solo permite objetos (`bucket/*`) pero no el bucket (`bucket`) → `aws s3 ls s3://bucket` falla con `AccessDenied`. Error frecuentísimo y esperado en entrevistas.

Policy final que usé hoy (correcta):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListAllMyBuckets",
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "*"
    },
    {
      "Sid": "ListSpecificBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::toleflaco-task-manager-uploads-2026"
    },
    {
      "Sid": "ReadWriteObjects",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::toleflaco-task-manager-uploads-2026/*"
    }
  ]
}
```

### Principio de mínimo privilegio

Regla: dar solo los permisos estrictamente necesarios, sobre los recursos concretos. Nunca `Action: "*"` sobre `Resource: "*"` en producción salvo Roles administrativos deliberados.

## Roles: dos policies distintas

Un Role tiene:

1. **Trust policy** → **¿quién puede asumirme?** Sin esto, nadie puede usarlo.
2. **Permissions policy** → **¿qué puedo hacer una vez asumido?** Es análoga a la de un User.

### Trust policy para EC2

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

Léelo: "el servicio EC2 puede ejecutar `sts:AssumeRole` sobre este Role".

**Separación deliberada de capas de seguridad**: aunque tu IAM User `tole` sea admin de la cuenta, no puede asumir este Role porque no aparece como Principal en la Trust policy. Un compromiso de credenciales admin no da automáticamente acceso a lo que los Roles pueden hacer.

Si algún día un humano necesita asumir un Role (patrón "break-glass access"), la Trust policy debe listar al User o Group explícitamente.

## Instance Profile — el ingrediente oculto

Cuando adjuntas un Role a una EC2 desde la consola, la abstracción es simple: "Role → EC2". Pero por debajo hay un **Instance Profile** que envuelve al Role.

```
EC2 Instance ──> Instance Profile ──> IAM Role ──> Policies
```

La consola crea automáticamente el Instance Profile con el mismo nombre que el Role al elegir "EC2 use case". Por CLI o Terraform, el Instance Profile es un recurso explícito.

## AWS SDK Default Credential Provider Chain

El SDK for Java v2 (y también CLI, boto3, etc.) busca credenciales en este orden:

1. Variables de entorno (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
2. Fichero `~/.aws/credentials`.
3. **Instance Metadata Service** en `http://169.254.169.254`.

En una EC2 con IAM Role adjunto y sin nada en 1 y 2 → va directo al 3, encuentra credenciales temporales, y las usa. Renovación automática antes de caducar.

## IMDSv2 (Instance Metadata Service versión 2)

Defensa contra SSRF introducida en 2019, default obligatorio en instancias nuevas desde 2024.

| | IMDSv1 (viejo) | IMDSv2 (nuevo, default) |
|---|---|---|
| Petición | `GET` directo | `PUT` para token, luego `GET` con header |
| Defensa SSRF | No | Sí |
| Comportamiento sin token | Responde | Silencioso (o 401) |

Comando manual con IMDSv2:
```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
# → task-manager-ec2-role

curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/task-manager-ec2-role
```

Output esperado (JSON con credenciales temporales):
```json
{
  "Code": "Success",
  "Type": "AWS-HMAC",
  "AccessKeyId": "ASIA...",           ← prefijo ASIA = temporal STS
  "SecretAccessKey": "...",
  "Token": "...",
  "Expiration": "2026-08-05T01:27:32Z"  ← ~6h
}
```

**El SDK maneja IMDSv2 transparentemente**. Solo importa conocerlo si necesitas debugging manual, o si mueves código legacy que solo hablaba IMDSv1.

## Prefijos de Access Key ID — cómo distinguir tipos

| Prefijo | Origen | Duración |
|---|---|---|
| `AKIA...` | IAM User (access keys fijas) | Hasta que las rotes/borres |
| `ASIA...` | STS (credenciales temporales, asumidas por Role o federación) | Minutos a horas |

Regla mecánica de seguridad: si empieza por `AKIA` o `ASIA`, o si hay un `Token` de STS, **es secreto**. Nunca en chats, tickets, logs, screenshots, ni repos.

## Práctica realizada

Secuencia de la práctica:

1. Arrancar EC2 `task-manager-ec2` (parada desde Sesión 3).
2. Actualizar SG `task-manager-ec2-sg`: regla SSH → My IP (había cambiado de red, la IP anterior ya no valía).
3. SSH desde WSL con la nueva IP pública `3.254.77.22`.
4. Instalar AWS CLI v2 (no v1 de apt, deprecada).
5. **Verificación antes**: `aws s3 ls` → `NoCredentials`.
6. Crear bucket S3 `toleflaco-task-manager-uploads-2026` en `eu-west-1` (Account Regional namespace, Block all public access ON, SSE-S3, versioning OFF).
7. Crear customer-managed policy `task-manager-s3-uploads-rw` (versión inicial insuficiente, corregida después).
8. Crear IAM Role `task-manager-ec2-role` con Trust policy auto-generada para EC2 + Permissions policy adjunta.
9. Adjuntar Role a EC2 desde consola (Actions → Security → Modify IAM role).
10. **Verificación después (parcial)**: `aws s3 cp` funcionó → `aws s3 ls` falló con `AccessDenied` por policy incompleta.
11. Editar policy: añadir `s3:ListAllMyBuckets` y `s3:ListBucket` con sus ARN correctos.
12. **Verificación final**: `aws s3 ls` y `aws s3 ls s3://bucket/` funcionan.
13. Verificación manual del Metadata Service con IMDSv2 → JSON con credenciales `ASIA...` observado.

## Verificación empírica de las tres fases

**Estado 1 — Sin Role:**
```
$ aws s3 ls
aws: [ERROR]: NoCredentials: Unable to locate credentials.
```

**Estado 2 — Con Role pero policy incompleta:**
```
$ aws s3 ls
aws: [ERROR]: AccessDenied when calling ListBuckets:
User: arn:aws:sts::750392809244:assumed-role/task-manager-ec2-role/i-031f9ec92618edea1
is not authorized to perform: s3:ListAllMyBuckets

$ aws s3 cp test-upload.txt s3://toleflaco-task-manager-uploads-2026/
upload: ./test-upload.txt to s3://toleflaco-task-manager-uploads-2026/test-upload.txt
```

El PutObject funcionó porque estaba en la policy. Los List no, porque faltaban.

**Estado 3 — Policy corregida:**
```
$ aws s3 ls
2026-08-04 18:27:33 toleflaco-task-manager-uploads-2026

$ aws s3 ls s3://toleflaco-task-manager-uploads-2026/
2026-08-04 18:56:55         60 test-upload.txt
```

## Frases ⭐⭐⭐ para entrevistas

1. **"El AWS SDK for Java v2 usa la Default Credential Provider Chain: variables de entorno, `~/.aws/credentials`, y finalmente el Instance Metadata Service. En una EC2 con IAM Role adjunto, las credenciales temporales viven en el Metadata Service, el SDK las coge sin configuración, y las renueva automáticamente antes de caducar. La aplicación Spring Boot no ve credenciales — nunca."**

2. **"`NoCredentials` es fallo de autenticación — la app no tiene identidad. `AccessDenied` es fallo de autorización — la app tiene identidad pero le falta permiso concreto. Ver el ARN `assumed-role/...` en el error confirma que el Instance Metadata Service está sirviendo credenciales temporales y el SDK las está usando."**

3. **"La Trust policy es la puerta del Role, y no depende de los permisos del que llama. Un admin de la cuenta con `iam:*` puede crear el Role pero no asumirlo si el `Principal` de la Trust policy no lo incluye. Es defensa en profundidad — evita que un compromiso de credenciales admin dé automáticamente acceso a todo lo que los Roles pueden hacer."**

4. **"IMDSv2 requiere un token de sesión obtenido por PUT antes de leer metadata. Es defensa contra SSRF: un atacante que consigue GET arbitrarios en tu app no puede exfiltrar credenciales sin también poder hacer PUT. Default obligatorio en EC2s desde 2024. El AWS SDK lo maneja transparentemente."**

5. **"En S3, la ARN del bucket y la ARN de los objetos son distintas. `s3:ListBucket` va sobre `arn:aws:s3:::bucket` (sin `/*`). `s3:PutObject`/`GetObject` van sobre `arn:aws:s3:::bucket/*` (con `/*`). Y `s3:ListAllMyBuckets` va sobre `*` porque opera sobre la cuenta, no sobre un bucket concreto. Es la trampa clásica de mínimo privilegio en S3."**

6. **"Configurar el bucket con `Block Public Access` en los 4 checks + `Default encryption SSE-S3` + `Versioning` (según caso) es baseline profesional. Puntos gratis en cualquier revisión de seguridad."**

## Recursos AWS creados hoy

| Recurso | Nombre | Estado tras sesión |
|---|---|---|
| S3 Bucket | `toleflaco-task-manager-uploads-2026` (eu-west-1) | Vivo, con `test-upload.txt` (60 bytes) |
| IAM Policy | `task-manager-s3-uploads-rw` (customer-managed) | Vivo, versión corregida (3 statements) |
| IAM Role | `task-manager-ec2-role` | Vivo, adjunto a EC2 |
| Instance Profile | `task-manager-ec2-role` (auto-creado) | Vivo, vinculando EC2 y Role |
| EC2 | `task-manager-ec2` (i-031f9ec92618edea1) | Parada al cierre |

Coste estimado sesión completa: < $0.10 (EC2 corriendo ~2h, S3 con 60 bytes, IAM gratis).

## Cierre y cleanup

1. **Sesiones STS revocadas** en IAM → Roles → task-manager-ec2-role → Revoke sessions (por buena higiene, tras haber pegado credenciales temporales en chat de aprendizaje).
2. **EC2 parada** (no terminate). Preserva EBS con Java, Maven, AWS CLI, repo, fichero test-upload.txt local. IP pública se libera. Coste al mínimo (solo el EBS ~$0.02/día).
3. **Bucket, Policy, Role dejados vivos**: coste insignificante y sirven de punto de partida para próximas sesiones.

## Lecciones operativas nuevas

1. **AWS CLI v2 desde instalador oficial**, no `apt install awscli` (v1 obsoleta) ni snap.
2. **Regla SSH del SG se ata a IP fija /32**, no "desde donde estés". Al cambiar de red hay que actualizar la regla. Trade-off deliberado: pequeño coste operacional a cambio de eliminar brute-force SSH de fondo.
3. **Discrepancia consola vs realidad**: SSH funcional > status check `Initializing`. La UI puede quedar desincronizada. Refresh manual antes de asumir fallo.
4. **Familias de ARN en S3** (cuenta / bucket / objeto) — no compartir Resource entre acciones de familias distintas.
5. **IMDSv2 default** — `curl` sin token devuelve vacío en silencio. No es fallo del Metadata Service, es defensa.
6. **Nunca pegar credenciales AWS** (fijas o temporales) en chats, logs, o cualquier canal no efímero. Regla: si empieza por `AKIA` / `ASIA` o hay `Token` STS, es secreto.
7. **`Sid` en policies** — identificador legible por statement, útil en auditoría y en logs de CloudTrail.

## ADR propuesto (A2)

Título tentativo: **"Instance Profile con IAM Role para acceso a S3, no access keys en application.properties"**.

Formato Michael Nygard:
- Contexto: `task-manager-api` necesita subir/descargar objetos de S3 desde una EC2.
- Decisión: crear un IAM Role con permisos mínimos (`PutObject`, `GetObject`, `ListBucket` sobre el bucket concreto) y adjuntarlo a la EC2 vía Instance Profile.
- Consecuencias: la app no ve credenciales, no hay rotación manual, no hay secretos que filtrar. Trade-off: dependencia del Metadata Service (nulo problema en EC2 nativa; irrelevante fuera de AWS).
- Alternativa descartada: access keys de IAM User en `application.properties`. Descartada por riesgo de filtración y coste operacional de rotación.

Pendiente redactar y commit al repo `cloud-roadmap/decisions/`.

## Deuda arrastrada

- **Confirmar renombrado VPC** `task-manage-vpc` → `task-manager-vpc` (Sesión 2).
- **Activar billing access para IAM user `tole`** desde root (Account settings → activate IAM user and role access to Billing).
- **Verificar namespace del bucket creado hoy** (Regional vs Global) en S3 → bucket → Properties.
- **Escribir ADR A2** (arriba).

## Para retomar en Sesión 5

Sesión 5 propuesta: **almacenamiento S3 desde la app Spring Boot** (no ya desde CLI en la EC2). Endpoint POST que sube un fichero al bucket usando AWS SDK for Java v2. Presigned URLs para descargar. Verificar que el SDK usa las credenciales del Instance Profile sin configurar nada en `application.properties`.

Comandos para retomar EC2:
```bash
# 1. En consola AWS: arrancar EC2, copiar nueva Public IPv4.
# 2. Actualizar regla SG task-manager-ec2-sg con My IP (si cambió de red).
# 3. Desde WSL:
ssh -i ~/.ssh/task-manager-key.pem ubuntu@<NUEVA-IP>

# 4. Verificar que el Role sigue vivo:
aws s3 ls
# Debería listar toleflaco-task-manager-uploads-2026.
```

## Meta-observaciones de método

- **El error didáctico funcionó mejor que el éxito directo.** Al fallar `aws s3 ls` con `AccessDenied` tras adjuntar el Role, tuve que enseñar familias de ARN S3 en el momento y con motivación clara. Si hubiera acertado la policy a la primera, se me habría escapado el matiz.
- **Parar cuando algo tarda demasiado fue el instinto correcto.** El "Initializing" de 10+ min me hizo dudar. Resultó ser refresh UI. Pero verificar antes de seguir apilando cosas encima es siempre la decisión correcta.
- **Pegar credenciales en chat fue un error operacional**. Lección barata (temporales, revocadas), pero enunciada explícitamente para no repetirla. En cualquier canal profesional habría sido un incidente de seguridad reportable.

