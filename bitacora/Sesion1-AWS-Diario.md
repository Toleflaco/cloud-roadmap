# Sesión 1 · AWS — Setup, IAM y CLI

**Fecha:** 2026-08-01
**Módulo:** AWS fundamentos + Terraform (Roadmap Post-Git/Bash)
**Sesión:** 1 de 9
**Duración aproximada:** sesión larga, con dos tramos (mañana y tarde) separados por la comida.

---

## Contexto

Primera sesión del módulo AWS, el primero del roadmap post-Git/Bash. Se llega con el módulo Git cerrado y el de Bash casi (dos sesiones para terminar). El objetivo del temario era: cuenta AWS lista, IAM user con MFA, AWS CLI configurado desde WSL y el modelo mental de shared responsibility. Se cumplió el temario entero más el CLI, aunque el camino fue más largo de lo previsto por trabajar sobre una cuenta AWS antigua ya existente (`manutol@gmail.com`), no una creada de cero.

## Qué se hizo

La sesión arrancó decidiendo el plan de cuenta. Se eligió el plan **Gratuito (6 meses / hasta 200 USD en créditos)** sobre el de pago, porque incluye una red de seguridad real: cuando se agotan los créditos AWS detiene el servicio en vez de cobrar, lo que hace imposible una factura sorpresa durante la fase de aprendizaje. El plan de pago se descartó precisamente por no tener ese tope.

Como la cuenta ya existía, buena parte del tramo de mañana se fue en reactivarla. Aparecieron tres obstáculos encadenados que conviene dejar documentados porque volverán a interpretarse en el futuro: (1) un error 400 al saltar entre pantallas de edición, resuelto reentrando por la puerta principal; (2) el método de pago caducado —herencia de la cuenta vieja—, que obligó a registrar una tarjeta nueva; y (3) rebotes a la pantalla "Complete your account setup" al intentar entrar en IAM, causados porque la verificación de la tarjeta por parte de AWS aún no había cerrado. Este último no se resolvió con ninguna acción concreta: fue esperar a que AWS terminara de activar la cuenta (puede tardar hasta 24h en cuentas reactivadas). La lección es que ese rebote no es un fallo propio sino un estado de activación pendiente del lado de AWS.

Con la cuenta operativa se blindó el **root**: MFA con Microsoft Authenticator (segunda cerradura con código TOTP que rota cada 30s), región fijada en **eu-west-1 (Irlanda)**, y teléfono de recuperación corregido. El chequeo de seguridad de IAM confirmó dos cosas importantes: el root tiene MFA y el root no tiene access keys activas, ambas correctas.

Se creó el **presupuesto** `alerta-gasto-cero` con la plantilla *Zero spend budget*, que notifica al superar 0,01 USD de gasto. Se eligió este sobre el *Monthly cost budget* porque, con la disciplina de destruir recursos no free-tier al terminar cada sesión, el gasto esperado es prácticamente cero; el detector útil es el que salta al primer céntimo, no el que espera a un umbral mensual. AWS activó además Cost Anomaly Detection de fábrica (gratis, umbral de 100 USD), que queda como respaldo lejano.

En el tramo de tarde se completó el objetivo central: el **usuario IAM**. Se creó el usuario `tole` con acceso a consola y contraseña custom (guardada en Bitwarden), sin forzar cambio en el primer login. Para los permisos se siguió la buena práctica: en lugar de pegar la política directamente al usuario, se creó el grupo `admins` con la política gestionada `AdministratorAccess` y se metió a `tole` dentro. Se verificó entrando por primera vez como `tole` a través de la URL de sign-in de IAM (`https://750392809244.signin.aws.amazon.com/console`), distinta de la del root.

Por último se instaló y configuró el **AWS CLI v2** (2.36.14) en WSL. Se generó una access key para `tole` con caso de uso CLI, se configuró el perfil con `aws configure` (región `eu-west-1`, output `json`), y se verificó con `aws sts get-caller-identity`, que devolvió el ARN `arn:aws:iam::750392809244:user/tole` — confirmando que el CLI actúa como el usuario IAM, no como root. Se cerró la sesión asignando también MFA propio a `tole`.

## Decisiones y aprendizajes

**Root vs IAM user.** La razón de fondo para no trabajar como root a diario no es cosmética: si se filtran las credenciales de un usuario IAM se borra ese usuario y se sigue; si se filtran las del root se pierde la cuenta entera. Es el mismo principio que `sudo` frente a `root` en Linux.

**Grupos sobre políticas directas.** Adjuntar políticas a grupos y meter usuarios en ellos escala; pegar la política a cada usuario no. Aunque de momento `tole` sea el único usuario, hacerlo bien desde el principio es criterio demostrable en entrevista.

**Access keys son credenciales de larga duración y peligrosas.** AWS lo advierte explícitamente y ofrece alternativas (CloudShell, `aws login` con credenciales de consola). Para el roadmap se usan keys locales porque es el flujo estándar que exige Terraform, pero con conciencia de que en producción se prefieren roles temporales. Las keys quedan en `~/.aws/`, que nunca debe entrar en Git.

**Shared responsibility model.** AWS asegura la seguridad *of the cloud* (hardware, edificio, hipervisor); el cliente asegura la seguridad *in the cloud* (su app, sus datos, su configuración). Aplicado a dos casos: un bucket S3 dejado abierto es responsabilidad del cliente (`in`); un incendio en un centro de datos es de AWS (`of`). La mayoría de los incidentes reales caen del lado del cliente.

**Distinguir error real de ruido.** Recurrente durante toda la sesión. Fue error real y accionable: "método de pago caducado" y "MFA device already exists" (choque de nombres, resuelto renombrando). Fue ruido decorativo o falso positivo: "No se pudieron recuperar los datos" en widgets del panel y "access keys unused for more than a year" sobre una key creada minutos antes. Verificar antes de reaccionar; no todo lo que sale en rojo importa.

## Errores y su corrección

- **Error 400 al editar teléfono de recuperación.** Causa: enlace caducado al saltar entre pantallas. Corrección: reentrar por `console.aws.amazon.com` en vez de pelear con la pantalla de error.
- **Rechazo repetido del código MFA al reentrar.** Causa probable: código leído a punto de rotar y/o desincronización. Corrección: usar código recién cambiado y meterlo rápido; sincronizar la hora del móvil / "Time correction for codes" en Authenticator.
- **"Entity already exists" al asignar MFA a `tole`.** Causa: se reutilizó el mismo device name que el MFA del root. Corrección: nombre distinto (`tole-iam-mfa`).

## Estado al cierre

- Cuenta `ManuFlaco` / `750392809244` operativa.
- Root con MFA, sin access keys. Región eu-west-1.
- Usuario IAM `tole` con MFA propio, en grupo `admins` (`AdministratorAccess`). Credenciales en Bitwarden.
- Budget `alerta-gasto-cero` activo; Cost Anomaly Detection de respaldo.
- AWS CLI v2 en WSL configurado y verificado (`user/tole`).

## Pendiente / próxima sesión

Nada pendiente de esta sesión. La siguiente es **Sesión 2 — VPC, subnets y security groups**: primer bloque de redes, donde empieza la construcción de infraestructura. Recordatorio de coste: a partir de que se levanten recursos, aplicar la disciplina de destruir lo no free-tier al terminar (NAT Gateway ~35€/mes es el riesgo principal, no se deja encendido).
