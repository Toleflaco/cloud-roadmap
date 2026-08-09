# Sesión 8 — Limpieza de ADRs, arreglo de `.gitignore`, rename de recursos y cierre de S4 oficial con VPC Endpoint Gateway para S3

**Fecha:** 9 agosto 2026
**Duración:** ~1h50 (bloque único de tarde, 18:15 – 20:05)
**Estado:** Completada. Objetivos secundarios (renumeración ADR, arreglo `.gitignore`, rename recursos) resueltos como preámbulo. Objetivo empírico principal conseguido: Route Table de la subnet pública asociada al VPC Endpoint Gateway de S3, con las tres rutas activas simultáneas (endpoint + IGW + local) y longest prefix match razonado correctamente. Sesión 4 oficial del roadmap cerrada al completo.

## Objetivo pedagógico

Doble objetivo esta sesión:

1. **Cierre operativo de deuda de sesiones anteriores.** Renumeración de ADRs para alinear con el roadmap oficial (A2 y A3 reservados para futuras decisiones, tus ADRs propios movidos a A4 y A5), arreglo del `.gitignore` demasiado agresivo que llevaba dos sesiones bloqueando silenciosamente ficheros legítimos, y rename cosmético de recursos AWS con la errata `task-manage-` → `task-manager-`.

2. **Cierre de Sesión 4 oficial del roadmap AWS con VPC Endpoint Gateway para S3.** Concepto central: cómo mantener el tráfico EC2↔S3 dentro del backbone privado de AWS en lugar de cruzar internet, aunque la EC2 esté en subnet pública. Aprendizaje del algoritmo de **longest prefix match** en Route Tables como mecanismo subyacente que permite la convivencia de tráfico a internet (`0.0.0.0/0 → IGW`) y tráfico interno a S3 (`pl-<service> → vpce-<endpoint>`) sin conflicto.

## Fase 0 — Warmup y preparación

Sesión que empieza como continuación directa del cierre de S7 sin necesidad de prompt de continuación externo (el chat conservó todo el contexto). Confirmación del marco de trabajo pactado la sesión anterior: expansión de sesiones aceptada si la calidad pedagógica lo requiere, regla anti-rabbit-hole vinculante con veto tuyo sobre expansiones injustificadas, cada sesión debe cerrar con artefacto tangible.

**Plan del día**: (1) renumeración de ADRs A2→A4 y A3→A5, ~15 min. (2) VPC Endpoint Gateway como cierre de S4 oficial, ~1h. Total estimado 1h15-1h30 sobre 2h disponibles. Estimación resultó optimista por el bug del `.gitignore` que consumió tiempo adicional real (que finalmente enseñó más que el objetivo principal).

## Fase 1 — Renumeración ADRs y descubrimiento del bug del `.gitignore`

### Intención inicial

Renombrar `ADR-A2-aws-credentials-instance-profile.md` a `ADR-A4-...` y `ADR-A3-rds-managed-vs-postgres-on-ec2.md` a `ADR-A5-...`, editando referencias cruzadas internas, y hacer un commit único bilingüe. Reservar ADR-A2 para "Terraform vs CloudFormation vs CDK" (S5 oficial) y ADR-A3 para "Secrets Manager vs Parameter Store" (S7 oficial), alineando con el roadmap firmado el 2 ago 2026.

### El bug empírico descubierto

Primer intento con `git mv ADR-A2-... ADR-A4-...` falló con:
```
fatal: not under version control, source=decisions/ADR-A2-aws-credentials-instance-profile.md
```

`git mv ADR-A3-... ADR-A5-...` sí funcionó — el A3 estaba tracked, el A2 no. Contradictorio dado que el commit anterior `713cdb3` decía en su mensaje "add ADR-A2 and ADR-A3".

### Investigación forense con Git

Comandos de lectura ejecutados en orden:

```bash
git log --oneline -5 -- decisions/       # historia
git show --stat 713cdb3                  # qué añadió el commit del 8 ago
git ls-files decisions/                  # qué está tracked ahora mismo
git check-ignore -v decisions/ADR-A4-... # por qué no puedo añadir esto
```

**Hallazgo definitivo**:
```
.gitignore:6:*credentials*    decisions/ADR-A4-aws-credentials-instance-profile.md
```

Traducción: en la línea 6 del `.gitignore` existía el patrón `*credentials*`, que captura **cualquier fichero con la palabra `credentials` en el nombre**. Bloqueó el ADR-A4 (renombrado hoy) y previamente el ADR-A2 (que era el mismo fichero con otro nombre) en dos commits distintos. El ADR-A2 nunca llegó al repo. El commit `713cdb3` fue silenciosamente parcial — su mensaje mentía sin querer.

### Diagnóstico del `.gitignore`

El `.gitignore` completo del repo tenía dos patrones peligrosamente amplios en la sección "Credenciales AWS":

```
*credentials*
*.csv
```

Ambos siguen la filosofía "captura cualquier cosa que suene sospechosa", pero producen falsos positivos:

- `*credentials*` bloqueaba el ADR-A4 (documentación arquitectónica cuyo tema son credenciales).
- `*.csv` bloquearía cualquier CSV de datos de referencia, fixtures de tests, exports de métricas, etc. En un proyecto de portfolio profesional es común versionar CSVs legítimos.

### Corrección aplicada

Reemplazo de los dos patrones amplios por nombres específicos de los ficheros que AWS realmente genera al descargar credenciales:

```
# Antes
*credentials*
*.csv

# Después
credentials
credentials.csv
credentials.json
rootkey.csv
accesskeys.csv
```

Verificado con `git check-ignore -v -- $(find . -type f -not -path './.git/*')` antes y después: la única entrada bloqueada ahora es `.idea/` (correcta), no hay más falsos positivos.

### Commits resultantes

Tres commits secuenciales, cada uno consciente de sus limitaciones:

1. **`17db180`** — `chore(decisions): renumber ADRs to align with roadmap reservation for A2 (Terraform) and A3 (Secrets)`. Añadió el rename de A3→A5 pero **no** el A4 (bloqueado silenciosamente por el `.gitignore`). Commit parcial pero irreversible una vez pusheado.

2. **`29b7d14`** — `fix(gitignore): replace broad *credentials* and *.csv patterns with specific filenames`. Arregló el `.gitignore` **y** finalmente añadió el ADR-A4 al repo. Mensaje bilingüe honesto que documenta la causa raíz del bug: *"the pattern `*credentials*` was capturing legitimate documentation files whose topic was AWS credentials (ADR-A4 was silently ignored across two prior commits)"*.

Historia de Git resultante es un poco arqueológica (dos commits para lo que debía ser uno), pero **es honesta**: refleja el proceso real de descubrimiento del bug y su corrección. Preferido antes que reescribir historia con `git rebase -i` sobre commits ya pusheados a `origin/main`.

## Fase 2 — Rename cosmético de recursos AWS

Deuda arrastrada desde la Sesión 2 (creación de VPC con asistente "VPC and more"). El asistente creó todos los recursos con la errata `task-manage-` (sin la `r` final). Renombrados hoy vía **Actions → Manage tags** en la consola de cada recurso:

- VPC: `task-manage-vpc` → `task-manager-vpc`
- Route Tables: `task-manage-rtb-public`, `task-manage-rtb-private1-eu-west-1a`, `task-manage-rtb-private2-eu-west-1b` → `task-manager-rtb-*`
- Y otros recursos análogos donde apareciera la errata.

**Detalle técnico importante**: en AWS, el "nombre" de un recurso es solo un tag con clave `Name`. Los IDs internos (`vpc-0d36eccf71cddeda7`, `rtb-07f9363299f58b0b3`) son inmutables y siguen siendo los mismos. Ninguna dependencia rota — la app conecta a RDS por endpoint DNS, a S3 por bucket name, ninguna dependencia interna referencia estos recursos por nombre.

## Fase 3 — VPC Endpoint Gateway para S3 (cierre de S4 oficial)

### Auditoría inicial de Route Tables

Antes de tocar nada, inspección empírica de las cinco Route Tables existentes en la cuenta (2 de la default VPC más 3 de `task-manager-vpc`). Focus en las dos relevantes:

**Route Table pública `task-manager-rtb-public`** — antes del cambio:
```
Destination        Target                    Origin
0.0.0.0/0          igw-0ab423637224cab0c     Create Route
10.0.0.0/16        local                     Create Route Table
```

**Route Table privada `task-manager-rtb-private1-eu-west-1a`**:
```
Destination        Target                    Origin
pl-6da54004        vpce-0122ecf0ee7226fb9    Create Route
10.0.0.0/16        local                     Create Route Table
```

**Hallazgo del arqueólogo**: la subnet privada ya tenía asociación al VPC Endpoint desde la Sesión 2 (el asistente "VPC and more" lo creó automáticamente al marcar "S3 VPC endpoint enabled as free"), pero **solo lo asoció a las Route Tables privadas**, no a la pública. La EC2 vive en subnet pública. **Todo el tráfico a S3 de las Sesiones 5, 6 y 7 salió por internet vía IGW**, aunque el endpoint existía y podría haberlo evitado. Deuda técnica activa sin detectar hasta hoy.

### Conceptos clave interiorizados con predicción socrática

**Concepto 1 — Prefix lists AWS-managed**:

`pl-6da54004` no es un rango IP arbitrario. Es una **prefix list AWS-managed** — una lista dinámica de rangos IP que AWS mantiene y actualiza automáticamente. Contiene los rangos IP actuales de S3 en eu-west-1 (típicamente varios bloques `52.218.x.x`, `3.5.x.x`, etc.). Cuando AWS añade o deprecia rangos IP para S3 en la región, la prefix list se actualiza sin intervención del usuario.

Existen dos tipos de prefix lists:
- **AWS-managed** (`pl-6da54004`, `pl-` con IDs asignados por AWS): mantenidas por AWS.
- **Customer-managed** (creadas por el usuario): útiles para agrupar rangos IP de oficinas corporativas, VPN endpoints, etc.

**Concepto 2 — VPC Endpoint tipo Gateway**:

Los VPC Endpoints tipo **Gateway** (solo para S3 y DynamoDB) no viven como recursos de red con IP en una subnet, sino como **entradas de Route Table**. Cuando marcas una Route Table como asociada al endpoint, AWS añade automáticamente la ruta `pl-<service> → vpce-<endpoint>` a esa Route Table. Es una relación gestionada desde el endpoint hacia las Route Tables, no al revés.

Contraste con los VPC Endpoints tipo **Interface** (para servicios como CloudWatch, Kinesis, ECS, etc.): viven como ENI (Elastic Network Interface) con IP privada en la subnet, cobran por hora y por GB procesado, aparecen como recursos con dirección IP.

**Concepto 3 — Longest prefix match** (predicción socrática exitosa):

Predicción correcta a la primera cuando la Route Table pública tenga las tres rutas conviviendo:

```
pl-6da54004        vpce-...       ← específica (solo IPs de S3)
0.0.0.0/0          igw-...        ← default (cualquier IP)
10.0.0.0/16        local          ← específica (rango VPC)
```

Para una IP de S3 (ej. `3.5.67.194`, la vista ayer en la presigned URL):
- Matchea `pl-6da54004` (rangos S3).
- Matchea `0.0.0.0/0` (matchea todo).
- **Longest prefix match**: `pl-6da54004` es más específica (matchea menos IPs). Gana. Paquete va por el VPC Endpoint.

Para cualquier otra IP externa (Atlas, GitHub, Anthropic API):
- No matchea `pl-6da54004`.
- Matchea `0.0.0.0/0`.
- Paquete va por el IGW.

**Convivencia armónica y aditiva, no destructiva**: la ruta `0.0.0.0/0 → IGW` permanece intacta. Solo se añade una regla más específica que intercepta selectivamente el tráfico a S3.

Frase para entrevista ⭐⭐⭐:
> *"La convivencia entre una ruta `0.0.0.0/0 → IGW` y una ruta `pl-<service> → vpce-<endpoint>` en la misma Route Table funciona por longest prefix match: la prefix list es más específica, así que gana para el servicio destino, y el resto de tráfico sigue saliendo por internet. Es un patrón aditivo, no destructivo."*

### Flujo de la asociación (contraintuitivo)

En primera aproximación, intento fallido de añadir la ruta desde **Route Tables → Edit routes → Add route** buscando "VPC Endpoint" en el desplegable de Target. **No existe esa opción**. El desplegable de Target ofrece Internet Gateway, NAT Gateway, Peering Connection, etc., pero no VPC Endpoint tipo Gateway.

Razón de diseño de AWS: los VPC Endpoints tipo Gateway se gestionan **desde el endpoint hacia las Route Tables**, no al revés. Un mismo endpoint puede estar asociado a múltiples Route Tables; centralizar la gestión en el endpoint evita replicación de configuración.

Flujo correcto:

1. **VPC → Endpoints** en el menú lateral.
2. Seleccionar `vpce-0122ecf0ee7226fb9`.
3. **Actions → Manage route tables** (o pestaña Route tables del panel inferior).
4. Marcar el checkbox de `task-manager-rtb-public` (dejando las dos privadas también marcadas).
5. **Modify route tables**. AWS añade automáticamente la ruta a la Route Table seleccionada.

### Estado final verificado

**Route Table pública `task-manager-rtb-public`** — después del cambio:
```
Destination        Target                     Status    Origin
pl-6da54004        vpce-0122ecf0ee7226fb9     Active    Create Route
0.0.0.0/0          igw-0ab423637224cab0c      Active    Create Route
10.0.0.0/16        local                       Active    Create Route Table
```

Detalle técnico clave: la ruta al endpoint aparece con Origin **"Create Route"**, no **"Create Route Table"**. Es la evidencia de que AWS la añadió automáticamente cuando marcamos el checkbox, no viene "de fábrica" con la Route Table.

### Verificación empírica del cambio

**Decisión operativa**: no ejecutar verificación empírica activa (traceroute, VPC Flow Logs) por dos motivos:

1. El "antes" ya no existe — el cambio ya está aplicado, no hay estado inicial contra el que comparar traceroute.
2. VPC Flow Logs es material propio del módulo de Observabilidad, no aporta valor incremental hoy.

**Verificación por lógica**: la Route Table tiene la ruta `pl-6da54004 → vpce-...` activa, AWS garantiza el algoritmo de longest prefix match, por tanto el tráfico a S3 pasa por el endpoint. **El cambio funciona porque tiene que funcionar** dado el modelo de red que AWS documenta.

Deuda anotada: verificación empírica del tráfico por endpoint pendiente para módulo Observabilidad (VPC Flow Logs, dashboard de tráfico saliente por destino, comparativa antes/después con métricas de NAT/IGW).

## Frases ⭐⭐⭐ consolidadas hoy

1. **Sobre patrones `.gitignore` amplios**: *"Un `.gitignore` con patrones tipo `*palabra*` o extensiones globales sin calificar puede bloquear ficheros legítimos silenciosamente. Git no avisa cuando `git add` afecta a un fichero ignorado — simplemente no lo añade. La única forma fiable de detectar esto es `git status` obligatorio después de cada `git add` y antes de `git commit`, o consulta explícita con `git check-ignore -v`."*

2. **Sobre VPC Endpoint Gateway y seguridad**: *"Un VPC Endpoint Gateway para S3 mantiene el tráfico EC2↔S3 dentro del backbone privado de AWS. Nunca cruza internet público, ni siquiera en tránsito. Requisito estándar en auditorías de banking y fintech donde el data flow diagram tiene que demostrar que datos sensibles no atraviesan red pública."*

3. **Sobre VPC Endpoint Gateway y coste**: *"Un VPC Endpoint Gateway para S3 es gratis y evita el NAT Gateway para tráfico S3. En arquitecturas con EC2 en subnet privada, ahorra tanto los 35€/mes base del NAT si es su único cliente, como el cobro por GB procesado. En cargas con TB mensuales de S3 son cientos de euros de diferencia."*

4. **Sobre longest prefix match aditivo**: *"La convivencia entre una ruta `0.0.0.0/0 → IGW` y una ruta `pl-<service> → vpce-<endpoint>` en la misma Route Table funciona por longest prefix match: la prefix list es más específica, así que gana para el servicio destino, y el resto de tráfico sigue saliendo por internet. Es un patrón aditivo, no destructivo."*

5. **Sobre prefix lists AWS-managed**: *"Las AWS-managed prefix lists son listas de rangos IP mantenidas por AWS que se actualizan automáticamente. En vez de codificar rangos IP de un servicio (que pueden cambiar), referencias el ID de la prefix list y AWS se encarga de mantenerlo al día."*

6. **Sobre gestión de VPC Endpoints Gateway**: *"Los VPC Endpoints tipo Gateway se asocian a Route Tables desde la propia pantalla del endpoint, no editando la Route Table. Un mismo endpoint puede estar asociado a múltiples Route Tables; AWS gestiona la relación centralmente para evitar replicación de configuración."*

## Recursos AWS al final de la sesión

| Recurso | Estado final |
|---|---|
| VPC `task-manager-vpc` | Renombrada (antes `task-manage-vpc`) |
| Route Table `task-manager-rtb-public` | **Modificada — 3 rutas activas incluyendo VPC Endpoint** |
| Route Table `task-manager-rtb-private1-eu-west-1a` | Sin cambios |
| Route Table `task-manager-rtb-private2-eu-west-1b` | Sin cambios |
| VPC Endpoint Gateway `vpce-0122ecf0ee7226fb9` | Ahora asociado también a la Route Table pública |
| EC2 `task-manager-ec2` | Stopped (no arrancada en toda la sesión) |
| RDS `task-manager-db` | Stopped (no arrancada en toda la sesión) |
| S3, IAM Role, Instance Profile, SGs, Atlas | Sin cambios |

Coste corriendo durante la sesión: **~0€** — solo storage RDS EBS parado, y los cambios de Route Table no requieren compute activo.

## Cambios en el repo `cloud-roadmap`

- `.gitignore` modificado: reemplazo de patrones `*credentials*` y `*.csv` por nombres específicos.
- `decisions/ADR-A2-aws-credentials-instance-profile.md` → **renombrado y añadido** como `decisions/ADR-A4-aws-credentials-instance-profile.md`.
- `decisions/ADR-A3-rds-managed-vs-postgres-on-ec2.md` → **renombrado** como `decisions/ADR-A5-rds-managed-vs-postgres-on-ec2.md`. Referencias cruzadas actualizadas.
- Commits resultantes: `17db180` (rename ADRs parcial) y `29b7d14` (fix `.gitignore` + adds ADR-A4 finalmente).

## Lecciones operativas nuevas

1. **`git status` obligatorio entre `git add` y `git commit`**. Sin excepciones. Es la única forma fiable de detectar commits parciales silenciosos causados por `.gitignore`, staging incompleto o archivos no rastreados. Regla operativa personal locked.

2. **`.gitignore` con patrones tipo `*palabra*` son bombas de humo silenciosas**. Bloquean sin avisar. Preferir siempre nombres específicos o patrones bien calificados (con extensión, con ruta parcial). En repositorio de documentación arquitectónica, patrones globales tipo `*credentials*` son especialmente peligrosos porque el vocabulario de los ADRs coincide con el vocabulario de los ficheros a proteger.

3. **`git check-ignore -v <path>` es la herramienta de diagnóstico para "por qué no puedo añadir este fichero"**. Antes de asumir que Git está roto, preguntar a Git por qué ignora algo. Mucho más rápido y directo que revisar el `.gitignore` a ojo.

4. **`git check-ignore -v -- $(find . -type f -not -path './.git/*')` audita el repo entero**. Lista todos los ficheros ignorados con la razón. Útil como auditoría periódica para detectar patrones demasiado amplios.

5. **Renombrar recursos en AWS es cosmético y seguro**. El "nombre" es solo un tag `Name`; los IDs internos son inmutables. Ninguna dependencia rota mientras las herramientas y scripts apunten a IDs, no a nombres.

6. **VPC Endpoints tipo Gateway se gestionan desde el endpoint hacia las Route Tables**. La UI de Route Tables no ofrece "VPC Endpoint" como Target porque el flujo va al revés. Vocabulario clave para no perder tiempo buscando la opción donde no está.

7. **Detrás de cada asistente amigable de AWS hay decisiones ocultas que se mantienen para siempre**. El asistente "VPC and more" de Sesión 2 creó automáticamente el VPC Endpoint pero solo lo asoció a Route Tables privadas. Deuda invisible activa durante 4 sesiones hasta detectarla hoy. Regla operativa: **auditar los recursos creados por asistentes AWS y documentar las decisiones ocultas en un ADR o diario**.

## Deuda arrastrada actualizada

### Deuda nueva (Sesión 8)

- **Verificación empírica del tráfico por VPC Endpoint pendiente** — postpuesta al módulo Observabilidad (VPC Flow Logs).
- **Historia de Git con dos commits para lo que debía ser uno** — irreversible una vez pusheado, aceptada.

### Deuda arrastrada de sesiones anteriores (siguen abiertas)

- **README de portfolio pendiente actualizar** con S3 integration y VPC Endpoint. Deuda acumulada desde S6.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2** — Elastic IP fija (solución media) o Atlas VPC Peering (solución larga). Cada `stop/start` de EC2 rompe conexión.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location** — deuda REST idiomática menor.
- **`postgresql-client` en EC2 en v16 vs server v18** — meta-comandos `\l` fallan.
- **Billing access para IAM user `tole`** — activar desde root.

### Deudas cerradas hoy

- **ADR-A2 pendiente redactar** — completado como ADR-A4 (renumerado por reserva del A2 para Terraform).
- **ADR-A3 pendiente redactar** — completado como ADR-A5 (renumerado por reserva del A3 para Secrets Manager).
- **VPC endpoint gateway para S3** — cierre real de la S4 oficial del roadmap. Objetivo cumplido.
- **VPC `task-manage-vpc` → `task-manager-vpc` rename** — cerrada por rename cosmético.

## Para retomar en Sesión 9

**Warmup (~5 min):** confirmar estado del repo, sin necesidad de arrancar infra AWS todavía.

**Sesión 9 oficial (según roadmap): Terraform Bootstrap — parte conceptual**

Sesión sin tocar código Terraform aún. Solo pizarra y conversación. Temas propuestos:
- Qué problema resuelve Infrastructure as Code (IaC).
- Terraform vs CloudFormation vs CDK — comparativa razonada (ADR-A2 futuro).
- Arquitectura de Terraform: provider, resource, data source, module.
- El state file — qué es, por qué es sagrado, por qué NUNCA vive en Git.
- Remote state y locking — el problema del "dos personas ejecutando apply a la vez".
- HCL como lenguaje declarativo — filosofía "declaras el estado deseado, Terraform calcula el diff".
- Workflow típico: `init` → `plan` → `apply` → `destroy`.
- Convivencia con infraestructura existente creada por consola: `terraform import` como puente.

Sesión probablemente 1h30-2h. Cero infra, cero coste, alta densidad conceptual.

**Alternativa vespertina ligera**: repaso guiado de los conceptos AWS acumulados (S1-S7 + S8) con predicciones socráticas sobre lo aprendido, sin material nuevo. Útil si la próxima ventana es corta o de baja energía.

## Meta-observaciones de método

- **La regla anti-rabbit-hole se aplicó implícitamente hoy con éxito**: cuando el bug del `.gitignore` amenazaba con derivar la sesión hacia una auditoría profunda del `.gitignore` de repos análogos (task-manager-api, erp-mcp-server, cloud-roadmap), el foco se mantuvo en el fichero de este repo. Deuda anotada para revisar los otros `.gitignore` en sesión aparte cuando el objetivo lo justifique.

- **Sesión de 1h50 con dos objetivos completos y un bug real resuelto**. Estimación inicial de 1h15-1h30 se disparó por el bug del `.gitignore`, pero el aprendizaje derivado (`git check-ignore`, patrones `.gitignore` amplios como bombas de humo, `git status` obligatorio) es probablemente más valioso pedagógicamente que el objetivo original de renumerar ADRs. **La deuda técnica encontrada por accidente enseña más que el trabajo planeado.**

- **Cinco correcciones didácticas en fase de código/configuración, todas identificadas antes de aplicar**: (1) `git mv` fallando por `.gitignore`, (2) commit anterior parcial sin detección, (3) `.gitignore` con `*credentials*` y `*.csv` demasiado amplios, (4) intento de añadir ruta desde Route Table hacia VPC Endpoint (flujo incorrecto), (5) subnet pública con endpoint no asociado desde Sesión 2. Ninguna se propagó a estado incorrecto persistente. Ratio saludable de corrección/error.

- **Predicción socrática exitosa a la primera** en el concepto de longest prefix match, después de ver empíricamente las dos Route Tables. Contraste positivo con S7 (predicciones también acertadas). Confirmación de que la interiorización del método socrático está estable y aporta valor real de retención.

- **Deuda nueva hoy: 2 menores**. Compárese con S4 (3), S5 (2), S6 (4), S7 (3). Ratio deuda/entregado sanísima y consistente. Sin deuda tóxica identificada.

- **Regla operativa nueva locked**: auditar decisiones ocultas de asistentes AWS ("VPC and more", "Launch wizard" de EC2, "Create database" wizard de RDS). Cada uno esconde configuración por defecto que hay que verificar explícitamente y documentar. Añadir esa auditoría como fase de warmup en futuras sesiones donde se usen asistentes.
