# Sesión 5 — AWS SDK for Java v2: preparando Spring Boot para hablar con S3

**Fecha:** 5 agosto 2026
**Duración:** ~1h10min
**Estado:** Completada parcialmente (Fases 1–2 de 6). Fases 3–6 → Sesión 6.

## Objetivo pedagógico

Empezar el patrón dorado de "backend Java en AWS": una app Spring Boot integra el AWS SDK v2 y accede a S3 sin credenciales, apoyándose en el IAM Role adjunto a EC2 de la Sesión 4.

Arco pedagógico dividido en 6 fases:

- **Fase 1** — Dependencias (BOM + s3). ✓ Completada.
- **Fase 2** — Bean `S3Client` con region únicamente. ✓ Completada.
- **Fase 3** — `FileUploadService` con `putObject`. → Sesión 6.
- **Fase 4** — REST Controller `POST /files`. → Sesión 6.
- **Fase 5** — Deploy en EC2 + verificación empírica end-to-end. → Sesión 6.
- **Fase 6** — Diario y cleanup. Este documento cubre 1–2; el resto en Sesión 6.

## Decisión: SDK v2 raw vs Spring Cloud AWS

Elegido **AWS SDK for Java v2 raw** (`software.amazon.awssdk`). Razones:

1. **Aprendizaje limpio**: registro yo el `S3Client` como bean; veo qué le paso y qué omito. Cinco líneas de Java bajo control.
2. **Es lo que preguntan en entrevistas** Java+AWS senior. La respuesta esperada a *"cómo integraste S3"* empieza con `S3Client.builder().region(...).build()`, no con `spring.cloud.aws.s3.enabled=true`.
3. **Spring Cloud AWS es un envoltorio útil cuando hay 3+ servicios AWS** (S3 + DynamoDB + SQS...). Con solo S3, el ahorro es una línea a cambio de perder visibilidad. Trade-off malo para el momento pedagógico actual.

Reconsiderable en el futuro si un proyecto añade varios servicios. Pendiente registrar esta decisión secundaria en ADR-A2.

## Fase 1 — Dependencia AWS SDK v2 con BOM

### Por qué BOM y no versión suelta

El SDK v2 son ~200 jars (`s3`, `sts`, `dynamodb`, `auth`, `regions`, `http-client-*`, etc). Todos deben estar en la **misma versión coherente**. Sin BOM, Maven puede resolver `s3:2.51.0` pero `sts:2.28.0` por transitivas de otras librerías → `NoSuchMethodError` en runtime. Debug horrible.

El BOM garantiza coherencia: importas versiones en un solo sitio, todos los módulos del SDK las heredan.

### Sintaxis del BOM en `<dependencyManagement>`

```xml
<dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>bom</artifactId>
    <version>2.51.0</version>
    <type>pom</type>
    <scope>import</scope>
</dependency>
```

Claves conceptuales:

- **`<type>pom</type>`** — el artefacto no es un jar, es un pom (el BOM es puro XML con `<dependencyManagement>` dentro).
- **`<scope>import</scope>`** — sintaxis específica de Maven: "importa el `<dependencyManagement>` de este pom externo dentro del mío". Solo funciona con `type=pom`.
- **El BOM no aporta jars al classpath.** Solo declara versiones.

### Dependencia consumidora en `<dependencies>`

```xml
<dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>s3</artifactId>
</dependency>
```

**Sin `<version>`.** La resuelve Maven leyendo el `<dependencyManagement>` heredado del BOM. Único punto de actualización para los N módulos AWS del proyecto.

### Error didáctico al primer intento

Confusión entre BOM y dependencia real: se declaró `groupId=software.amazon.awssdk:s3` (mezclando notación abreviada `groupId:artifactId` de la documentación con la sintaxis XML del pom). La notación con dos puntos existe solo en documentación y comandos CLI; en el pom cada trozo va en su tag propio.

Corregido a la segunda: `groupId=software.amazon.awssdk`, `artifactId=bom`.

### Verificación empírica con `mvn dependency:tree`

```bash
./mvnw dependency:tree | grep -i awssdk
```

Confirmado en el árbol resuelto:

- `s3:2.51.0` con la versión heredada del BOM. ✓
- Módulos clave transitivos: `auth`, `regions`, `sdk-core`, `apache5-client` (sync HTTP), `netty-nio-client` (async HTTP).
- **Ausencia notable: `sts`.** No viene como transitiva de `s3` en el SDK moderno. Solo se necesita cuando el código llama explícitamente a `AssumeRoleCredentialsProvider` (cross-account access, role chaining). Con Instance Profile puro, el SDK lee credenciales del Metadata Service directamente sin llamar a STS. Si algún día se necesita `AssumeRole`, se añade `software.amazon.awssdk:sts` como dependencia explícita.

## Fase 2 — Bean S3Client con region únicamente

Archivo `src/main/java/com/mtole/taskmanager/config/S3Config.java`:

```java
package com.mtole.taskmanager.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;

@Configuration
public class S3Config {

    @Bean
    public S3Client s3Client() {
        return S3Client.builder()
                .region(Region.EU_WEST_1)
                .build();
    }
}
```

### Lo que le pasas al builder: solo region

Un cliente HTTP contra un API autenticado necesita mínimo tres cosas:

| Necesidad | Fuente | ¿Se declara? |
|---|---|---|
| A dónde ir (endpoint) | Resuelto de la region por el módulo `regions` | No, implícito |
| Con qué region firmar SigV4 | `Region.EU_WEST_1` | Sí, explícito |
| Con qué credenciales firmar | Default Credential Provider Chain implícita | No, implícito |

**Endpoint override** (`.endpointOverride(...)`) solo se usa en casos raros: LocalStack para tests, AWS China / GovCloud, VPC Endpoint privado con DNS custom. Para AWS público estándar, no se toca.

### La joya: el bean NO llama a AWS

Al no llamar a `.credentialsProvider(...)`, el SDK instala por debajo un `DefaultCredentialsProvider.create()`. La chain, en orden:

1. Variables de entorno `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`.
2. System properties Java.
3. Web Identity Token (SSO, EKS).
4. `~/.aws/credentials` file.
5. **Instance Metadata Service (IMDSv2)** ← aquí encontrará las del Role en EC2.

Para en el primero que devuelve credenciales.

### Por qué region hardcodeada, no en `application.properties`

Regla operativa:

> **Externaliza lo que cambia entre entornos. Hardcodea lo que es una constante de arquitectura.**

Hoy la app corre solo en `eu-west-1`. `Region.EU_WEST_1` es constante de arquitectura de facto. Externalizar hoy es sobreingeniería (crea una property `aws.region=...` que nadie va a cambiar nunca).

Refactor futuro (~3 minutos) si algún día la app corre en dos regiones a la vez o hay failover: mover a `@Value("${aws.region}")` con `application-{profile}.properties`. Un solo JAR para todos los entornos.

Contraste con el antipatrón `@Value("${app.database.driver:org.postgresql.Driver}")`: el driver Postgres nunca va a cambiar entre entornos. Externalizarlo ensucia el YAML sin ganar nada. Reconocer esto en code review es señal de senior.

## Descubrimiento empírico: los clients del SDK v2 son *lazy*

### La predicción y el error

Al intentar arrancar la app en WSL con `./mvnw spring-boot:run`, predicción: *"la app arrancará porque no estoy conectado a AWS, y el `S3Client` no lo necesita para construirse"*.

Realidad: la app petó, pero **no por AWS**:

```
Caused by: java.net.ConnectException: Connection refused
    Connection to localhost:5432 refused
    ... FlywayInitializer ...
```

Flyway intentó conectar al Postgres local (no levantado en WSL en esa sesión). Cero mención a S3 o credenciales en el traceback.

### Lo que esto prueba empíricamente

1. Spring construyó el bean `s3Client` sin problema. **Cero red, cero credenciales, cero llamada al Metadata Service.**
2. El SDK **solo hablará con AWS cuando alguien invoque un método real** (`putObject`, `getObject`, `listBuckets`). En ese punto se activa la Default Credential Provider Chain por primera vez.
3. Consecuencia práctica: la app arranca aunque S3 esté caído. Solo fallará la petición HTTP concreta que intente usarlo. **Fail-safe por diseño.**

Este era el clic pedagógico grande de la sesión, y llegó gratis por un error de predicción sobre las dependencias de arranque de la app monolito.

## Frases ⭐⭐⭐ para entrevistas

1. **"Uso el BOM de AWS SDK v2 en `<dependencyManagement>` con `type=pom` y `scope=import`. Las dependencias concretas (s3, sqs, dynamodb...) van sin versión en `<dependencies>` y la heredan del BOM. Garantiza coherencia entre los módulos del SDK y da un único punto de actualización."**

2. **"En el árbol de dependencias del SDK v2, el módulo `auth` trae la Default Credential Provider Chain que resuelve el Instance Profile leyendo IMDSv2, y `regions` traduce la region al endpoint. No necesitas `sts` a menos que hagas `AssumeRole` explícito — típicamente cross-account access o role chaining."**

3. **"Registro el `S3Client` como bean pasándole solo la región. La Default Credential Provider Chain se instala implícitamente al no llamar a `.credentialsProvider(...)`. En EC2 con Instance Profile, la chain resuelve las credenciales temporales en el Metadata Service. La app no ve credenciales nunca."**

4. **"Los clients del AWS SDK v2 son lazy: `S3Client.builder().region(...).build()` no llama a AWS. La chain de credenciales solo se activa al primer método real, y las conexiones HTTP se abren bajo demanda. Diseño explícito para que un fallo de S3 no impida el arranque de la app."**

5. **"Externalizo lo que cambia entre entornos (URLs, credenciales, feature flags) y hardcodeo lo que es constante de arquitectura (drivers, versión de protocolo, región cuando la app corre en una sola). Externalizar por defecto ensucia la configuración; hardcodear por defecto crea deuda. La regla es 'externaliza cuando el cambio es real, no hipotético'."**

## Recursos AWS

Sin cambios respecto a Sesión 4. Ninguna operación desde consola AWS ni CLI.

| Recurso | Estado |
|---|---|
| S3 Bucket `toleflaco-task-manager-uploads-2026` | Vivo (con `test-upload.txt` de Sesión 4) |
| IAM Policy `task-manager-s3-uploads-rw` | Vivo |
| IAM Role `task-manager-ec2-role` | Vivo |
| Instance Profile `task-manager-ec2-role` | Vivo |
| EC2 `task-manager-ec2` | Parada (desde Sesión 4) |

**Coste sesión completa: $0.00** (trabajo local en WSL, EC2 parada, cero llamadas HTTP a AWS).

## Cambios en el repo `task-manager-api`

- `pom.xml`: BOM de AWS SDK v2 añadido en `<dependencyManagement>` junto al de testcontainers; dependencia `s3` añadida en `<dependencies>` sin `<version>`.
- Nuevo archivo `src/main/java/com/mtole/taskmanager/config/S3Config.java` con el bean `s3Client()`.

Verificado empíricamente: `./mvnw clean compile` verde. Bean construido correctamente al intentar arrancar (fallo posterior no relacionado con S3).

## Lecciones operativas nuevas

1. **BOM Maven: siempre `type=pom` + `scope=import` dentro de `<dependencyManagement>`.** Sintaxis específica no negociable.
2. **`mvn dependency:tree` es el primer paso tras añadir una dependencia grande** como el SDK. Confirma versión resuelta, muestra transitivas relevantes, y detecta módulos ausentes que se esperaban encontrar (como el `sts` de este caso).
3. **Predicciones sobre arranque de una app deben incluir TODAS las dependencias de infraestructura**, no solo la del foco de sesión. La app monolito depende de Postgres + MongoDB + Flyway aunque el foco de hoy sea S3. Reflejo entrenable, no innato.
4. **Clients del SDK v2 son lazy por diseño.** Un `builder().build()` no dispara red. Consecuencia práctica: cero problema tener el bean registrado en tests unitarios sin necesidad de LocalStack. El bean se construye, no llama a AWS hasta que un método concreto se ejecuta.
5. **Notación abreviada `groupId:artifactId:version` de documentación ≠ sintaxis XML del pom.** Fuera del XML sirve para copiar-pegar en comandos y foros. Dentro del pom cada trozo va en su tag propio.
6. **Método socrático: parar cuando el cansancio aparece es la disciplina correcta**, no una excusa. Escribir builder patterns nuevos cansado genera errores mecánicos indistinguibles de errores conceptuales.

## Deuda arrastrada

- **ADR-A2** (Instance Profile vs access keys) — pendiente redactar en `cloud-roadmap/decisions/`. Ampliar con "SDK v2 raw vs Spring Cloud AWS" como sección secundaria.
- **Verificar namespace del bucket** (Regional vs Global) en S3 → bucket → Properties. Arrastre desde Sesión 4.
- **VPC** `task-manage-vpc` → `task-manager-vpc` — renombrado pendiente desde Sesión 2.
- **Billing access para IAM user `tole`** — activar desde root. Arrastre desde Sesión 4.
- **Fases 3–6 de Sesión 5** — Service, Controller, deploy real, verificación empírica end-to-end → Sesión 6.
- **Presigned URL + VPC Endpoint** — postergados a Sesión 7 según priorización acordada.

## Para retomar en Sesión 6

**Warmup (~5 min):** repaso del `S3Config` y del punto lazy loading. Verificar que `./mvnw clean compile` sigue verde.

**Fase 3 — FileUploadService (~15 min):**

- Clase `FileUploadService` en `com.mtole.taskmanager.files` (crear package nuevo).
- Método `String upload(MultipartFile file)`.
- Generación de key con `UUID.randomUUID()` + nombre original.
- `PutObjectRequest.builder().bucket(...).key(...).contentType(...).build()`.
- `RequestBody.fromInputStream(file.getInputStream(), file.getSize())`.
- Trampa clásica: `RequestBody.fromInputStream` requiere content-length obligatoriamente.

**Fase 4 — Controller REST (~10 min):**

- `@RestController` en el mismo package.
- `POST /files` con `@RequestParam("file") MultipartFile file`.
- DTO de respuesta con la key.

**Fase 5 — Deploy y verificación empírica (~30 min):**

- Arrancar EC2 `task-manager-ec2` desde consola.
- Nueva Public IP asignada (la anterior `3.254.77.22` de Sesión 4 ya no vale — cada `stop` libera la IP).
- Actualizar regla SSH del SG `task-manager-ec2-sg` con IP pública WSL actual: `3.254.152.91/32` (recogida hoy). Verificar antes con `curl -s ifconfig.me` por si cambió.
- SSH desde WSL, `git pull` en el repo clonado, `./mvnw clean package -DskipTests`.
- Arrancar el JAR con `java -jar target/task-manager-api-0.0.1-SNAPSHOT.jar --spring.profiles.active=aws` (perfil `aws` con Postgres/Flyway deshabilitados — decisión pedagógica en Sesión 6).
- **Verificación empírica end-to-end:** `curl -F "file=@foto.jpg" http://<ip-ec2>:8080/files` desde WSL.
- Verificar en consola S3 que el fichero aparece.
- Parar EC2 al terminar.

**Fase 6 — Diario denso (~10 min).**

Duración estimada Sesión 6: **1h30m con método socrático honesto.**

## Meta-observaciones de método

- **El clic empírico llegó gratis por un error de predicción.** Se predijo *"la app arrancará"* olvidando Postgres/MongoDB/Flyway. El traceback devolvió no un error de AWS sino de Postgres, y eso reveló el lazy loading del SDK v2 sin haberlo teorizado antes. Segundo caso consecutivo (después de las familias de ARN de la Sesión 4) en que el error didáctico enseña más que el éxito directo. Empieza a ser patrón, no coincidencia.
- **Momento *"esto me va a costar"* en mitad de la sesión** (justo tras corregir el BOM). Objetivamente, la sesión mostraba progreso claro: BOM comprendido, sintaxis correcta al segundo intento, decisión SDK v2 raw justificada. El sentimiento subjetivo de dificultad y la realidad objetiva de progreso pueden divergir en sesiones densas de dominio nuevo. Nombrar el fenómeno ("carga cognitiva por concept dumping") ayuda a no interpretarlo como fallo personal. **Regla operativa nueva:** cuando aparezca un término "al pasar" en una explicación, dejarlo pasar por defecto; solo desmenuzar los que están en el foco de la sesión.
- **Cortar en Fase 2 completada, no en mitad de Fase 3.** Sesión 6 arrancará limpia con service + controller en cabeza fresca. Contrafáctico rechazado: escribir builder patterns nuevos cansado habría producido errores mecánicos difíciles de distinguir de conceptuales, y probablemente habría contaminado el diario con debugging en vez de aprendizaje. Regla operativa reforzada: *"afternoon sessions lighter, no dense new concepts"* es de aplicación estricta, no orientativa.
