# ADR-A4 — Credenciales AWS: Instance Profile con IAM Role y SDK v2 raw

**Fecha:** 8 agosto 2026
**Estado:** Accepted
**Deciders:** Manuel Toledano Delgado (Tole)
**Sesiones relacionadas:** AWS Sesión 5 (SDK v2 + Default Credential Provider Chain), Sesión 6 (`POST /files` end-to-end contra S3), Sesión 7 (Presigned URLs con `S3Presigner`).

## Context

La aplicación `task-manager-api` (Spring Boot 4, Java 21) se despliega en una instancia EC2 (`task-manager-ec2`, Ubuntu 24.04, `t3.micro`) en la región `eu-west-1` y necesita autenticarse contra servicios de AWS —hasta la fecha S3 y RDS, previsiblemente CloudWatch, SES o SQS en el futuro— para operaciones de lectura y escritura sobre datos del negocio.

Todo servicio de AWS requiere que cada petición HTTP entrante lleve una **firma AWS Signature Version 4 (SigV4)** calculada con credenciales AWS válidas. Esa firma se computa a partir de tres elementos: `Access Key ID`, `Secret Access Key` y opcionalmente un `Session Token` para credenciales temporales. La pregunta arquitectónica es: **¿de dónde saca esas credenciales la aplicación en tiempo de ejecución?**

Se consideraron tres alternativas:

1. **IAM Access Keys de un IAM User** (`AKIA...`). Un par de credenciales permanentes generadas manualmente desde la consola IAM, distribuidas a la aplicación vía variables de entorno, fichero `~/.aws/credentials` o (peor) hardcodeadas en `application.yml`. Válidas indefinidamente hasta rotación manual.

2. **Instance Profile con IAM Role adjunto a la EC2**. La instancia EC2 lleva un rol IAM asociado; el AWS SDK consulta el Instance Metadata Service v2 (IMDSv2) en `http://169.254.169.254`, obtiene credenciales STS temporales (`ASIA...` + `Session Token`), y las usa para firmar. Sin ficheros, sin variables de entorno, sin acción humana.

3. **AWS IAM Identity Center (SSO)** con acceso federado desde un identity provider externo. Descartada de raíz para servidores headless: SSO está pensado para autenticación interactiva de humanos, no para procesos long-running en producción.

En paralelo se evaluó qué **librería cliente** usar para hablar con AWS desde Java:

- **AWS SDK v2** (`software.amazon.awssdk:s3`) — SDK oficial, activamente mantenido, API basada en builders inmutables, soporte first-class para credenciales temporales, `HttpClient` desacoplable (Apache/Netty/URL). Requiere gestionar los beans manualmente en Spring (`S3Config` con `@Bean`).
- **AWS SDK v1** (`com.amazonaws:aws-java-sdk-s3`) — Legacy. Modo mantenimiento oficial desde 2024, se retirará en 2025-2026. Descartado por obsolescencia.
- **Spring Cloud AWS** (`io.awspring.cloud:spring-cloud-aws-starter-s3`) — Wrapper sobre AWS SDK v2 con autoconfiguración Spring. Reduce boilerplate, pero añade una capa de indirección que oculta el mecanismo de credenciales y dificulta el debug cuando algo falla. Su valor añadido concreto para este proyecto (un service, un client) es bajo.

Los criterios que pesaron en la decisión, ordenados por relevancia:

1. **Eliminación del vector de fuga de credenciales.** El proyecto es público en GitHub (portfolio activo para búsqueda de empleo). Cualquier credencial permanente que acabase commiteada por error tendría impacto real.
2. **Cero fricción operativa en el equipo.** No hay decisión posterior sobre "quién genera las keys, cómo se distribuyen, cómo se rotan, qué pasa cuando alguien deja el proyecto".
3. **Pedagogía y portfolio.** El patrón elegido debe ser el que en una entrevista Java+AWS mid/senior se espera como respuesta correcta a "¿cómo se autentica tu aplicación contra AWS en producción?".
4. **Simplicidad de código.** Menos capas entre la aplicación y el SDK, menos misterio cuando algo falla.
5. **Coste.** Ninguna de las alternativas tiene coste directo. No es un criterio diferenciador aquí.

## Decision

Usaremos **Instance Profile con IAM Role adjunto a la EC2** para las credenciales AWS, combinado con **AWS SDK v2 raw** para el cliente Java. Concretamente:

1. Se crea un IAM Role (`task-manager-ec2-role`) con una IAM Policy (`task-manager-s3-uploads-rw`) que otorga permisos mínimos sobre el bucket específico del proyecto.
2. Ese Role se asocia a la EC2 mediante un Instance Profile del mismo nombre.
3. El código de la aplicación **no configura credenciales explícitamente**. Los beans `S3Client` y `S3Presigner` se construyen únicamente con `Region.EU_WEST_1`, sin llamar a `.credentialsProvider(...)`.
4. En tiempo de ejecución, el SDK v2 delega en la **Default Credential Provider Chain**, que recorre en orden: variables de entorno → system properties → Web Identity Token → `~/.aws/credentials` → **IMDSv2 (5º eslabón)**. En la EC2 con Instance Profile, los primeros cuatro eslabones no resuelven; el quinto sí, y devuelve credenciales STS temporales (`ASIA...` con `Session Token`) obtenidas del servicio de metadatos.
5. En entorno de desarrollo local (WSL), la Chain resuelve típicamente por variables de entorno o por `~/.aws/credentials` con un perfil personal del desarrollador. **El código es idéntico en dev y en producción**; cambia únicamente el eslabón que sirve.

## Consequences

### Positivas

- **Cero credenciales AWS permanentes existen en el filesystem del desarrollador, ni en variables de entorno, ni en `application.yml`, ni en ningún commit del repositorio.** El vector clásico de fuga por commit accidental de `AKIA...` queda eliminado por diseño.
- **Rotación automática sin intervención humana.** IMDSv2 emite credenciales STS temporales con TTL de varias horas; el AWS SDK v2 refresca automáticamente en background antes de que caduquen mediante un thread interno. La aplicación nunca percibe el cambio.
- **Robo del laptop de desarrollo → cero exposición de S3 productivo.** No hay credenciales productivas en el laptop. El desarrollador puede tener sus propias credenciales personales para su cuenta de desarrollo, pero las credenciales de la aplicación productiva solo existen efímeramente dentro de la EC2.
- **Auditoría trivial del mecanismo de autenticación.** Basta con leer el prefijo de tres letras de `X-Amz-Credential` en cualquier petición firmada: `AKIA` = access key permanente (mal patrón), `ASIA` = credencial temporal STS (Instance Profile o `AssumeRole`). Presencia de `X-Amz-Security-Token` confirma temporalidad.
- **Escalabilidad operativa.** Si mañana el equipo pasa de una persona a cinco, no hay que generar, distribuir ni rotar access keys. Añadir un nuevo desarrollador no toca la configuración de credenciales del servicio.
- **Portabilidad del patrón a otros compute services AWS.** El mismo mecanismo (asumir un Role vía el metadata service) funciona en ECS Tasks, EKS Pods con IRSA, Lambda functions y CodeBuild jobs. La decisión se generaliza sin cambio de arquitectura.
- **Menos superficie de configuración.** El bean `S3Client` se instancia con dos líneas (`region + build`), sin lógica condicional según entorno. `S3Config` es 20 líneas de código.
- **Alineamiento con AWS Well-Architected Framework** (pilar Security, principio "use IAM roles for applications running on EC2 instances instead of long-term credentials").

### Negativas

- **Requiere que el compute service sea de AWS.** El patrón no funciona en un servidor on-premise, en un contenedor Docker corriendo en el laptop del desarrollador, ni en otro cloud provider. Para entornos híbridos habría que combinarlo con IAM Roles Anywhere o volver a credenciales explícitas, complicando la arquitectura.
- **Debugging inicial menos evidente.** Un fallo "credentials not found" en desarrollo local requiere entender cómo funciona la Default Credential Provider Chain para diagnosticar en qué eslabón está fallando. Un desarrollador nuevo puede tardar en la primera exposición. Mitigado con documentación en `README.md` y con el ADR presente.
- **Acoplamiento operativo al Instance Metadata Service.** Si un atacante obtiene ejecución dentro de la EC2 (por ejemplo, vulnerabilidad de SSRF en la aplicación), puede consultar IMDSv2 y obtener las credenciales del Role. Mitigado por: (a) usar exclusivamente IMDSv2 (con token hop-limit), no IMDSv1; (b) principio de menor privilegio en la policy adjunta al Role, restringiendo la superficie de daño posible.
- **Retraso en el arranque de la app en frío.** El primer uso del `S3Client` desencadena el recorrido completo de la Default Credential Provider Chain, que incluye una llamada HTTP a IMDSv2. Coste típico: pocos cientos de milisegundos. Verificado empíricamente en Sesión 5: los clientes del SDK v2 son lazy y no consultan credenciales hasta la primera operación real, no al construir el bean.

### Neutrales

- **AWS SDK v2 requiere gestionar los beans manualmente en Spring.** No hay autoconfiguración estilo Spring Boot starter. Trade-off aceptado: más control y menos magia oculta a cambio de dos líneas más de configuración por cliente AWS que se añada.
- **Necesita conocimiento explícito del vocabulario AWS.** "Instance Profile", "IAM Role", "STS", "Default Credential Provider Chain", "IMDSv2" son términos que hay que interiorizar. En un equipo con experiencia AWS es baseline; en un equipo sin ella, hay que documentar. Se considera consecuencia neutra porque el vocabulario es estándar de la industria, no específico del proyecto.
- **Spring Cloud AWS descartado hoy no es una puerta cerrada permanentemente.** Si en el futuro el proyecto crece a docenas de servicios AWS integrados, el boilerplate manual del SDK v2 raw podría empezar a pesar y justificar un refactor a Spring Cloud AWS. Por ahora (S3 + posiblemente CloudWatch), no.

## Related decisions



- **ADR-A1 (Accepted, 2026-08-02)** — VPC custom en lugar de default VPC. Define el modelo de red sobre el que este ADR opera.
- **ADR-A3 (Accepted, 2026-08-08)** — RDS gestionada vs Postgres autoinstalado en EC2.

## References

- AWS documentation: [IAM roles for Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
- AWS SDK for Java v2: [Default Credentials Provider Chain](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/credentials-chain.html)
- AWS Well-Architected Framework — Security Pillar, section "Identity Management".
- RFC 3927 — Dynamic Configuration of IPv4 Link-Local Addresses (contexto para la IP `169.254.169.254`).
- Diarios internos: `bitacora/Sesion5-AWS-Diario.md`, `bitacora/Sesion6-AWS-Diario.md`, `bitacora/Sesion7-AWS-Diario.md`.
