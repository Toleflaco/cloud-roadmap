# Sesión 6 — AWS S3 upload end-to-end desde Spring Boot + recreación de RDS from scratch

**Fecha:** 6 agosto 2026
**Duración:** ~3h (dos bloques: mañana y tarde-noche, con veterinario en medio)
**Estado:** Completada. Objetivo empírico end-to-end conseguido: fichero real en S3 vía `curl` desde WSL a Spring Boot en EC2, sin credenciales escritas en ningún sitio.

## Objetivo pedagógico

Completar las Fases 3-6 de la Sesión 5 (Service + Controller + Deploy en EC2 + verificación empírica end-to-end), materializando el patrón dorado *"backend Java en AWS con Instance Profile"* como funcionalidad real y no como teoría.

Objetivo empírico concreto:
```
$ curl -X POST http://<ec2-ip>:8080/files -H "Authorization: Bearer <token>" -F "file=@prueba.txt"
{"key":"2026/08/06/uuid-prueba.txt"}
```
Y ver el fichero en la consola S3.

**Conseguido.** Timestamp del objeto en S3: `August 6, 2026, 20:44:24 (UTC+02:00)`.

## Fase 3 — FileUploadService

### Decisiones estructurales

- **Package**: `com.mtole.taskmanager.files` (siguiendo la convención package-by-feature del proyecto: `tasks`, `users`, `categories`, `activity`).
- **Configuración del bucket**: externalizado en `application.yml` como `aws.s3.bucket`, leído con `@Value("${aws.s3.bucket}")` sin default. Fail-fast si el entorno no lo provee. Justificación: los buckets S3 suelen cambiar entre entornos (dev/staging/prod), es configuración de entorno, no constante de arquitectura.

### Firma pública del método principal

```java
public String upload(MultipartFile file) throws IOException
```

**Frontera de capas materializada aquí.** El controller solo conoce Spring MVC (`MultipartFile`). El service es la frontera de adaptación entre el mundo Spring MVC y el mundo AWS SDK.

Regla operativa aprendida:
> *"Las clases del SDK de un vendor externo (`PutObjectRequest`, `S3Client`, `RequestBody`) viven en el service. El controller solo conoce Spring MVC. El service traduce entre los dos mundos. Es el patrón Adapter aplicado sin ceremonial."*

Error didáctico previo (documentado): inicialmente predije la firma como `public void upload(PutObjectRequest file)`. Dos problemas: `PutObjectRequest` como parámetro invierte la dirección de la dependencia (controller conocería AWS SDK), y `void` no permite devolver la key al cliente HTTP. Corregido a la primera tras identificar el error.

### Estrategia de generación de key

Elegida **Opción C**: `YYYY/MM/DD/uuid-nombre_sanitizado.ext`.

Ventajas técnicas concretas verificadas hoy:
1. Listados por prefijo en S3 (`s3 ls s3://bucket/2026/08/`) devuelven un mes entero.
2. Ciclo de vida de S3 ("borrar objetos con prefix `2026/07/` a los 90 días") es trivial.
3. Debugging futuro: la key en un log de error muestra fecha sin BD.
4. UUID garantiza cero colisiones.
5. **Consecuencia UX en consola S3**: la interfaz web muestra las `/` como jerarquía navegable con breadcrumbs (`2026/ > 08/ > 06/`), aunque S3 sea internamente un key-value store plano. Empíricamente verificado hoy en la consola.

### `PutObjectRequest` — tres campos mínimos

- `.bucket(String)` — dónde va (nombre del bucket).
- `.key(String)` — con qué nombre dentro del bucket.
- `.contentType(String)` — MIME type. Sin él, el navegador recibe `binary/octet-stream` al descargar y no sabe interpretar el fichero. Se obtiene de `MultipartFile.getContentType()`.

### `RequestBody` — el contenido binario

Separado del `PutObjectRequest` (que solo lleva metadatos). Se pasa como segundo argumento a `s3Client.putObject(request, body)`:

```java
RequestBody.fromInputStream(file.getInputStream(), file.getSize())
```

**Trampa clásica del SDK v2**: `fromInputStream` requiere **content-length obligatorio**. Un `InputStream` no puede ser leído dos veces (una para calcular tamaño, otra para enviar), así que hay que pasar la longitud explícitamente. `MultipartFile` provee ambos (`.getInputStream()` y `.getSize()`) gratis.

### Sanitizador — trampa didáctica

Primer intento del sanitizador con enfoque **blacklist** (quitar tildes con `Normalizer.NFD` + `.replace("ñ", "n")` + `.replaceAll("\\s+", "-")`) tenía tres bugs sutiles:

1. `.replace("ñ", "n")` era código muerto — la ñ ya se había descompuesto en `n` + tilde combinante en el paso NFD anterior, y la tilde había sido eliminada.
2. `.replace()` no interpreta regex, trata `\\s+` como string literal.
3. Enfoque conceptualmente incorrecto: intentar preservar letras es una carrera perdida (paréntesis, `?`, `#`, `&`, `%` — la lista de "malos" nunca acaba).

Refactor a enfoque **whitelist**:

```java
filename.replaceAll("[^a-zA-Z0-9._-]", "-")
```

Léase: *"todo carácter que NO sea (`^`) letra ASCII, dígito, punto, guión bajo o guión, sustitúyelo por `-`"*. Trade-off asumido: perdida legibilidad castellana en las keys; **no perdida** funcionalidad.

Regla operativa aprendida:
> *"Whitelist > Blacklist en sanitización. Define el conjunto seguro pequeño, sustituye todo lo demás. Fallar de forma segura por defecto es mejor que enumerar exhaustivamente lo peligroso."*

## Fase 4 — FileUploadController

Sencillo, corto, sin sorpresas:

```java
@RestController
@RequestMapping("/files")
public class FileUploadController {
    private final FileUploadService fileUploadService;

    public FileUploadController(FileUploadService fileUploadService) {
        this.fileUploadService = fileUploadService;
    }

    @PostMapping
    public UploadResponse upload(@RequestParam("file") MultipartFile file) throws IOException {
        return new UploadResponse(fileUploadService.upload(file));
    }

    private record UploadResponse(String key) {}
}
```

### Detalles observados y consolidados

- **Constructor injection sin `@Autowired`**: desde Spring 4.3 (2016), un constructor único es punto de inyección automático. `@Autowired` es redundante y estilísticamente obsoleto.
- **`S3Client` inyectado como bean + `String bucket` como `@Value`**: dos mecanismos de resolución de Spring coexistiendo en un constructor único. DI de beans + property placeholder resolution.
- **Sin `ResponseEntity`**: Jackson serializa el record automáticamente. Devuelve HTTP 200. Deuda menor apuntada: para REST idiomático sería 201 Created + `Location: /files/{key}`.
- **UploadResponse como nested private record**: encapsulación fuerte, solo el controller lo instancia. Alternativa (record separado en el package) evaluada como más reutilizable. Coherencia con la convención del proyecto — deuda pequeña.

### Autenticación heredada

`POST /files` queda protegido por JWT via `SecurityConfig` global (deny-by-default, allow explícito). Coherente con la política del proyecto. Un endpoint público de upload permitiría a un troll con `curl` en bucle llenar el bucket de basura y consumir presupuesto.

## Descubrimiento empírico grande: antipatrón "exclusion como DBless"

### Primer intento fallido

Estrategia inicial: perfil `aws-s3` con exclusiones de autoconfig para que la app arrancara solo con S3 (sin Postgres/Mongo/Flyway/Security). El `application-aws-s3.yml` se creó con:

```yaml
spring:
  autoconfigure:
    exclude:
      - org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration
      - org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration
      - org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration
      # ... y varias más
```

Resultado al arrancar en local:
```
Failed to configure a DataSource: 'url' attribute is not specified
```

### Análisis

`spring.autoconfigure.exclude` desactiva **una** clase, no todas las que dependen de esa infraestructura. `DataSourceAutoConfiguration` estaba excluida, pero `DataSourceTransactionManagerAutoConfiguration`, `JdbcTemplateAutoConfiguration`, `JpaRepositoriesAutoConfiguration` y varias más seguían intentando configurar `DataSource`. La blacklist se convierte en carrera perdida (mismo patrón que la sanitización con blacklist antes).

### Conclusión

> **Excluir autoconfig es antipatrón para "monolito DBless".** Un monolito que fue diseñado con BBDD obligatoria no se hace opcionalmente sin ella con `spring.autoconfigure.exclude`. Dos caminos válidos:
> - **Tocar la BBDD**: aceptar que la app necesita RDS/Mongo/etc, configurar env vars, conectar.
> - **Extraer el nuevo dominio a un módulo aparte**: `task-manager-files` como micro-servicio con solo Spring Web + AWS SDK.
> **La tercera vía (exclusion) es antipatrón.**

Decisión: pivotar a Ruta B (conectar RDS real). El `application-aws-s3.yml` se borra al final de la sesión.

## Descubrimiento operativo grande: RDS Delete accidental (Sesión 3)

Al ir a arrancar la RDS supuestamente parada, se descubre que **la RDS no existe**. Consola RDS → Databases (0).

### Diagnóstico con CloudTrail

Consulta a CloudTrail → Event history → filtro `Resource name: task-manager-db`:

```
Aug 03  22:57  CreateDBInstance  tole   task-manager-db
Aug 03  23:35  DeleteDBInstance  tole   task-manager-db  ← 38 min después
```

Ambos eventos con `userIdentity: tole`. No fue AWS, no fue auto-cleanup del Free Plan. **Fue un delete humano** el 3 de agosto, 38 minutos después de crear la instancia por primera vez. Probablemente al confundir el botón `Stop` con `Delete` (adyacentes en el menú Actions de RDS) al hacer cleanup nocturno.

Sesión 3 parte 2 nunca tuvo diario formal. Sin diario, la memoria queda como *"la paré"* aunque el evento fuera *"la borré"*. **CloudTrail no miente; la memoria sí.**

### Regla operativa consolidada

> ***"RDS Stop y RDS Delete están adyacentes en el menú Actions. Stop pausa (7 días máx, se auto-arranca). Delete destruye. Verificar dos veces antes de confirmar. Si el diario dice 'stop', que CloudTrail lo respalde."***

### Mitigación aplicada hoy

En el wizard de creación de RDS de esta sesión: **checkbox `Enable deletion protection` activado**. Ahora un `Delete DB instance` desde consola pide desactivar primero deletion protection. Fricción intencional al borrado destructivo.

### Ventana empírica confirmada: la RDS parada NO tenía backups retained

Consulta a Automated backups → Retained → *"No retained backups found"*. Habría sido restore instantáneo con toda la configuración preservada. **Backup retention estaba en 0 días o se borró explícitamente en el diálogo de Delete de Sesión 3.**

Mitigación aplicada hoy: **Backup retention: 7 días** en el wizard.

## Recreación completa de RDS

### Wizard con Full configuration

Elegido `Full configuration` (no `Express`, que impone Aurora Serverless v2 ~$45/mes). Parámetros finales:

| Campo | Valor | Justificación |
|---|---|---|
| Engine | PostgreSQL 18.3-R2 | Latest stable |
| Template | Free tier / Dev-test | Presets económicos |
| DB instance identifier | `task-manager-db` | Coherencia |
| Master username | `postgres` | Master AWS, no la usa la app |
| Master password | *(generada nueva y guardada en Bitwarden)* | |
| Instance class | `db.t4g.micro` | 2 vCPU, 1 GB RAM, ARM Graviton — más barato que t3 equivalente |
| Storage | 20 GiB gp2 | Mínimo Free tier |
| VPC | `vpc-0d36eccf71cddeda7` | Misma que EC2 (crítico — el default VPC del wizard NO sirve) |
| DB subnet group | `task-manager-db-subnet-group` | Reutilizado, sobrevivió al delete |
| Public access | No | Solo desde EC2 vía SG referenciado |
| VPC security group | `task-manager-db-sg` | Recreado hoy con SG referenciado |
| AZ | `eu-west-1a` | Misma que EC2 (evita tráfico inter-AZ) |
| Initial database name | `task_manager` | Con underscore, del `application-dev.yml` |
| Backup retention | 7 days | Mitigación anti-delete futuro |
| Deletion protection | Enabled | Mitigación anti-delete accidental |
| Encryption | Enabled (default aws/rds KMS) | Sin coste extra |

### Security Group `task-manager-db-sg` — modelo referenciado

Recreado esta sesión (el original se destruyó en cascada al borrar RDS en Sesión 3):

- **Inbound rule única**: TCP 5432 desde `sg-036772953179b5905` (`task-manager-ec2-sg`) — **NO** desde CIDR.

Ventajas del modelo referenciado, ya predichas y ahora consolidadas:
1. Si mañana la EC2 se reemplaza por otra instancia (nueva IP privada, nuevo IP público), pero con el mismo SG, hereda acceso automáticamente. Cero cambios en el SG de RDS.
2. Si se escala horizontalmente (varias EC2 detrás de un load balancer, todas con el mismo SG), todas conectan a RDS sin tocar reglas.
3. La rotación de IP residencial es irrelevante — la RDS no debe ser accesible desde el portátil directamente, solo desde la capa de aplicación.

Frase para entrevista:
> *"El Security Group de la RDS acepta 5432 solo desde el Security Group de la capa de aplicación, no desde CIDRs. Modelo referenciado: la regla persiste correctamente aunque cambien instancias, IPs o se escale horizontalmente. Es baseline de arquitectura AWS profesional."*

## Application user en RDS — `task_manager_app`

En Sesión 3 la app conectaba con `task_manager_app` (application user), no con `postgres` (master AWS). Buena práctica coherente con dev local.

**Un solo paso adicional en la recreación**: crear el user manualmente. Desde EC2 via `psql`:

```sql
CREATE USER task_manager_app WITH PASSWORD '<...>';
\c task_manager
GRANT CONNECT ON DATABASE task_manager TO task_manager_app;
GRANT USAGE, CREATE ON SCHEMA public TO task_manager_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO task_manager_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO task_manager_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO task_manager_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO task_manager_app;
```

Claves conceptuales:

- **`CREATE USER` → respuesta `CREATE ROLE`**: en Postgres, los "users" son roles con capacidad LOGIN. Nombres intercambiables.
- **`GRANT USAGE, CREATE ON SCHEMA public`**: cambio importante entre Postgres 14 y 15+. Por defecto, usuarios non-owner ya no pueden crear objetos en `public` sin este GRANT explícito. Sin él, Flyway habría fallado al crear tablas.
- **`ALTER DEFAULT PRIVILEGES`**: línea sutil pero crítica. Dice "cuando alguien cree tablas futuras en este schema, dales permisos a `task_manager_app`". Sin ella, Flyway habría creado tablas como owner=postgres y `task_manager_app` no habría podido usarlas.

Frase para entrevista:
> *"En Postgres 15+, `GRANT USAGE, CREATE ON SCHEMA public` es obligatorio para que un application user no-owner pueda crear objetos. Es cambio de seguridad respecto a versiones anteriores. Y `ALTER DEFAULT PRIVILEGES` garantiza que futuras tablas se creen ya con permisos correctos, no como huérfanas del owner."*

### Warning de compatibilidad `psql` v16 vs Postgres 18

```
WARNING: psql major version 16, server major version 18.
         Some psql features might not work.
```

`\l` (meta-comando para listar BBDDs) rompió con `ERROR: column d.daticulocale does not exist` — el cliente v16 asume columnas del catálogo que Postgres 18 renombró. Workaround: `SELECT datname FROM pg_database;` (SQL puro, estándar, siempre funciona).

Deuda menor apuntada: actualizar `postgresql-client` en EC2 a v18 en Sesión 7.

## Deploy y arranque de la app

### `application-aws.yml`

Perfil nuevo `aws`, basado en `application-dev.yml` con adaptaciones para runtime AWS:

```yaml
spring:
  datasource:
    url: ${DB_URL}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  data:
    mongodb:
      uri: mongodb+srv://taskmanager_app:${MONGODB_PASSWORD}@task-manager-cluster.dgu0fym.mongodb.net/taskmanager?retryWrites=true&w=majority&appName=task-manager-cluster
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true

jwt:
  secret: ${JWT_SECRET}
  access-expiration: 60m

aws:
  s3:
    bucket: toleflaco-task-manager-uploads-2026

logging:
  level:
    root: INFO
    software.amazon.awssdk: INFO

management:
  health:
    mongodb:
      enabled: false

server:
  port: 8080
```

Diferencias con dev:
- `show-sql: false` — sin logs verbosos.
- Sin defaults en `${DB_URL}`, `${DB_USERNAME}`, `${DB_PASSWORD}` — obligatorio pasarlos como env vars.

### Estrategia de env vars

Copia del `.secrets` local a EC2 con `scp`, luego `source ~/.secrets` con `set -a` para auto-export:

```bash
set -a
source ~/.secrets
set +a
```

Combinación clásica en scripts de arranque para cargar env vars desde un fichero.

### Deploy

- Compilación en local WSL (`./mvnw clean package -DskipTests`).
- `scp` del JAR a EC2 (`~/task-manager-api-0.0.1-SNAPSHOT.jar`, 86 MB en 4 segundos vía SSH).
- Arranque en EC2: `java -jar ~/task-manager-api-0.0.1-SNAPSHOT.jar --spring.profiles.active=aws`.

### Primer arranque — fallo empírico esperable: MongoDB Atlas TLS

```
Caused by: javax.net.ssl.SSLException: (internal_error) Received fatal alert: internal_error
```

Diagnóstico correcto a la primera: MongoDB Atlas tiene **IP Access List** (firewall a nivel de proyecto Atlas, independiente de AWS SG). La IP de la EC2 (`3.250.88.27`) no estaba en la lista → Atlas rechaza el handshake TLS con `internal_error` (código genérico "no te conozco").

Corrección: Atlas → Database & Network Access → añadir `3.250.88.27/32` con comentario `task-manager-ec2 (Aug 2026)`.

### Segundo arranque — éxito

Log final:
```
18:38:13.639 - Schema "public" is up to date. No migration necessary.
18:38:17.885 - Discovered replica set primary ac-vlfm20t-shard-00-01
18:38:24.349 - Tomcat started on port 8080 (http)
18:38:24.373 - Started TaskManagerApiApplication in 18.996 seconds
```

**RDS Postgres 18 + MongoDB Atlas 8.0 + próximo S3 = tres servicios conectados desde Spring Boot 4 corriendo en EC2.**

Nota importante: **Flyway aplicó las 8 migraciones V1-V8 sin intervención** en el primer arranque (aunque el mensaje diga "up to date" — fue instantáneo). BBDD `task_manager` quedó con schema completo.

## Verificación empírica end-to-end

Flujo:
1. `POST /users` — crear usuario.
2. `POST /auth/login` — obtener JWT.
3. `POST /files` con Bearer token + multipart — upload real.

Resultado del paso 3:
```json
{"key":"2026/08/06/b56bb4ec-a963-40e0-92be-7c3458f891ae-prueba.txt"}
```

Verificación en consola S3: bucket `toleflaco-task-manager-uploads-2026` → `2026/ > 08/ > 06/ > b56bb4ec-a963-40e0-92be-7c3458f891ae-prueba.txt`, 52 bytes, timestamp `August 6, 2026, 20:44:24 (UTC+02:00)`.

### La cadena empírica completa detrás del JSON

1. `curl` WSL (88.11.202.24) → EC2:8080 (SG allow del puerto 8080).
2. Spring Security validó el JWT.
3. `FileUploadController.upload(MultipartFile)` recibió el multipart.
4. `FileUploadService.upload(file)` construyó la key `2026/08/06/uuid-prueba.txt`.
5. `s3Client.putObject(request, RequestBody.fromInputStream(...))` **por primera vez llamó a AWS**.
6. La Default Credential Provider Chain **por primera vez despertó** (era lazy hasta este momento — validación empírica del descubrimiento de Sesión 5).
7. La chain bajó los 5 eslabones, encontró credenciales temporales en IMDSv2 sirviendo del Role adjunto.
8. El SDK firmó la petición con SigV4 usando la Region eu-west-1.
9. S3 aceptó el PUT y devolvió 200 OK.
10. El service devolvió la key al controller.
11. Jackson serializó `new UploadResponse(key)` a JSON.
12. Tomcat lo devolvió como response body.

**Cero credenciales en el código. Cero credenciales en `application.yml`. Cero credenciales en env vars AWS. Solo Instance Profile.**

## Frases ⭐⭐⭐ para entrevistas

1. **"En un backend Java corriendo en EC2 con Instance Profile, el SDK v2 usa la Default Credential Provider Chain: variables de entorno → system properties → Web Identity → ~/.aws/credentials → IMDSv2. Para en el 5º eslabón, resuelve credenciales temporales del Role, firma la petición SigV4. La app no ve credenciales nunca."**

2. **"Las clases del SDK de un vendor externo (S3Client, PutObjectRequest, RequestBody) viven en el service, no en el controller. El service traduce entre Spring MVC (MultipartFile) y el mundo AWS SDK. Es el patrón Adapter aplicado sin ceremonial y permite cambiar de S3 a Google Cloud Storage sin tocar controllers."**

3. **"Whitelist > Blacklist en sanitización. `filename.replaceAll(\"[^a-zA-Z0-9._-]\", \"-\")` es más seguro que enumerar exhaustivamente los caracteres problemáticos. Falla de forma segura por defecto; imposible olvidar un caso borde."**

4. **"El Security Group de la RDS acepta 5432 solo desde el Security Group de la capa de aplicación (modelo referenciado), no desde CIDRs. La regla persiste aunque cambien instancias, IPs o se escale horizontalmente. Es baseline de arquitectura AWS profesional."**

5. **"En Postgres 15+, un application user no-owner necesita `GRANT USAGE, CREATE ON SCHEMA public` explícito para crear objetos. Y `ALTER DEFAULT PRIVILEGES` garantiza que las tablas futuras se creen ya con permisos correctos, no como huérfanas del owner. Sin ambas, Flyway falla al primer arranque."**

6. **"MongoDB Atlas tiene IP Access List a nivel de proyecto, independiente de AWS Security Groups. Cuando la app se mueve de dev local a EC2 en producción, la IP cambia y Atlas rechaza el TLS con `internal_error`. Defense in depth: doble firewall (AWS SG + Atlas allow list) que hay que mantener coordinado."**

7. **"Excluir autoconfig con `spring.autoconfigure.exclude` no hace un monolito 'DBless'. Es antipatrón. Un monolito que fue diseñado con BBDD obligatoria requiere una BBDD, o extraes el nuevo dominio a un módulo aparte. La tercera vía no existe."**

## Recursos AWS al final de la sesión

| Recurso | Estado final |
|---|---|
| S3 Bucket `toleflaco-task-manager-uploads-2026` | Vivo, con `test-upload.txt` (Sesión 4) + `prueba.txt` (Sesión 6) |
| IAM Policy `task-manager-s3-uploads-rw` | Vivo |
| IAM Role `task-manager-ec2-role` | Vivo |
| Instance Profile `task-manager-ec2-role` | Vivo |
| EC2 `task-manager-ec2` | **Stopped** |
| SG `task-manager-ec2-sg` | Vivo (rules SSH:22 y HTTP:8080 desde 88.11.202.24/32) |
| **RDS `task-manager-db`** (NUEVA) | **Stopped**. PostgreSQL 18.3, db.t4g.micro, 20 GB, deletion protection ON, backup retention 7 days |
| **SG `task-manager-db-sg`** (NUEVO) | Vivo (rule PostgreSQL:5432 desde task-manager-ec2-sg — modelo referenciado) |
| DB Subnet Group `task-manager-db-subnet-group` | Vivo (sobrevivió al delete de Sesión 3) |
| MongoDB Atlas cluster `task-manager-cluster` | Vivo (M0 free, IP `3.250.88.27` añadida al allow list) |

Coste corriendo ahora mismo: **~$0.10/día de storage RDS EBS**. EC2 y RDS ambas paradas. Cero compute cobrando.

## Cambios en el repo `task-manager-api`

- Nuevo package: `src/main/java/com/mtole/taskmanager/files/` con `FileUploadService.java` y `FileUploadController.java` (con record nested `UploadResponse`).
- Nuevo YAML: `src/main/resources/application-aws.yml`.
- Eliminado: `application-aws-s3.yml` (antipatrón, no se usa).

## Lecciones operativas nuevas

1. **BOM Maven + property placeholder resolution + DI de beans conviven en un mismo constructor.** No hay conflicto — cada uno se resuelve por su mecanismo. Un constructor con `S3Client s3Client, @Value("${aws.s3.bucket}") String bucket` es sintaxis idiomática.
2. **`mvn package` sin `clean` no borra ficheros del JAR anterior.** Si eliminas o renombras un recurso en el source tree, `clean` es obligatorio. Sin `clean`, Maven asume iteración incremental sobre los mismos ficheros.
3. **`spring.autoconfigure.exclude` es blacklist superficial.** Excluye una clase pero deja las que dependen de ella. Reflejo entrenable: cuando quieras "desactivar" una autoconfig, comprueba primero si la app fue diseñada para funcionar sin ella. Si no, no la excluyas — cámbiala.
4. **Los clients del AWS SDK v2 son lazy** (consolidado de Sesión 5): el bean se construye sin llamar a AWS. La Default Credential Provider Chain se activa al **primer método real** (`putObject`), y solo entonces baja los 5 eslabones. Verificado empíricamente hoy — `Started TaskManagerApiApplication in 18.996 seconds` sin tocar S3, primer `curl` funcionó a la primera.
5. **CloudTrail es la fuente de verdad, la memoria no.** Si el diario dice "stop" pero CloudTrail dice "delete", CloudTrail gana. Regla operativa consolidada: **sesión sin diario formal → factura semanas después**. Cuando una sesión se parte en dos (parte 1 conceptual, parte 2 ejecución), ambas partes merecen diario, no solo la conceptual.
6. **Deletion protection en RDS**: fricción intencional al borrado destructivo. Reversible (se puede desactivar sin recrear). Baseline en cualquier RDS de producción.
7. **Backup retention en RDS**: 7 días por defecto en la sesión de hoy. Habría permitido restore instantáneo si Sesión 3 hubiera sido con 7 días de retention. Aprendizaje caro pero definitivo.
8. **MongoDB Atlas IP Access List es firewall independiente de AWS SG**. Cuando la app pasa de dev local (IP residencial en la lista) a EC2 (IP nueva), hay que actualizar Atlas también. Doble mantenimiento — deuda operativa apuntada para migrar a Atlas VPC Peering en Sesión 8+.

## Deuda arrastrada (nueva y consolidada)

### Deuda estratégica nueva (Sesión 6)
- **`UploadResponse` como nested private vs fichero separado** — decidir según convención global del proyecto.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location**: deuda REST idiomática menor.
- **`postgresql-client` en EC2 en v16 vs server v18**: actualizar a v18 en Sesión 7 para meta-comandos.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2**: cada `stop/start` cambia IP y hay que actualizar. Solución larga: Atlas VPC Peering con AWS. Solución media: Elastic IP fija para la EC2. Deuda operativa.
- **README de portfolio pendiente actualizar** con S3 integration.

### Deuda arrastrada de sesiones anteriores (siguen abiertas)
- ADR-A2 (Instance Profile vs access keys + SDK v2 raw vs Spring Cloud AWS).
- Verificar namespace del bucket (Regional vs Global).
- VPC `task-manage-vpc` → `task-manager-vpc` rename.
- Billing access para IAM user `tole` — activar desde root.

### Deudas cerradas hoy
- Fases 3-6 de Sesión 5 — **completadas**.
- RDS recreada from scratch con configuración robusta.

## Para retomar en Sesión 7

**Warmup (~5 min):** verificar app arranca en local con perfil `dev` (Postgres + Mongo local vía Docker), refrescar el estado de recursos AWS.

**Sesión 7 candidatos temáticos** (a decidir según prioridad):

**Opción A — Presigned URLs (Fase originalmente planeada para Sesión 5).**
Endpoint `GET /files/{key}/url` que devuelve URL firmada temporal (10 min TTL) para descarga directa cliente-a-S3 sin pasar por la app. Frontend del futuro llamaría a este endpoint y luego haría `GET` directo al S3. Concepto clave: URLs firmadas con SigV4 pre-computado, sin credenciales expuestas al cliente. ~1h.

**Opción B — VPC Endpoint Gateway para S3.**
Actualmente tráfico EC2→S3 sale por internet (Route Table → IGW → S3 público). Con VPC Endpoint Gateway, el tráfico va por red interna AWS (gratis, sin latencia inter-región, sin sobrecarga NAT). Concepto clave: PrivateLink vs Endpoint Gateway, Route Table modificada. ~1h. Deuda planeada desde Sesión 4.

**Opción C — ADR-A2 + ADR-A3 formales.**
Redactar en `cloud-roadmap/decisions/` los ADRs pendientes: Instance Profile vs access keys, RDS gestionada vs Postgres en EC2, SDK v2 raw vs Spring Cloud AWS. Es "consolidación limpia" de decisiones ya tomadas. ~1h.

Recomendación: **Opción A** — cierra el hilo pedagógico del "patrón dorado S3" con presigned URLs, que es de las preguntas más frecuentes en entrevistas Java+AWS ("¿cómo servirías descargas de ficheros a un frontend sin exponer las credenciales?").

## Meta-observaciones de método

- **El descubrimiento pedagógico del antipatrón llegó gratis por intentar la vía fácil.** El primer intento de "monolito DBless" via exclusion parecía la solución óptima (menos cambios, foco pedagógico en S3). La factura empírica del intento reveló el antipatrón mejor que cualquier blog. **Tercer caso consecutivo en el roadmap AWS** (Sesión 4: familias de ARN; Sesión 5: lazy loading SDK v2; Sesión 6: exclusion antipatrón) donde el error didáctico enseña más que el éxito directo. Ya no es coincidencia, es patrón del método.
- **La sesión duró ~3h en dos bloques**, con veterinario del gato entre medias como pausa natural. La calidad de decisiones tras la pausa fue notablemente mejor que en el último tramo del bloque de mañana (donde apareció frustración con confusión master vs application user). **Regla operativa consolidada**: en sesiones largas, forzar pausa a las ~2h y volver con cabeza fresca produce mejor resultado que empujar más tiempo continuo.
- **La confusión "master user vs application user" causó fricción emocional real**. Al pedir "empezar de cero", la reacción correcta fue simplificar radicalmente (un solo usuario `postgres`, sin GRANTs, sin `psql`), no insistir en el patrón profesional. Al aparecer el `.secrets` con la password real de `task_manager_app`, el patrón profesional se pudo ejecutar sin fricción. **Reflejo entrenable**: cuando el usuario está frustrado con complejidad, retirar complejidad; cuando aparece contexto nuevo que la simplifica, retomarla naturalmente.
- **Alarmas de seguridad falsas por leer con exceso de velocidad**: al ver el `.secrets`, la reacción inmediata fue "revoca la Anthropic API key" cuando en realidad estaba censurada con puntos suspensivos. La segunda ocasión con la password del SQL, cuando estaba con asteriscos. Reflejo para calibrar: leer dos veces antes de disparar la alarma de rotación de credenciales. Falsas alarmas erosionan confianza y meten fricción en el flow.
- **Deudas apuntadas hoy: 4 nuevas estratégicas.** Ninguna tóxica. Compárese con las Sesión 4 (3), Sesión 5 (2). Ratio deuda/entregado sanísima. Los Lannister también deben oro a bancos que no cierran hoy — pero apuntado en el libro mayor.
