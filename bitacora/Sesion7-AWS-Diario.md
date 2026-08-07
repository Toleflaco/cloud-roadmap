# Sesión 7 — AWS S3 presigned URLs para descarga directa cliente-a-S3

**Fecha:** 7 agosto 2026
**Duración:** ~2h 15min (bloque único de tarde, 17:15 – 19:30)
**Estado:** Completada. Objetivo empírico end-to-end conseguido: cliente descarga fichero directamente desde S3 con URL firmada temporal, sin `Authorization` header y sin que la app actúe de proxy. Verificado también el fallo esperado tras expiración del TTL.

## Objetivo pedagógico

Cerrar el hilo del "patrón dorado S3" con presigned URLs. Concepto central: **desplazar la firma de credenciales del header HTTP al query string de la URL**, permitiendo que un cliente descargue directamente de S3 sin exponer credenciales y sin que la aplicación consuma CPU/RAM/ancho de banda actuando de proxy.

Objetivo empírico concreto:
```
$ curl -G "http://<ec2-ip>:8080/files/download-url" \
    -H "Authorization: Bearer <token>" \
    --data-urlencode "key=2026/08/07/uuid-fichero.txt"
{
  "key": "...",
  "url": "https://<bucket>.s3.eu-west-1.amazonaws.com/...?X-Amz-Signature=...",
  "expiresAt": "2026-08-07T18:28:04Z"
}

$ curl -v "$URL"   # sin Authorization header
< HTTP/1.1 200 OK
< Server: AmazonS3
<contenido del fichero>
```

**Conseguido.** Presigned URL generada a las `18:18:04 UTC`, descarga válida ejecutada a las `18:22:33 UTC`, expiración esperada a las `18:28:04 UTC`, prueba negativa (403 AccessDenied) verificada a las `18:30:58 UTC`.

## Fase 0 — Warmup y arranque de infra

**Warmup** (~20 min): revisión del prompt de continuación de Sesión 6, decisión entre Opciones A/B/C (elegida A — presigned URLs), predicciones conceptuales sobre por qué `S3Presigner` es un bean distinto de `S3Client`, y matiz importante sobre firmar vs encriptar.

**Arranque de infra**:
- EC2 `task-manager-ec2` arrancada → nueva IP pública `54.74.2.124` (rango eu-west-1).
- RDS `task-manager-db` arrancada.
- Atlas Network Access actualizada con la nueva IP pública de la EC2.
- SG SSH+8080 no requirió cambios (misma IP residencial de casa que Sesión 6, `88.11.202.24/32`).

Primer intento de arranque de la app en EC2 falló con:
```
Caused by: java.lang.IllegalArgumentException: 'url' must start with "jdbc"
```

Diagnóstico correcto: env vars del `~/.secrets` no cargadas en la sesión SSH (SSH nuevo → shell limpio). Aplicado el patrón:

```bash
set -a
source ~/.secrets
set +a
```

- **`set -a`** — flag "allexport": todas las asignaciones posteriores se exportan automáticamente al entorno.
- **`source ~/.secrets`** — ejecuta el fichero en el shell actual (no en subshell), asignando las variables. Con `-a` activo, cada asignación se convierte en export.
- **`set +a`** — desactiva el allexport para no ensuciar el resto de la sesión.

Sin `set -a`/`set +a`, si el fichero de secretos no lleva `export` explícito en cada línea, las variables quedan solo en el shell y NO se propagan a procesos hijos (Java). Gotcha clásico de bash.

Frase para entrevista:
> *"Un shell SSH nuevo hereda solo el entorno mínimo definido por PAM y `/etc/environment`. Los secretos en `~/.secrets` requieren `source` explícito antes de arrancar procesos que dependan de ellos, y `set -a` para forzar export al proceso hijo."*

## Concepto central: `S3Presigner` vs `S3Client`

Pregunta de arranque de la sesión: *"¿por qué `S3Presigner` es un bean distinto en vez de reutilizar el `S3Client` ya inyectado?"*

Respuesta consolidada:

- **`S3Client` es un cliente de red.** Cuando ejecuta `putObject(request, body)`, hace una petición HTTPS real a `https://s3.eu-west-1.amazonaws.com/...`, con el fichero en el body, esperando respuesta HTTP. **Es operación de red bidireccional real.**
- **`S3Presigner` no habla con S3 nunca.** Cuando ejecuta `presignGetObject(request)`, no sale un solo byte hacia AWS. Coge las credenciales que tiene en memoria (Instance Profile), aplica el algoritmo AWS Signature V4 localmente (HMAC-SHA256, canonical request, string-to-sign, hex encoding), y devuelve un string con la URL firmada. **Es puro cálculo local.**

Analogía consolidada:
> *"El `S3Presigner` es un notario que firma un documento en su despacho. No necesita llamar a nadie para firmar, solo su sello (las credenciales) y saber qué firma (bucket, key, método, TTL). El resultado es un papel firmado (la URL) que puedes darle a quien quieras. Cuando ese alguien (el navegador del cliente) presenta el papel en la ventanilla de S3, S3 mira la firma, comprueba que es válida y que no ha expirado, y sirve el fichero."*

Consecuencias operativas:
1. **Sin red = sin fallo de red posible.** Si la EC2 perdiera conectividad a internet en el momento de generar la URL, el endpoint respondería igualmente correcto. Verificado conceptualmente.
2. **El bean tiene distinto ciclo de vida y distintos modos de fallo.** `S3Client` puede fallar por timeout, credenciales revocadas, 5xx del backend. `S3Presigner` solo puede fallar por parámetros inválidos (TTL negativo, key nula) o credenciales locales corruptas.
3. **Justificación arquitectónica de la separación:** AWS SDK v2 los diseñó como beans independientes precisamente porque son responsabilidades ortogonales que comparten solo el mecanismo de credenciales.

Frase para entrevista:
> *"En AWS SDK v2, `S3Client` es un cliente de red que ejecuta operaciones HTTP contra el servicio; `S3Presigner` calcula firmas AWS SigV4 localmente sin salir a red. Ambos usan la Default Credential Provider Chain pero son beans independientes porque son responsabilidades distintas con modos de fallo distintos. Diseño análogo a `KMSClient` vs `KMSKeyMaterial`."*

## Concepto central: firmar ≠ encriptar

Matiz clave importado en respuesta a interpretación imprecisa en el warmup ("la firma está encriptada con SigV4"). Diferencia consolidada:

- **Encriptar** = transformar datos legibles en ilegibles con una clave, para que solo quien tenga la clave (o su complementaria) pueda revertirlo. Objetivo: **confidencialidad**.
- **Firmar** = calcular un hash criptográfico de los datos usando una clave secreta, y adjuntar ese hash. Objetivo: **autenticidad e integridad**.

**La URL firmada NO está encriptada.** Cualquiera que la intercepte puede leer perfectamente el bucket, la key, la fecha de expiración, el algoritmo, todo, en texto plano en los query params. Lo único "secreto" es que solo tu app (con las credenciales del Instance Profile) podía haber calculado ese valor concreto de `X-Amz-Signature` para esa combinación exacta de bucket + key + fecha + TTL + headers firmados. Si alguien altera un solo carácter de la URL, la firma deja de cuadrar y S3 devuelve `AccessDenied`.

Frase para entrevista:
> *"Las presigned URLs no ocultan información, garantizan autenticidad. La URL entera es pública y legible; lo que la hace segura es que la firma AWS SigV4 solo puede haberla generado alguien con las credenciales, y cualquier alteración del resto de la URL invalida la firma."*

## Fase 1 — Bean `S3Presigner` en `S3Config`

Añadido en `S3Config.java`, junto al bean `S3Client` existente:

```java
@Bean(destroyMethod = "close")
public S3Presigner s3Presigner() {
    return S3Presigner.builder()
            .region(Region.EU_WEST_1)
            .build();
}
```

Decisiones:

- **Sin `credentialsProvider(...)` explícito.** Delegación a la Default Credential Provider Chain, mismo mecanismo que el `S3Client`. En EC2 resuelve a Instance Profile vía IMDSv2 en el 5º eslabón. Coherencia con el patrón dorado.
- **`destroyMethod = "close"`.** El `S3Presigner` implementa `SdkAutoCloseable`, y Spring lo cerraría automáticamente al detectar `AutoCloseable`/`Closeable` (default `destroyMethod = "(inferred)"`). La declaración explícita es **redundante pero documental**: sirve como documentación viva de qué método se llama al destruir el bean. Ambas formas son idiomáticas.
- **Sin parámetros de entrada al método `@Bean`.** Un intento inicial de firmar `public S3Presigner s3Presigner(SdkAutoCloseable sdkAutoCloseable)` fue error didáctico — el parámetro no se usaba en el cuerpo y le pedía a Spring inyectar un bean de una interfaz que muchos objetos del SDK implementan. Antipatrón de "Spring adivina qué quiero inyectar". Corregido antes de compilar.

Error didáctico útil: **la anotación `@Bean(destroyMethod = "close")` NO obliga a que el parámetro sea el objeto a destruir.** Spring introspecta el bean **devuelto**, no los parámetros. Confusión resuelta antes de tocar el compilador.

## Fase 2 — Record `PresignedUrlResponse`

Fichero nuevo `PresignedUrlResponse.java` en `com.mtole.taskmanager.files`:

```java
public record PresignedUrlResponse(
        String key,
        String url,
        Instant expiresAt
) {}
```

### Decisiones de diseño

- **Fichero separado, no nested private.** Convención local: los DTOs de request/response que cruzan la frontera HTTP son públicos y viven en el package de la feature, para consistencia con futuros consumidores (frontend, tests de integración externos).
- **`Instant` para `expiresAt`, no `OffsetDateTime` ni `Duration`.**
  - `Duration` habría sido una cantidad ("dura 10 minutos") — obligaría al cliente a hacer aritmética contra su reloj local en el momento de recepción, arrastrando el latency de red.
  - `OffsetDateTime` habría transmitido información de zona horaria del servidor — irrelevante, S3 opera en UTC internamente.
  - **`Instant` es un punto absoluto en la línea de tiempo global**, sin zona horaria, sin ambigüedad. El cliente hace `expiration.isAfter(Instant.now())` y sabe si sigue viva.
- **Naming inglés convención `-At` para timestamps futuros:** `expiresAt`, análogo a `createdAt`, `updatedAt`, `deletedAt`. Convención Spring/Jackson estándar.
- **Sin campo `signature` separado.** La firma ya viaja **dentro** de la URL como query param `X-Amz-Signature`. Devolverla aparte sería duplicar información sin uso para el cliente.

Frase para entrevista:
> *"Para expresar caducidad en APIs prefiero instantes absolutos sobre duraciones relativas. La duración obliga al cliente a hacer aritmética contra su reloj local en el momento de recepción, arrastrando el latency de red; el instante absoluto elimina esa ambigüedad. El reloj del servidor es la fuente de verdad, el cliente solo compara."*

## Fase 3 — Método `generateDownloadUrl` en `FileUploadService`

Añadido al service existente, junto al método `upload(MultipartFile)`:

```java
public PresignedUrlResponse generateDownloadUrl(String key, Duration ttl) {
    // 1. Describe la operación pura: "GET del objeto K del bucket B"
    GetObjectRequest objectRequest = GetObjectRequest.builder()
            .bucket(bucket)
            .key(key)
            .build();

    // 2. Envuelve la operación con opciones de firmado
    GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
            .signatureDuration(ttl)
            .getObjectRequest(objectRequest)
            .build();

    // 3. Firma (puro cálculo local, sin red)
    PresignedGetObjectRequest presigned = s3Presigner.presignGetObject(presignRequest);

    // 4. Empaqueta URL + expiración en DTO
    return new PresignedUrlResponse(
            key,
            presigned.url().toString(),
            presigned.expiration()
    );
}
```

### Patrón matrioska del SDK v2 (consolidado)

AWS SDK v2 usa un **request anidado**:
- **`GetObjectRequest`** — describe la operación pura ("bucket, key, opcionales de range"). Es la MISMA clase que usarías con `S3Client.getObject(request)` para ejecutar la descarga real.
- **`GetObjectPresignRequest`** — envuelve al anterior y le añade opciones específicas de firmado (`signatureDuration`).

```
GetObjectPresignRequest             ← "cómo firmar"
    ├── signatureDuration           ← TTL
    └── GetObjectRequest            ← "qué firmar"
            ├── bucket
            └── key
```

El objeto exterior es **meta** (habla de la firma), el interior es **sustancia** (habla de la operación real). Justificación de la separación:

1. **Reutilización de la descripción de operación.** `GetObjectRequest` sirve tanto para ejecutar (`S3Client`) como para firmar (`S3Presigner`), garantizando cero divergencia semántica.
2. **Escalabilidad del patrón.** Cada operación firmable tiene su pareja: `PutObjectRequest` + `PutObjectPresignRequest`, `DeleteObjectRequest` + `DeleteObjectPresignRequest`, etc. Uniforme.
3. **Separación de responsabilidades.** Las opciones de firmado (TTL, headers firmados) son ortogonales a las opciones de la operación (bucket, key, range, if-match).

### Predicción validada

Anticipada correctamente por analogía: para firmar una **subida**, el patrón sería `PutObjectPresignRequest` que envuelve `PutObjectRequest`. Prueba de que el patrón se ha interiorizado como estructura general, no como fórmula memorizada del caso GET.

### Salida del método `presign` — dos campos útiles

`PresignedGetObjectRequest` expone:
- **`.url()`** — devuelve `java.net.URL`, hay que hacer `.toString()` para exponer en JSON.
- **`.expiration()`** — devuelve un `Instant` ya calculado (mismo reloj que usó el presigner para la firma). **No hace falta calcular `Instant.now().plus(ttl)` manualmente.**

Frase para entrevista:
> *"AWS SDK v2 usa un patrón de request anidado para presign: `GetObjectRequest` describe la operación (misma clase que ejecutaría `S3Client.getObject`), y `GetObjectPresignRequest` la envuelve con opciones específicas de firmado como el TTL. Esta separación permite reutilizar la misma descripción de operación tanto para ejecución real como para firmado, sin divergencia."*

## Fase 4 — Endpoint `GET /files/download-url`

Añadido al `FileUploadController` existente:

```java
private final Duration downloadUrlTtl;

public FileUploadController(FileUploadService fileUploadService,
                            @Value("${aws.s3.presign.download-ttl}") Duration downloadUrlTtl) {
    this.fileUploadService = fileUploadService;
    this.downloadUrlTtl = downloadUrlTtl;
}

@GetMapping("/download-url")
public PresignedUrlResponse getFile(@RequestParam String key) {
    return fileUploadService.generateDownloadUrl(key, downloadUrlTtl);
}
```

### Decisión 1 — key como `@RequestParam`, no `@PathVariable`

Primer intento de firma: `@GetMapping("/{key}/url")` con `@PathVariable String key`.

**Problema empírico anticipado**: las keys tienen forma `2026/08/07/uuid-fichero.txt`, con **barras internas**. Spring interpreta cada `/` como separador de segmento por defecto — `{key}` solo captura un segmento. La URL `GET /files/2026/08/07/uuid-fichero.txt/url` no matchea contra el patrón `/files/{key}/url` y cae al `ResourceHttpRequestHandler` (que busca ficheros estáticos y devuelve `NoResourceFoundException`).

**Soluciones evaluadas**:
- **Opción A (elegida)**: `@GetMapping("/download-url")` + `@RequestParam String key`. Query param URL-decodifica automáticamente los `/` sin problema. Idiomático REST para recursos con identificadores complejos.
- **Opción B (descartada)**: `@GetMapping("/{key:.+}/url")` — hack de patrón regex para capturar más de un segmento. Feo y rompe la semántica de path variable.

**Trampa didáctica real vivida en la sesión**: primera petición al endpoint devolvió 500 con `ProblemDetail` genérico. Diagnóstico inicial equivocado por mi parte (hipótesis: `key` null, bean mal configurado, TTL mal parseado). El logging real mostró:
```
NoResourceFoundException: No static resource files/download-url
```
Diagnóstico corregido: **el JAR desplegado en la EC2 era el de la Sesión 6** (`Aug 6 18:20`), no tenía el endpoint nuevo. Faltó el paso `./mvnw clean package && scp` tras el cambio de código.

Frase para entrevista:
> *"El ciclo edit → compile → deploy → restart es la primera fuente de bugs falsos en desarrollo remoto. Si el comportamiento no cambia tras un fix, verifica siempre en este orden: (1) fecha de modificación del artifact desplegado, (2) que el proceso lo cargó tras el reemplazo, (3) que el proceso corresponde a la versión desplegada. En CI/CD serio esto se elimina con builds inmutables identificados por hash o versión."*

Conexión pedagógica: exactamente lo que un `Deployment` de Kubernetes con `image: myapp:sha-abc123` (no `myapp:latest`) previene por diseño. Deuda anotada para el módulo K8s.

### Decisión 2 — TTL externalizado en `application.yml` como `Duration`

Añadido al `application-aws.yml` (y `application-dev.yml` con el mismo valor por coherencia):

```yaml
aws:
  s3:
    bucket: toleflaco-task-manager-uploads-2026
    presign:
      download-ttl: 10m
```

Y en el controller:
```java
@Value("${aws.s3.presign.download-ttl}") Duration downloadUrlTtl
```

**Gotcha resuelto**: Spring Boot parsea `10m` como `Duration.ofMinutes(10)` automáticamente (soporta sufijos `ns`, `us`, `ms`, `s`, `m`, `h`, `d`). Sin sufijo, `10` se interpreta como **10 milisegundos**, no 10 minutos — bug silencioso peligroso. Alternativas descartadas:
- ISO-8601 `PT10M` — funciona pero menos legible.
- Propiedad `download-ttl-minutes: 10` con `long` en Java + `Duration.ofMinutes(...)` manual — hace la conversión explícita, pierde elegancia.

Frase para entrevista:
> *"Spring Boot soporta unidades sufijadas (`10m`, `30s`, `1h`) para inyectar `Duration` desde properties, más legible que ISO-8601 y sin conversión manual. Sin sufijo, un número desnudo se interpreta como milisegundos — bug silencioso peligroso en configuración de tiempos."*

### Decisión 3 — `@Value` como campo inyectado en constructor, no como parámetro de handler

Primer intento: `@Value` **como parámetro del método handler**:
```java
public PresignedUrlResponse getFile(@RequestParam String key,
                                     @Value("${aws.s3.presign.download-ttl}") Duration ttl) { ... }
```

**Antipatrón**. Los parámetros de handlers Spring MVC vienen de la request HTTP (`@RequestParam`, `@PathVariable`, `@RequestBody`, `@RequestHeader`), no de configuración. El TTL es **configuración del bean, no de la petición**.

Corrección: inyección por constructor como campo `private final Duration downloadUrlTtl`, reusado en cada petición. Idiomático Spring.

## Verificación empírica end-to-end

### Bloque de pruebas desde WSL local (simulando cliente real)

```bash
# 1. Login
JWT=$(curl -s -X POST http://54.74.2.124:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"tole@test.com","password":"..."}' \
  | jq -r '.accessToken')
# JWT length: 125 ✓

# 2. Subida
KEY=$(curl -s -X POST http://54.74.2.124:8080/files \
  -H "Authorization: Bearer $JWT" \
  -F "file=@/tmp/test-presigned.txt" \
  | jq -r '.key')
# Key devuelta: 2026/08/07/68738370-b52b-4ef1-b9f8-36d6bde40f5e-test-presigned.txt ✓

# 3. Generación de presigned URL
RESPONSE=$(curl -s -G "http://54.74.2.124:8080/files/download-url" \
  -H "Authorization: Bearer $JWT" \
  --data-urlencode "key=$KEY")
```

Respuesta obtenida:
```json
{
  "key": "2026/08/07/68738370-...-test-presigned.txt",
  "url": "https://toleflaco-task-manager-uploads-2026.s3.eu-west-1.amazonaws.com/2026/08/07/...?X-Amz-Security-Token=IQoJb3JpZ2luX2VjEJL...&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260807T181804Z&X-Amz-SignedHeaders=host&X-Amz-Credential=ASIA25NXFS4OOTU7KIBH/20260807/eu-west-1/s3/aws4_request&X-Amz-Expires=600&X-Amz-Signature=30b2bfbff31d6da75d2789ecc64a86ed677c9136e1a578b4432773d2912c98bf",
  "expiresAt": "2026-08-07T18:28:04.932620585Z"
}
```

### Anatomía de la URL firmada (crítica para entrevista)

Descomposición de cada query param:

| Query param | Valor observado | Significado |
|---|---|---|
| `X-Amz-Algorithm` | `AWS4-HMAC-SHA256` | Signature V4 con HMAC-SHA256, estándar AWS actual |
| `X-Amz-Date` | `20260807T181804Z` | Momento de firma (UTC ISO comprimido) |
| `X-Amz-Expires` | `600` | TTL en segundos = 10 min (coincide con `signatureDuration`) |
| `X-Amz-SignedHeaders` | `host` | Headers HTTP incluidos en el cálculo de la firma |
| `X-Amz-Credential` | `ASIA25NXFS4OOTU7KIBH/20260807/eu-west-1/s3/aws4_request` | Scope: credencial, fecha, región, servicio |
| `X-Amz-Security-Token` | `IQoJb3JpZ2luX2Vj...` | Token STS asociado a la credencial temporal |
| `X-Amz-Signature` | `30b2bfbff31d6da...` | HMAC final (64 hex chars = 256 bits = SHA-256) |

### El "aha" del prefijo `ASIA` — prueba empírica del Instance Profile

**Access keys clásicas de IAM User empiezan por `AKIA`.** Ejemplo: `AKIAIOSFODNN7EXAMPLE`.
**Credenciales temporales de STS empiezan por `ASIA`.** Ejemplo: `ASIA25NXFS4OOTU7KIBH`.

La URL firmada lleva `ASIA...` **y** `X-Amz-Security-Token`. Significa empíricamente y sin ambigüedad:
1. La app **no usó access keys** para firmar (habría sido `AKIA`).
2. La app **consultó IMDSv2**, obtuvo credenciales temporales STS asociadas al rol `task-manager-ec2-role`, y firmó con ellas.
3. Esas credenciales **rotan solas** cada varias horas — AWS las regenera y el SDK las actualiza en background. Si alguien roba esta URL, deja de funcionar cuando STS rote el token asociado (además del TTL de 10 min).

**Todo el patrón dorado que llevas dos sesiones montando está codificado en el prefijo de tres letras de esa credencial.** Se puede auditar sin correr un solo comando extra: lees `ASIA` en la URL, sabes que fue Instance Profile.

Frase para entrevista:
> *"En una URL presigned de S3, el prefijo del `X-Amz-Credential` te dice qué mecanismo firmó: `AKIA` es access key permanente de IAM User (mal patrón para servicios), `ASIA` es credencial temporal de STS obtenida vía Instance Profile o AssumeRole (patrón correcto para EC2/ECS/EKS/Lambda). El `X-Amz-Security-Token` acompaña siempre a las temporales."*

Frase para entrevista:
> *"El Instance Profile no cachea credenciales permanentes: consulta STS on demand y el AWS SDK v2 refresca automáticamente vía background thread antes de que caduquen. Si el rol se revoca en IAM, las URLs pre-firmadas dejan de funcionar cuando la firma expira o el token es invalidado — ese doble mecanismo es la razón por la que este patrón es el estándar en producción."*

### Descarga válida — `curl -v "$URL"` a los `18:22:33 UTC`

**Petición HTTP capturada** (headers `>` = salida, `<` = entrada):

```
> GET /2026/08/07/...?X-Amz-Signature=... HTTP/1.1
> Host: toleflaco-task-manager-uploads-2026.s3.eu-west-1.amazonaws.com
> User-Agent: curl/7.81.0
> Accept: */*
```

**Fíjate en lo que NO hay**: cero `Authorization` header, cero credenciales convencionales. La firma va **en la URL misma**, no en un header. Eso es la esencia de las presigned URLs.

**Respuesta capturada**:
```
< HTTP/1.1 200 OK
< x-amz-request-id: JHB8RA6WRBM6AGWB
< Content-Type: text/plain
< Content-Length: 66
< Server: AmazonS3
< x-amz-server-side-encryption: AES256
```

Observaciones clave:
- **`Server: AmazonS3`**, no Tomcat. La petición **no pasa por la EC2**, va directa a S3.
- **`x-amz-server-side-encryption: AES256`** — objeto cifrado en reposo con SSE-S3 (configurado en Sesión 4). Cifrado doble: **TLS en tránsito** + **SSE-S3 en reposo**. Requisito estándar en auditoría de banking/fintech.
- **IP de destino `3.5.67.194`** — rango público de S3 en eu-west-1, no la IP de la EC2.

Contenido recibido = contenido subido en el paso 2. Round-trip completo verificado.

### Descarga expirada — `curl -v "$URL"` a los `18:30:58 UTC`

Mismo `curl`, misma URL, 8 minutos después de expiración. Respuesta:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>AccessDenied</Code>
  <Message>Request has expired</Message>
  <X-Amz-Expires>600</X-Amz-Expires>
  <Expires>2026-08-07T18:28:04Z</Expires>
  <ServerTime>2026-08-07T18:30:59Z</ServerTime>
  <RequestId>2T5NJDVJ2QDYCSKT</RequestId>
</Error>
```

HTTP status: `403 Forbidden`. S3 literalmente compara `ServerTime > Expires` y deniega. **Prueba empírica de que S3 hace enforcement activo del TTL, no es decorativo.** Los cuatro estados del ciclo de vida de una presigned URL verificados: firma, descarga válida dentro de ventana, expiración, descarga inválida fuera de ventana.

Frase para entrevista:
> *"Implementé presigned URLs para descarga directa de S3 desde el cliente. La API genera una URL firmada con TTL de 10 minutos usando credenciales temporales de STS obtenidas vía Instance Profile, y el cliente descarga directamente de S3 sin que la app actúe de proxy. Verifiqué que la petición del cliente no lleva `Authorization` header — la firma va en el query string — y que responde el propio S3 con `Server: AmazonS3`, no la aplicación. Tras el TTL, S3 devuelve 403 AccessDenied con `Request has expired`."*

Frase para entrevista:
> *"El patrón evita tres antipatrones típicos: (1) exponer credenciales al cliente, (2) que el backend actúe como proxy consumiendo CPU/RAM/ancho de banda en tráfico que S3 puede servir mejor, (3) doble transferencia de red S3→backend→cliente. Escala mejor que servir binarios desde tu API."*

## Frases ⭐⭐⭐ para entrevistas (consolidadas)

1. **"`S3Client` es cliente de red; `S3Presigner` calcula firmas SigV4 localmente sin salir a red. Ambos usan la Default Credential Provider Chain pero son beans independientes porque son responsabilidades distintas con modos de fallo distintos."**

2. **"Las presigned URLs no ocultan información, garantizan autenticidad. La URL entera es pública y legible; lo que la hace segura es que la firma AWS SigV4 solo puede haberla generado alguien con las credenciales, y cualquier alteración del resto de la URL invalida la firma."**

3. **"Para expresar caducidad en APIs prefiero instantes absolutos sobre duraciones relativas. La duración obliga al cliente a hacer aritmética contra su reloj local en el momento de recepción, arrastrando latency de red; el instante absoluto elimina esa ambigüedad."**

4. **"AWS SDK v2 usa un patrón de request anidado para presign: `GetObjectRequest` describe la operación pura (misma clase que ejecutaría `S3Client.getObject`), y `GetObjectPresignRequest` la envuelve con opciones específicas de firmado como el TTL. Esta separación permite reutilizar la misma descripción de operación tanto para ejecución real como para firmado."**

5. **"En una URL presigned de S3, el prefijo del `X-Amz-Credential` te dice qué mecanismo firmó: `AKIA` es access key permanente de IAM User (mal patrón para servicios), `ASIA` es credencial temporal de STS obtenida vía Instance Profile o AssumeRole (patrón correcto para EC2/ECS/EKS/Lambda). El `X-Amz-Security-Token` acompaña siempre a las temporales."**

6. **"Spring Boot soporta unidades sufijadas (`10m`, `30s`, `1h`) para inyectar `Duration` desde properties, más legible que ISO-8601 y sin conversión manual. Sin sufijo, un número desnudo se interpreta como milisegundos — bug silencioso peligroso."**

7. **"El ciclo edit → compile → deploy → restart es la primera fuente de bugs falsos en desarrollo remoto. Si el comportamiento no cambia tras un fix, verifica en este orden: (1) fecha de modificación del artifact desplegado, (2) que el proceso lo cargó tras el reemplazo, (3) que el proceso corresponde a la versión desplegada. En CI/CD serio esto se elimina con builds inmutables identificados por hash."**

8. **"El patrón presigned URL evita tres antipatrones: exponer credenciales al cliente, que el backend actúe como proxy consumiendo CPU/RAM/ancho de banda, y la doble transferencia S3→backend→cliente. Escala mejor que servir binarios desde tu API."**

## Recursos AWS al final de la sesión

| Recurso | Estado final |
|---|---|
| S3 Bucket `toleflaco-task-manager-uploads-2026` | Vivo, con `test-upload.txt` (S4) + `2026/08/06/uuid-prueba.txt` (S6) + `2026/08/07/uuid-test-presigned.txt` (S7) |
| IAM Policy `task-manager-s3-uploads-rw` | Vivo |
| IAM Role `task-manager-ec2-role` | Vivo |
| Instance Profile `task-manager-ec2-role` | Vivo |
| EC2 `task-manager-ec2` | **Stopped** |
| SG `task-manager-ec2-sg` | Vivo (rules SSH:22 y HTTP:8080 desde 88.11.202.24/32) |
| RDS `task-manager-db` | **Stopped**. PostgreSQL 18.3, db.t4g.micro, 20 GB, deletion protection ON, backup retention 7 days |
| SG `task-manager-db-sg` | Vivo (rule PostgreSQL:5432 desde task-manager-ec2-sg — modelo referenciado) |
| DB Subnet Group `task-manager-db-subnet-group` | Vivo |
| MongoDB Atlas cluster `task-manager-cluster` | Vivo (M0 free, IP `54.74.2.124` añadida al allow list) |

Coste corriendo ahora mismo: **~$0.10/día de storage RDS EBS**. EC2 y RDS ambas paradas. Cero compute cobrando.

## Cambios en el repo `task-manager-api`

- Modificado `S3Config.java`: añadido bean `S3Presigner` con `destroyMethod = "close"`.
- Nuevo fichero `PresignedUrlResponse.java` en `com.mtole.taskmanager.files`.
- Modificado `FileUploadService.java`: nuevo campo `S3Presigner s3Presigner` inyectado por constructor, nuevo método público `generateDownloadUrl(String key, Duration ttl)`.
- Modificado `FileUploadController.java`: nuevo campo `Duration downloadUrlTtl` inyectado por constructor con `@Value`, nuevo endpoint `GET /download-url` con `@RequestParam String key`.
- Modificado `application-aws.yml`: nueva propiedad `aws.s3.presign.download-ttl: 10m`.
- Modificado `application-dev.yml`: mismo valor de la propiedad para coherencia entre perfiles.

Commit único con mensaje bilingüe siguiendo Conventional Commits: `feat(files): add presigned URL endpoint for S3 downloads`.

## Lecciones operativas nuevas

1. **`set -a; source ~/.secrets; set +a` es el patrón para cargar env vars a un proceso hijo sin editar el fichero de secretos.** Sin `set -a`, las asignaciones se quedan en el shell y no se propagan. Verificable con `echo "DB_URL=[$DB_URL]"` — corchetes vacíos = variable no exportada.
2. **El JAR desplegado en EC2 NO se actualiza solo.** Ciclo obligatorio tras cada cambio de código: `./mvnw clean package -DskipTests` en WSL → `scp` a EC2 → `pkill -f task-manager-api` → relanzar con `set -a; source; set +a; java -jar`. Diagnóstico rápido de "JAR viejo" via `ls -la ~/task-manager-api-*.jar` comparado con la hora actual.
3. **Spring Boot devuelve `NoResourceFoundException` cuando un endpoint no está registrado.** El request cae al `ResourceHttpRequestHandler` como último recurso (busca ficheros estáticos con ese path). Es una pista útil de diagnóstico: **si aparece este error, el mapping no existe** — no que Spring esté rompiéndose por dentro. Muchas veces indica JAR desactualizado o typo en el `@GetMapping`.
4. **`@Value` en parámetros de handler es antipatrón.** Los parámetros de `@GetMapping`/`@PostMapping` vienen de la request HTTP, no de configuración. La configuración se inyecta en el constructor como campo `private final`. La regla general: si el valor NO cambia por petición, no debe llegar como parámetro del handler.
5. **Spring parsea `10m` como `Duration.ofMinutes(10)` automáticamente**, pero `10` desnudo lo interpreta como **milisegundos**. Siempre incluir la unidad sufijada en properties tipo `Duration`.
6. **El `destroyMethod` en `@Bean` es documental/redundante cuando el bean implementa `AutoCloseable`.** Spring lo detecta y llama a `close()` automáticamente (default `(inferred)`). Declararlo explícitamente es válido y sirve como documentación viva de la contract del bean, pero no cambia el comportamiento en este caso.
7. **La misma IP residencial mantiene abierto el SG entre sesiones si no cambia el ISP.** Verificable con `curl -s ifconfig.me` en WSL antes de arrancar la EC2. Ahorra el paso "actualizar SG SSH+8080".

## Deuda arrastrada (nueva y consolidada)

### Deuda nueva (Sesión 7)
- **`FileUploadController` es un god controller** — mezcla upload y presigned URL. Aceptable con 2 endpoints, revisar si crece a 5+.
- **Tests unitarios/integración del nuevo endpoint no escritos.** Deuda de testing planeada para Fase 8 o sesión dedicada. `@MockBean` para `S3Presigner`, `@WebMvcTest` para el controller.
- **README de portfolio pendiente actualizar** con la funcionalidad de presigned URLs (deuda arrastrada de S6, ampliada).

### Deuda arrastrada de sesiones anteriores (siguen abiertas)
- ADR-A2 (Instance Profile vs access keys + SDK v2 raw vs Spring Cloud AWS) — pendiente redactar en `cloud-roadmap/decisions/`.
- ADR-A3 (RDS gestionada vs Postgres en EC2) — pendiente redactar.
- Verificar namespace del bucket (Regional vs Global).
- VPC `task-manage-vpc` → `task-manager-vpc` rename.
- Billing access para IAM user `tole` — activar desde root.
- **`postgresql-client` en EC2 en v16 vs server v18** — meta-comandos `\l` fallan.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2** — Elastic IP fija (solución media) o Atlas VPC Peering (solución larga).
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location** — deuda REST idiomática menor.
- **`UploadResponse` como nested private record** — revisar convención global del proyecto.

### Deudas cerradas hoy
- Opción A del prompt de continuación (Presigned URLs) — **completada**.

## Para retomar en Sesión 8

**Warmup (~5 min):** arrancar EC2 + RDS + Atlas (nueva IP), verificar app arranca con perfil `aws`.

**Sesión 8 candidatos temáticos** (a decidir según prioridad):

**Opción A — VPC Endpoint Gateway para S3.**
Actualmente tráfico EC2→S3 sale por internet (Route Table → IGW → S3 público). Con VPC Endpoint Gateway, va por red interna AWS (gratis, sin latencia inter-región, sin sobrecarga NAT). Concepto clave: PrivateLink vs Endpoint Gateway, Route Table modificada. ~1h. Deuda planeada desde S4.

**Opción B — ADR-A2 + ADR-A3 formales.**
Redactar en `cloud-roadmap/decisions/` los ADRs pendientes: Instance Profile vs access keys + SDK v2 raw vs Spring Cloud AWS, RDS gestionada vs Postgres en EC2. Consolidación limpia de decisiones ya tomadas. ~1h.

**Opción C — CloudWatch Logs para la app Spring Boot.**
Actualmente los logs de la app viven en `~/app.log` de la EC2 y se pierden al terminar la instancia. Integración con CloudWatch Logs Agent para envío en tiempo real. Concepto clave: Log Groups, Log Streams, retention policies, IAM permissions para la EC2. ~1.5h. Primera pieza del bloque de observabilidad.

**Opción D — Presigned URLs para upload directo cliente-a-S3.**
Análogo a lo de hoy pero con `PutObjectPresignRequest`. El cliente subiría directamente a S3 sin mandar el fichero a la EC2. Concepto clave: cliente debe declarar `Content-Type` y `Content-Length` firmados. ~1h. Cierra el simétrico del patrón de hoy.

Recomendación: **Opción B** para consolidar decisiones antes de que se acumulen más, seguida de **Opción A** cuando esté fresca la memoria del patrón de red actual.

## Meta-observaciones de método

- **Predicciones antes de código funcionaron mejor que en sesiones anteriores.** Tres predicciones acertadas (patrón matrioska para PutObject, `Instant` vs `Duration` para la comunicación con cliente, expiración enforced por S3) sugieren que la interiorización del método socrático está madurando. Corolario: cuando se responde "no tengo ni idea, y si te digo otra cosa te miento", la explicación posterior aterriza mucho mejor que después de una respuesta inventada. Meta-regla operativa: **cuando no lo sabes, decirlo cuesta menos que fingir y ahorra tiempo de corrección**.
- **Sesión vespertina de 2h completó objetivo A entero.** Coherente con la regla de 4h/día y el patrón "sesiones vespertinas más ligeras" — la carga cognitiva de hoy fue conceptual pero contenida, sin conceptos completamente nuevos (Instance Profile ya estaba consolidado, patrón matrioska es análogo al `PutObjectRequest` de ayer). Contraste con S6 (3h + dos bloques): S7 fue single-block porque el "puente pedagógico" ya estaba tendido.
- **El `NoResourceFoundException` es didácticamente valioso.** Mi diagnóstico inicial equivocado (bean mal, TTL mal, key null) fue humillante rápidamente por los logs reales. Cuarta vez consecutiva en el roadmap AWS (S4 familias de ARN, S5 lazy loading SDK v2, S6 exclusion antipatrón, S7 JAR viejo) donde el error empírico enseña una regla operativa concreta que no llega en libros. **Patrón confirmado: no soltar el diagnóstico "sin ver logs".**
- **Cuatro correcciones didácticas en fase de código, ninguna tóxica**: (1) parámetro innecesario `SdkAutoCloseable` en el `@Bean`, (2) intento de path variable con `/`, (3) `@Value` como parámetro de handler, (4) intento de envolver `PresignedUrlResponse` en `new PresignedUrlResponse(...)` en el controller. Todas corregidas a la primera tras identificarlas. Ninguna arrastrada a producción (bueno, a la EC2). Ratio corrección/error saludable.
- **Deudas nuevas hoy: 3 estratégicas menores**. Compárese con S4 (3), S5 (2), S6 (4). Ratio deuda/entregado sanísima y estable. Sin deuda tóxica identificada.
