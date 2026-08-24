# Sesión 12-E — Import brownfield RTs privadas + associations privadas (cierre bloque de red)

**Fecha:** 24 agosto 2026
**Duración:** ~1h25 (06:30 – 07:55, ventana matutina desde casa donde duerme)
**Estado:** Cierre limpio del bloque de red completo. **13/13 recursos** en state (VPC + 4 subnets + IGW + 3 RTs + 4 associations + 1 ruta pública). `terraform plan` global = `No changes`. Serial 17 (arrancó S12-E en 13, +4 imports). Commit `8181010` pusheado a `origin/main`. RDS: trampa auto-arranque de 7 días **disparada empíricamente hoy** — parada manual inmediata verificada, contador reseteado. SGs NO entraron — pactados formalmente para S12-F sin drama. Sesión corta pero densa en aprendizajes empíricos que corrigieron predicciones teóricas (mías y del alumno) sobre el schema de `aws_route_table`.

## Objetivo pedagógico

Cerrar el bloque de red brownfield iniciado en S12-A/B/C/D importando las 2 RTs privadas restantes y sus 2 associations. Objetivo empírico paralelo: verificar cómo se comporta el schema del recurso `aws_route_table` en provider AWS 6.59.0 cuando existe una ruta gestionable en AWS (la ruta al VPC Endpoint, `pl-6da54004 → vpce-...`) que **no está declarada en el HCL**. Predicción teórica (compartida por profesor y alumno): drift con `-` en `plan` post-import. Resultado empírico: `No changes`. Aprendizaje de método: la teoría razonable no sustituye al empírico controlado, especialmente cuando el schema del provider ha evolucionado entre versiones.

## Bloque 0 — RDS auto-arranque disparado + verificación estado del repo

Regla operativa OBLIGATORIA del prompt: verificar estado antes del warmup. Antes de eso, alerta crítica del profesor apenas abierta la sesión: **hoy es 24 ago 2026, exactamente el día límite del auto-arranque de RDS a 7 días desde S12-A**. Verificación en consola AWS: RDS `task-manager-db` **ya en estado `Starting`** — la trampa se disparó sola en algún momento entre la noche anterior y la mañana. Parada manual inmediata desde la consola. Confirmación posterior: `Stopping` → `Stopped temporarily`. Contador reseteado.

Verificación del repo:
- `git log --oneline -5` → HEAD en `07d991f (add S12-D diary)`, `origin/main` sincronizado. **Nota**: mensaje `07d991f` incumple Conventional Commits bilingüe (no lleva `feat`/`docs`, no lleva cuerpo EN + `---` + cuerpo ES). Ya pusheado — no se reescribe (regla operativa nueva, ver más abajo).
- `git status` → `working tree clean`.
- `terraform plan` → `No changes`, 10 recursos refreshed. Sin sorpresas.
- Serial en state verificado con `aws s3 cp - | jq '.serial'` = **13**, coincide con aritmética esperada del cierre de S12-D (9 al arranque + 4 imports = 13).

Ground truth confirmado. Todo alineado con el prompt de continuación. Diario S12-D + checklist S12-D commiteados en frío la noche anterior por el alumno.

### Nota operativa capturada — commit `07d991f`

Alumno consciente del mensaje mal formateado desde el momento de pegarlo ("me vas a decir que el mensaje del último commit está mal, lo sé, pero ya está pusheado no lo voy a cambiar no??"). Corrección del profesor **con push-back suave y regla derivada**:

> **Regla operativa (candidata ⭐⭐⭐ #30):** El mensaje de commit se verifica **ANTES** de `git push`. Reescribir historia ya pusheada a `main` en un repo personal es tentador pero mala costumbre — en banca/consultoría se trabajará con protected branches donde `push --force` está prohibido por política. Aprender ahora a convivir con commits imperfectos ya pusheados y a verificar antes de pushear.

## Bloque 1 — Warmup: repaso de conceptos de S12-D

Cinco preguntas de predicción antes de arrancar imports. Las críticas: Q1 (anatomía RT) y Q2 (sintaxis de import por tipo).

### Preguntas y desempeño

| # | Tema | Predicción del alumno | Realidad | Correcto |
|---|------|----------------------|----------|----------|
| 1 (crítica) | 3 estructuras Terraform que modelan RT completa + cuál NO se declara nunca y por qué | Estructuras correctas: `aws_route_table` + `aws_route` + `aws_route_table_association`. **"No se declara nunca la asociación implícita de la Main RT"**. | Estructuras correctas. **Pero mezcló dos conceptos distintos**: la pregunta se refería a la **ruta local** (`10.0.0.0/16 → local`, creada por AWS al crear la RT, no gestionable, nunca declarada como `aws_route`). El alumno respondió sobre la **asociación implícita de la Main RT** (fallback silencioso de subnets sin asociación explícita). Ambos son "cosas que AWS crea sin pedir permiso" pero operan a niveles distintos (rutas dentro de una RT vs asociación de una RT entera). Refuerzo aplicado con analogía visual: en la consola AWS abrir la RT pública ya importada, contar rutas visibles (2), identificar cuál está en HCL (la del IGW) y cuál no (la local). | Parcial tras refuerzo |
| 2 (crítica) | Sintaxis de import de `aws_route` vs `aws_route_table_association`. Regla operativa derivada. | Separadores correctos: `_` para `aws_route`, `/` para `aws_route_table_association`. **Regla operativa no formulada** — solo se dieron los facts. | Facts OK. Refuerzo directo: la regla operativa derivada obligatoria es **"verificar la sintaxis del ID de import en los docs oficiales del provider ANTES de cada tipo de recurso nuevo, porque el separador cambia por tipo y no hay convención universal"**. Sin la regla escrita, el próximo tipo nuevo (SGs, VPC Endpoints) volverá a ser adivinanza. | Aprobado con regla operativa añadida |
| 3 | Por qué NO se importa la ruta del VPC Endpoint como `aws_route` explícito. Qué recurso se ocupará. | "Porque lo hará cuando importemos la VPC". | **Fallo de concepto: VPC ≠ VPC Endpoint**. La VPC ya está importada desde S12-B (`aws_vpc.main`). Lo que falta es el **VPC Endpoint**, recurso distinto (`aws_vpc_endpoint`). Cuando se declare/importe en S12-F con parámetro `route_table_ids = [aws_route_table.private_1a.id, aws_route_table.private_1b.id]`, ese recurso adoptará la ruta hacia sí mismo. Refuerzo: **VPC = red virtual (ya la tienes)**; **VPC Endpoint = servicio interno que permite alcanzar servicios AWS (S3, DynamoDB) sin salir a Internet**. | Fallado, refuerzo directo aplicado |
| 4 | Por qué NO se importa la Main RT. Qué la caracteriza. | AWS la crea automáticamente al crear la VPC, no permite eliminarla ni desasociarla de su rol principal. Terraform solo puede gestionar recursos que AWS permite modificar. Asociación implícita con subnets sin asociación explícita. | **Sólida**. Nada que añadir. | Aprobado |
| 5 | Regla operativa ⭐⭐⭐ aplicada bajo estrés que evitó reproducir el bug de copy-paste de S12-C. | "Aparte de leer bien, el ciclo pactado es HCL → validate → plan → import → plan No changes". | Concepto identificado, **número incorrecto**. El alumno citó la regla ⭐⭐⭐ **#17** (ciclo pactado, protege de saltarse verificaciones). La pregunta buscaba la ⭐⭐⭐ **#19** (releer IDs carácter a carácter, protege del error de transcripción). Ambas convivieron en S12-D y ambas se aplicaron. Distinción importante: **#17 protege contra saltarse pasos**; **#19 protege contra errores de lectura al copiar**. Cuando entren SGs, #19 será aún más crítica (IDs de SG igual de opacos). | Parcial (concepto identificado, atribución incorrecta) |

### Resultado global del warmup

Sin fallos absolutos en las críticas — se decidió NO cortar la sesión. Refuerzos aplicados en Q1, Q3 y Q5. Progresión respecto a S12-D visible en la disciplina general.

## Bloque 2 — Descubrimiento realidad RTs privadas (correctivo)

**Error de método del profesor cazado por evidencia del alumno**. El prompt de continuación asumía que las RTs privadas estaban "limpias" hoy (sin ruta gestionable) y que la ruta al VPC Endpoint llegaría solo cuando se declarara `aws_vpc_endpoint` en S12-F. Alumno abrió la consola AWS y verificó en directo: la RT privada `rtb-0be3472cd9db77b55` **ya tiene 2 rutas visibles hoy**:

- `pl-6da54004 → vpce-0122ecf0ee7226fb9` (Origin: **Create Route** — ruta gestionable)
- `10.0.0.0/16 → local` (Origin: **Create Route Table** — ruta no gestionable)

Refuerzo del propio profesor aplicado: **error mío al escribir el prompt de continuación — asumí sin verificar. Aplico regla propia (compartida): cuando no sé algo real de la infra del alumno, marcarlo "verificar" en vez de darlo por sentado**. No lo hice. Corregido en frío.

Consecuencia práctica del descubrimiento: la ruta `pl-6da54004 → vpce-...` es **ruta gestionable**, lo que en la clasificación de S12-D significa que un `aws_route` explícito podría gestionarla. Aparece un choque con las decisiones ya pactadas:

- **Decisión A (locked S12-D)**: las RTs privadas NO llevan `aws_route` explícito en S12-E.
- **Decisión B (locked S12-D)**: la ruta del VPC Endpoint se delega al recurso `aws_vpc_endpoint` en S12-F, no se importa como `aws_route`.

Análisis conjunto pactado antes de escribir HCL: en teoría, si en el HCL de la RT privada no se declara ningún bloque `route` inline, Terraform podría interpretarlo como "no hay rutas → borrar las que haya en state" tras el import. Esa era la lectura razonable del schema. Predicción del alumno: **plan post-import mostrará `-` para la ruta `pl-6da54004`**. Predicción del profesor: **~70% probable que ocurra ese drift**, pero **no verificable teóricamente al 100% sin empírico controlado con la versión 6.59.0**.

Reencuadre operativo pactado: en vez de importar las dos RTs privadas seguidas asumiendo `No changes`, hacer **empírico controlado con `private_1a`**. Ciclo pactado íntegro con predicciones escritas en cada paso. Sea cual sea el resultado del plan post-import, **no ejecutar `apply`** — `plan` es diagnóstico (regla ⭐⭐⭐ #14). Si aparece drift, ajustar con `lifecycle { ignore_changes = [route] }` u otra opción. Si sale `No changes`, aprender algo nuevo sobre el schema.

## Bloque 3 — Import RT privada 1a + association (empírico controlado)

Alumno escribió HCL. **Error tipográfico cazado por el propio alumno en re-lectura** antes de `terraform validate`: escribió `aws_route_association` en vez de `aws_route_table_association`. Reto del profesor sin dar solución ("compara mentalmente los dos tipos que declaraste con los que declaraste en S12-D... cuenta cuántas piezas tiene el tipo del segundo recurso"). Alumno cazó el error solo. Regla operativa entrenada: **releer HCL antes de pedirle al CLI que valide. Si `validate` caza el error, el CLI te salva. Si lo cazas tú, aprendes a leer HCL**.

HCL corregido para `private_1a` (2 recursos):
- `aws_route_table.private_1a` con `vpc_id` + tag `Name = "task-manager-rtb-private1-eu-west-1a"`.
- `aws_route_table_association.private_1a` con `subnet_id = aws_subnet.private_1a.id` + `route_table_id = aws_route_table.private_1a.id`.

Ciclo pactado ejecutado:

1. `terraform validate` → `Success`.
2. **Predicción escrita**: "hay una ruta no declarada y la va a borrar". → Ejecución de `plan` pre-import → **Realidad**: `Plan: 2 to add, 0 to change, 0 to destroy`. Nada de borrar.
3. **Aprendizaje empírico crítico**: el plan pre-import **es engañoso** porque el state no conoce todavía la RT en AWS. `plan` compara HCL vs state, no HCL vs AWS. Sin haber importado, el state no sabe que `rtb-0be3472cd9db77b55` existe → Terraform lo trata como recurso nuevo a crear. La predicción del alumno era **conceptualmente correcta** ("HCL sin declarar → drift") pero **prematura** (aplicable al plan post-import, no al pre-import). Regla ⭐⭐⭐ #3 de S12-A confirmada bajo estrés: **Terraform NO compara HCL contra AWS directamente. Compara HCL contra state. Import lee AWS y escribe en state; después plan compara HCL vs state**.
4. `terraform import aws_route_table.private_1a rtb-0be3472cd9db77b55` → `Import successful`.
5. **Predicción escrita**: "misma predicción — hay una ruta no declarada y la va a borrar". → Ejecución de `plan` post-import → **Realidad**: **`Plan: 1 to add, 0 to change, 0 to destroy`**. La única acción es crear la asociación pendiente. **Silencio absoluto** sobre la RT recién importada, incluida la ruta `pl-6da54004`. Ninguna `-`.
6. **Aprendizaje empírico crítico #2**: predicción incorrecta. El schema del recurso `aws_route_table` en provider AWS 6.59.0 trata el atributo `route` como **`Optional + Computed`**. Cuando un atributo es `Optional + Computed` y no se declara en HCL, Terraform interpreta "no me pronuncio sobre este atributo — respeta lo que haya en state/AWS", **NO** "borra lo que haya". Esto es distinto a atributos `Optional` puros, que sí se interpretan como "vacío si no se declara".
7. Web search del profesor durante el análisis: **en 2018 (issue #5631 de GitHub) el comportamiento era el que el alumno predijo** — el bloque se interpretaba como vacío y borraba rutas. En algún momento entre 2018 y la versión 6.59.0 (2026), HashiCorp cambió el schema para evitar la trampa. Regla operativa derivada:

> **Regla operativa (candidata ⭐⭐⭐ #29):** Los comportamientos empíricos de Terraform pueden cambiar entre versiones del provider. Un blog post o issue de GitHub de años anteriores describiendo "cómo se comporta X" puede estar obsoleto. La única fuente de verdad es el empírico controlado con la versión que se está usando.

Consecuencia práctica: **no hace falta `lifecycle { ignore_changes = [route] }`, no hace falta `aws_route` explícito**. La decisión B (locked S12-D) sigue en pie sin modificación. `aws_vpc_endpoint` en S12-F tomará ownership de la ruta cuando se declare.

8. `terraform import aws_route_table_association.private_1a subnet-00571f5c84fc414d3/rtb-0be3472cd9db77b55` → `Import successful`. **Predicción del alumno acertada**: `plan` post-import de la asociación → `No changes`. Sintaxis del ID de import compuesto (`subnet_id/route_table_id`) verificada por el profesor en docs oficiales antes de ejecutar. Aprendizaje operativo del alumno derivado:

> **Regla operativa (candidata ⭐⭐⭐ #28):** No todos los IDs de import son identificadores AWS opacos. Algunos son **claves compuestas** construidas a partir de datos que ya están en el HCL (subnet_id + route_table_id). Cuando se dude del formato, consultar la sección "Import" de la doc oficial del recurso antes de ejecutar el comando `aws` de descubrimiento — puede que no haga falta.

## Bloque 4 — Import RT privada 1b + association (replicación limpia)

Mismo patrón replicado. Ciclo pactado íntegro con predicciones escritas (breves porque el alumno ya sabía qué esperar tras el empírico de `private_1a`).

- HCL `aws_route_table.private_1b` con tag `Name = "task-manager-rtb-private2-eu-west-1b"` + `aws_route_table_association.private_1b`.
- `validate` → `Success`.
- Predicción `plan` pre-import: "2 recursos a crear". Realidad: `Plan: 2 to add`. Acertada.
- `import aws_route_table.private_1b rtb-09250fc195ff54f09` → OK.
- Predicción `plan` post-import RT: "solo la association pendiente, sin borrar rutas". Realidad: `Plan: 1 to add`. Acertada — el aprendizaje del bloque 3 aterrizó.
- `import aws_route_table_association.private_1b subnet-0af15e9e05f81098f/rtb-09250fc195ff54f09` → OK.
- Predicción `plan` final: `No changes`. Realidad: `No changes`. Acertada.

Verificación serial post-bloque: `aws s3 cp s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate - | jq '.serial'` → **17**. Aritmética: arrancó S12-E en 13, +4 imports = 17. Cuadra exactamente.

**Cero copy-paste bugs en 4 imports pese a dos pares de IDs peligrosamente similares** (`rtb-0be3...` vs `rtb-0925...` para las RTs privadas, `subnet-0057...` vs `subnet-0af1...` para las subnets privadas). Regla ⭐⭐⭐ #19 aplicada bajo estrés real por segunda sesión consecutiva. Consolidación empírica verdadera.

## Bloque 5 — Commit + push del bloque de red

Alumno compuso mensaje bilingüe **con andamiaje mínimo** (Nivel 2 del andamiaje graduado — piezas EN + estructura). Progreso respecto a S12-D visible: no pidió que el profesor le entregara el mensaje. Iteración de corrección aplicada por profesor sobre 3 detalles:

1. Subject: `route table` → `route tables` (plural, más preciso — son dos RTs).
2. Cuerpo ES: comillas angulares `«sin cambios»` → comillas rectas `"No changes"` (evitar Unicode no-ASCII + preferir literal del CLI).
3. Cuerpo ES: `Se importan...` → `Importa...` (activo, paralelo con EN).

Alumno **se adelantó al push** sin verificar el cuerpo del commit con `git log -1 --format=full`. `git log --oneline` solo muestra el subject; el cuerpo puede tener encoding roto sin que se detecte. Corrección del profesor sin softening pero sin drama, con regla operativa explícita:

> **Regla operativa (candidata ⭐⭐⭐ #31):** "Me adelanté" es señal de que el ciclo pactado se convirtió en teatro. El valor pedagógico está en ejecutar el ciclo aunque parezca ceremonia excesiva para un repo personal, porque **banca = ceremonia obligatoria**. Objetivo del roadmap no es entrenar para repo personal — es entrenar para banca. En banca `push` a `main` no existe: hay PR con revisión obligatoria. Acostumbrarse a "correr" ahora genera fricción en la primera semana con procesos de banca que se percibirán como burocracia.

Commit `8181010` pusheado a `origin/main` (`07d991f..8181010`). 1 fichero, 22 inserciones. Repo limpio.

## Aprendizajes empíricos consolidados en S12-E (candidatos a ⭐⭐⭐)

1. **⭐⭐⭐ #26 (candidata):** El `plan` pre-import es engañoso — siempre dirá `+ create` para addresses nuevos porque desde la perspectiva del state está inventando algo que no existe. El diagnóstico útil ocurre en el `plan` post-import, cuando el state ya conoce la realidad AWS.

2. **⭐⭐⭐ #27 (candidata):** El schema del recurso `aws_route_table` en provider AWS 6.59.0 trata el atributo `route` como `Optional + Computed`. Un HCL sin declarar bloque `route` **NO borra** rutas gestionables preexistentes en la RT — respeta lo que haya en state/AWS. Comportamiento distinto al de versiones antiguas del provider (issue #5631 de 2018).

3. **⭐⭐⭐ #28 (candidata):** No todos los IDs de import son identificadores AWS opacos. Algunos son claves compuestas construidas a partir de datos que ya están en el HCL (ej: `aws_route_table_association` usa `subnet_id/route_table_id`, ambos ya disponibles). Consultar sección "Import" de docs oficiales antes de ejecutar comandos `aws` de descubrimiento innecesarios.

4. **⭐⭐⭐ #29 (candidata):** Los comportamientos empíricos de Terraform pueden cambiar entre versiones del provider. Blog posts o issues de GitHub de años anteriores describiendo "cómo se comporta X" pueden estar obsoletos. Única fuente de verdad: empírico controlado con la versión que se usa.

5. **⭐⭐⭐ #30 (candidata):** El mensaje de commit se verifica ANTES de `git push`. Reescribir historia pusheada no es opción en banca (protected branches). Aprender ahora a convivir con commits imperfectos + verificar antes de pushear.

6. **⭐⭐⭐ #31 (candidata):** "Me adelanté" es señal de que el ciclo pactado se convirtió en teatro. Valor pedagógico = ejecutar el ciclo aunque parezca ceremonia excesiva en repo personal, porque banca = ceremonia obligatoria.

7. **Candidato ADR-A9:** Política de gestión de servicios efímeros AWS con timer de auto-arranque. RDS Stop tiene timer de 7 días verificado empíricamente hoy. Regla operativa provisional: **sesiones espaciadas ≤ 6 días** hasta que RDS esté detrás de Terraform con automatización de arranque/parada. Alternativa a evaluar: snapshot + destroy + restore por Terraform (más barato en coste mental si las sesiones se espacian más). Verificable en frío con: `aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=StartDBInstance --max-results 5 --query 'Events[*].[EventTime,Username]' --output table`.

## Estado exacto al cierre de S12-E

Terraform:
- CLI 1.15.8, provider AWS 6.59.0 (~> 6.58 en versions.tf).
- Backend S3 con `use_lockfile = true` (native locking).
- State en `s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate`, serial **17**, lineage sin cambios, resources = **13**.
- `terraform plan` global = `No changes`.

Recursos en state (13):
- `aws_vpc.main`
- `aws_subnet.private_1a`, `aws_subnet.private_1b`, `aws_subnet.public_1a`, `aws_subnet.public_1b`
- `aws_internet_gateway.task_manager`
- `aws_route_table.public`, `aws_route_table.private_1a`, `aws_route_table.private_1b`
- `aws_route.public_to_igw`
- `aws_route_table_association.public_1a`, `aws_route_table_association.public_1b`, `aws_route_table_association.private_1a`, `aws_route_table_association.private_1b`

Commits desde S12-D:
- `8181010` feat(infra): import private route tables and their associations
- `07d991f` add S12-D diary (mensaje no conformante, se deja como está — regla candidata ⭐⭐⭐ #30)

Pendiente commitear (deuda cerrada por el alumno en frío):
- `bitacora/Sesion12-Import-Checklist.md` con las 4 últimas casillas tachadas.
- `bitacora/Sesion12-E-AWS-Diario.md` (este documento, tras revisión y adaptación por el alumno).

RDS: `stopped temporarily`. Contador de 7 días reseteado tras auto-arranque disparado esta mañana.

## Pendientes para S12-F (~2h estimadas honestas, matutinas preferentemente)

Bloque de seguridad primero (arrastrado desde S12-E) y arrancar bloque de aplicación:

1. **SGs**: `aws_security_group` (ec2-sg + db-sg) + `aws_security_group_rule` (ingress/egress). Descubrimiento con `aws ec2 describe-security-groups`. **Introducción explícita del vocabulario SG + SG Rule ANTES de escribir HCL** — regla nueva de S12-D obligatoria.
2. **VPC Endpoint**: `aws_vpc_endpoint` con `route_table_ids = [aws_route_table.private_1a.id, aws_route_table.private_1b.id]`. Este import cerrará el capítulo de "ruta `pl-6da54004` sin owner Terraform".
3. **S3 uploads** + sub-recursos.
4. **IAM Role + Instance Profile**.
5. **EC2**.
6. **RDS**.
7. **`terraform plan` global final** = `No changes` en la infra completa.
8. **ADRs pendientes**: A2 (Terraform vs CloudFormation/CDK), A3 (Secrets Manager vs Parameter Store), A9 candidato (política RDS Stop timer), A10 candidato (Main RT sin gestionar), A11 candidato (VPC Endpoint gestiona ruta, no `aws_route` explícito).

**Prioridad si el tiempo se acorta**: SGs + VPC Endpoint + EC2 primero (permite verificar `task-manager-api` funcional). RDS + IAM roles después si sobra.

**Regla operativa OBLIGATORIA para S12-F**:
- Al arrancar: `git log --oneline -5` + `git status` + `terraform plan` + `jq '.serial'`. Si algo no cuadra, PARAR antes de escribir HCL.
- Ciclo pactado obligatorio con predicción escrita en cada paso — regla ⭐⭐⭐ #24 aplicada sin excepción.
- Vocabulario nuevo (SG, SG Rule) introducido explícitamente ANTES de aparecer en preguntas o HCL — regla nueva de S12-D.
- Verificación del mensaje de commit con `git log -1 --format=full` ANTES de `git push` — regla candidata ⭐⭐⭐ #30.

## Meta-observaciones de método

1. **Error de método del profesor: asumí "sesión vespertina" cuando era matutina**. El prompt de continuación tenía "SON LAS 6.30 hasta las 9" — ambiguo entre AM y PM. El profesor asumió PM sin preguntar y calibró scope como si la sesión fuera vespertina (ligera, 4h/día máx). Alumno corrigió sin drama al final: "empezamos a las 6.30 de la mañana... da igual". Regla derivada:

> Cuando la hora dada por el alumno es ambigua (formato 12h), preguntar antes de calibrar scope. Alternativa mejor: pedir en próximos prompts de continuación el formato 24h ("06:30 a 09:00") — sirve al alumno también cuando relee sus propias bitácoras en frío.

2. **Error de método del profesor: asumí "RTs privadas limpias" sin verificar**. El prompt de continuación afirmaba que las RTs privadas no tenían ruta gestionable hoy y que la ruta al VPC Endpoint llegaría "cuando se declarara `aws_vpc_endpoint` en S12-F". Empírico del alumno demostró lo contrario. Regla derivada:

> Cuando el profesor no conoce con certeza un dato de la infra real del alumno, marcarlo como "verificar" en el prompt de continuación en vez de asumir con confianza. Aplica la misma regla que se le pide al alumno.

3. **Predicción teórica del profesor incorrecta con "~70% confianza"**. La predicción "aparecerá `-` para la ruta `pl-6da54004`" era razonable dada la teoría del schema, pero fue **contradicha empíricamente** por el comportamiento real del provider 6.59.0. Corrección directa aplicada por el profesor sin softening ("hablé con más certeza teórica que la que tenía"). Regla derivada:

> Cuando el profesor emite una predicción teórica con porcentaje de confianza sobre comportamiento del provider Terraform, exponer explícitamente que el empírico controlado es la única fuente de verdad, y que la predicción teórica sirve como marco pero no sustituye al `plan` real. No inflar el porcentaje de confianza.

4. **Empírico controlado como método de resolución de dudas**. Frente a un choque entre predicciones teóricas (alumno + profesor) y ambigüedad sobre el schema, se pactó **importar `private_1a` primero como empírico controlado**, sin ejecutar `apply`, para observar `plan` real antes de importar `private_1b`. Método aplicado correctamente. Aprendizaje empírico genuino resultante (⭐⭐⭐ #27 candidata) mucho más valioso que si se hubiera adoptado una solución defensiva prematura (`lifecycle { ignore_changes = [route] }` sin verificar que hacía falta). Regla derivada:

> Frente a incertidumbre teórica en brownfield, hacer empírico controlado sobre UN recurso primero, no aplicar solución defensiva sobre el bloque completo. `plan` es diagnóstico (read-only), no ejecutar `apply` hasta entender lo que dice.

5. **Alumno cazó su propio bug de tipo de recurso** (`aws_route_association` vs `aws_route_table_association`) tras re-lectura solicitada por el profesor, sin dar la solución. Progreso claro sobre S12-C (donde el bug del IGW fue cazado por el CLI/plan). Regla propia funcionando:

> Cuando el CLI aún no ha sido invocado, forzar re-lectura del alumno antes de pedir `validate`. Si el alumno caza el error, el aprendizaje es doble: reconoce el error + entrena el músculo de leer HCL antes de delegarlo al CLI.

6. **Alumno se adelantó al push sin verificar cuerpo del commit**. Patrón cazable: el ciclo pactado se convierte en teatro cuando parece ceremonia excesiva en repo personal. Corrección con regla operativa explícita sobre banca (candidata ⭐⭐⭐ #31), sin reproche, sin `--amend`. No es reproche a este commit concreto — es materia prima para consolidar el hábito.

7. **RDS auto-arranque a 7 días verificado empíricamente**. Primera vez que un timer de facturación AWS impacta operativamente el roadmap. Dato de oro para ADR-A9. Sin drama — se paró inmediatamente al arrancar la sesión, contador reseteado. Aprendizaje colateral: la disciplina de espaciar sesiones ≤ 6 días es obligatoria mientras RDS no esté detrás de Terraform con automatización.

8. **Duración real ~1h25 vs pactado "hasta 09:00"**. Cierre a las 07:55h. Recorte explícito de SGs a S12-F respetado sin ceder a la tentación de "meter algo más" al final. Buena disciplina operativa. Alumno decidió (opción B propuesta por profesor): checklist ahora, bitácora y prompt S12-F en frío mañana o pasado. Alineado con regla ⭐⭐⭐ #17 (no saltarse pasos por excitación de "cerrar todo hoy") + regla operativa 48-72h (escritura reflexiva sale mejor en frío).

9. **Bitácora escrita por el profesor en modo "notas borrador"** a petición explícita del alumno ("haz las notas con el formato que te subo y yo mientras modifico el checklist y lo subo"). Método pedagógico normalmente exige que el alumno escriba, pero en este caso se pactó paralelización (checklist a mano + notas de profesor como materia prima). **Este documento requiere revisión y adaptación por el alumno antes de commitear**. No es producto final — es andamiaje escrito para acelerar el paso "en frío" sin sacrificar la reflexión personal del alumno.
