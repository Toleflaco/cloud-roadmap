# Sesión 2 · AWS — VPC, subnets y fundamentos de red

**Fecha:** 2026-08-02
**Módulo:** AWS fundamentos + Terraform (Roadmap Post-Git/Bash)
**Sesión:** 2 de 9
**Duración aproximada:** dos tramos — teoría por la tarde (~13:00) y práctica (~17:00), separados por descanso.

---

## Contexto

Primera sesión de redes del módulo AWS. El objetivo era construir el modelo mental de red en AWS y montar una VPC custom con diseño público/privado en dos zonas de disponibilidad, como base sobre la que se desplegará el resto de infraestructura. Se hizo con la cuenta ya asegurada y el usuario IAM `tole` de la sesión anterior. La sesión se dividió en un bloque conceptual (sin código) y un bloque práctico (consola), con un descanso entre medias para no encadenar demasiadas horas tras el trabajo del roadmap de IA.

## Qué se hizo

**Bloque conceptual.** Se construyó el modelo mental completo con la analogía del edificio de oficinas. Una VPC es una red privada aislada dentro de AWS, definida por un rango de IPs en notación CIDR (`10.0.0.0/16`, ~65.000 direcciones). Las subnets son divisiones dentro de la VPC, cada una con su sub-rango. La distinción central es pública vs privada: una subnet es pública porque su route table tiene una ruta `0.0.0.0/0` hacia el Internet Gateway; es privada por la ausencia de esa ruta, no por un flag. El Internet Gateway es único por VPC y pertenece al edificio entero, no a una subnet concreta. Las route tables son las reglas que determinan si una subnet sabe llegar al IGW. Se cubrió también la diferencia entre Security Groups (cortafuegos a nivel de instancia, stateful, solo reglas allow) y NACLs (cortafuegos a nivel de subnet, stateless, allow y deny), y el orden en que el tráfico los atraviesa: primero la NACL de la subnet, luego el SG de la máquina.

**Bloque práctico.** Se decidió usar el asistente "VPC and more" en lugar de crear cada pieza a mano con "VPC only". La razón fue pragmática: todo esto se reescribirá en Terraform en la Sesión 5, que es donde de verdad se aprende a definir infraestructura pieza a pieza y versionada; hoy el objetivo era entender cada componente, no teclear clics repetitivos una única vez. Se dejó la default VPC intacta y se creó una VPC custom `task-manage-vpc` (`vpc-0d36eccf71cddeda7`) con: 4 subnets (2 públicas + 2 privadas repartidas en eu-west-1a y eu-west-1b), Internet Gateway, 3 route tables de trabajo más la main, y un VPC endpoint de S3.

Se revisaron las decisiones de coste del asistente. La crítica fue el **NAT Gateway**, que se dejó en `None` (cuesta ~35€/mes y no se necesita mientras nada privado deba salir a internet; es el mayor riesgo de coste del módulo). El **VPC endpoint de S3** sí se activó (gratis, da a las subnets privadas un camino directo y privado a S3 sin pasar por internet ni NAT). Se mantuvieron DNS hostnames y DNS resolution habilitados.

**Verificación del concepto clave.** Se inspeccionaron las route tables reales para comprobar con los propios ojos qué hace pública o privada a una subnet. La route table pública (`rtb-public`) tiene dos rutas: `10.0.0.0/16 → local` (tráfico interno) y `0.0.0.0/0 → igw-...` (salida a internet), y está asociada a las 2 subnets públicas. La route table privada (`rtb-private1`) tiene `10.0.0.0/16 → local` y `pl-... → vpce-...` (endpoint de S3), pero **no** tiene la ruta al IGW. Esa ausencia es exactamente lo que la hace privada.

## Decisiones y aprendizajes

**VPC custom sobre default.** La default VPC de AWS es cómoda pero tiene todas sus subnets públicas: está diseñada para arrancar rápido, no para arrancar seguro. Cualquier entorno serio usa una VPC custom con separación público/privada. (Documentado en detalle en ADR-A1.)

**Público/privado es cuestión de ruta, no de flag.** El concepto central de la sesión, verificado empíricamente: una subnet es pública si su route table apunta `0.0.0.0/0` al Internet Gateway. Sin esa línea, queda aislada de internet.

**Alta disponibilidad con 2 AZs.** Las 4 subnets se reparten en dos zonas de disponibilidad (centros de datos físicos separados dentro de la región). Una pareja pública+privada por zona. Si una AZ cae, la otra sigue. Es por esto que hay 4 subnets y no 2.

**Defensa en profundidad para datos.** Una base de datos con datos de clientes se protege en tres capas: (1) vive en subnet privada, a la que internet no sabe llegar; (2) la NACL de la subnet; (3) el Security Group que solo acepta conexiones del servidor de aplicación en el puerto 5432. Basta con que una capa diga no. En banca es el estándar.

**Security Group vs NACL — nivel y estado.** El SG protege la instancia y es stateful (recuerda la conexión entrante, la respuesta sale sola). La NACL protege la subnet y es stateless (revisa cada dirección por separado). En el día a día se trabaja con SGs; la NACL casi siempre se deja en su configuración default (allow all) y solo se toca para bloqueos explícitos por IP o compliance. Cada subnet tiene siempre una NACL, pero una NACL puede cubrir varias subnets.

**NAT Gateway como riesgo de coste.** Es la pieza que cuesta dinero de verdad (~35€/mes). Se deja apagada por defecto y solo se levanta cuando una máquina privada necesita salida a internet, apagándola al terminar.

## Incidencias

- La lista de route tables mostró primero una tabla de otra VPC pese a filtrar por la propia, y luego una sola en vez de las cuatro. Era un glitch de refresco de la consola; se resolvió pulsando el botón de refrescar. Aprendizaje: las listas de VPC mezclan recursos de todas las VPCs de la región, conviene filtrar por VPC y, si algo no cuadra, refrescar antes de asumir un problema real.

## Estado al cierre

- VPC `task-manage-vpc` (`vpc-0d36eccf71cddeda7`), CIDR `10.0.0.0/16`, State Available.
- 4 subnets: 2 públicas + 2 privadas, en eu-west-1a y eu-west-1b.
- Internet Gateway adjunto; VPC endpoint de S3 activo; NAT Gateway en None (sin coste).
- Route tables verificadas: pública con ruta al IGW, privadas sin ella.
- Coste de la sesión: 0 € (todo lo creado es gratis; el NAT, que costaría, se dejó apagado).

## Pendiente / próxima sesión

**Sesión 3 — EC2 + RDS PostgreSQL.** Se lanza el primer servidor (EC2) y la primera base de datos gestionada (RDS) dentro de esta VPC, y ahí se configuran los primeros Security Groups con un propósito real (EC2 accede a RDS por SG referenciado, no por CIDR abierto). Recordatorio de coste: EC2 t2.micro y RDS db.t3.micro entran en free tier; aun así, disciplina de apagar/destruir al terminar.
