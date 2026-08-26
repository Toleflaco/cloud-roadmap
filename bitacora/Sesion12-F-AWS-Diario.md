# Sesión 12-F — Import brownfield SGs (ec2-sg + db-sg completos) con patrón moderno

**Fecha:** 25 agosto 2026 (arranque, interrumpida por urgencia médica) + 26 agosto 2026 (reanudación y cierre)
**Duración:** ~1h10 el 25 ago (06:35 – 07:45, interrupción no anunciada) + ~3h15 el 26 ago (06:44 – ~10:00, cierre limpio). Total efectivo ~4h25 en dos ventanas matutinas.
**Estado:** Cierre limpio del bloque de seguridad completo. **7/7 recursos SG** en state (2 contenedores + 3 reglas ec2 + 2 reglas db). `terraform plan` global = `No changes`. Serial 24 (arrancó S12-F en 17, +7 imports). 2 commits pusheados a `origin/main`: `fd46ccd` (ec2-sg + 3 reglas) y `878df45` (db-sg + 2 reglas, rehecho con `--amend` antes del push por bug de `vpc_id` hardcodeado detectado en `git diff --staged`). RDS: `stopped` verificado antes de tocar Terraform ambos días, sin auto-arranque durante la sesión. Bloque VPC Endpoint NO entró — pactado formalmente para S12-G sin drama. Sesión larga con dos errores empíricos de oro que justificaron retroactivamente todo el ciclo pactado: referencias HCL con comillas literales (patrón "SG-references-SG") y `vpc_id` hardcodeado en contenedor db.

## Objetivo pedagógico

Cerrar el bloque de seguridad brownfield introduciendo el **patrón moderno del provider AWS** para Security Groups: recurso contenedor (`aws_security_group`) + recursos separados por regla (`aws_vpc_security_group_ingress_rule` + `aws_vpc_security_group_egress_rule`), en lugar del patrón histórico con bloques `ingress`/`egress` inline. Objetivos empíricos paralelos: (i) verificar que el schema `Optional + Computed` observado en S12-E para `aws_route_table.route` **se replica** en `aws_security_group.ingress`/`egress`, permitiendo declarar el contenedor sin bloques inline sin destruir reglas existentes; (ii) aprender el patrón "SG-references-SG" (`referenced_security_group_id`) para micro-segmentación por identidad de SG en lugar de por CIDR; (iii) aterrizar empíricamente las 6 reglas operativas candidatas de S12-E bajo estrés real. Objetivo secundario: consolidar `git log -1 --format=full` + triple confirmación conjunta pre-push como ceremonia obligatoria de banca.

## Bloque 0 (25 ago) — Verificación estado del repo + calibración de scope

Regla operativa OBLIGATORIA del prompt: verificar estado antes del warmup. Verificación:
- `git log --oneline -5` → HEAD en `0a3e90b docs(bitacora): add S12-E diary`, `origin/main` sincronizado. Hash coincide con el "verificar" del prompt.
- `git status` → `working tree clean`.
- `terraform plan` → `No changes`, 14 recursos refreshed.
- `aws s3 cp - | jq '.serial'` → **17**, coincide con el cierre de S12-E.
- Fecha sistema: martes 25 ago 2026. Margen sobre deadline auto-arranque RDS (31 ago): 6 días. Suficiente.
- Estado RDS verificado: `stopped`.

**Discrepancia empírica detectada por el profesor** en el output de `terraform plan`: refrescó **14 recursos**, no 13 como afirmaba el resumen del prompt de continuación S12-F. Verificación con `terraform state list | wc -l` → **14**. El prompt de continuación tenía un error de conteo en el resumen ("13/13 recursos de red importados") aunque enumeraba correctamente los 14 nombres al desglosarlos. Regla derivada:

> **Regla operativa (candidata):** El ground truth del número de recursos en state es `terraform state list | wc -l`, no el conteo mental al redactar el prompt de continuación. Aplicable también al pedagogo cuando redacta prompts.

Nota operativa: **no se hace `git rebase` ni `git commit --amend` sobre el commit del diario S12-E ya pusheado** para corregir el "13" del cuerpo del mensaje. Regla ⭐⭐⭐ #30. La corrección se documenta en este diario como nota al margen.

## Bloque 1 (25 ago) — Warmup: repaso de conceptos de S12-E

Cinco preguntas de predicción antes de arrancar SGs. Las críticas: Q2 (Optional+Computed, concepto empírico de oro de S12-E que probablemente aparecería en el schema de `aws_security_group`) y Q4 (anatomía RT, deuda parcial de S12-E).

### Preguntas y desempeño

| # | Tema | Predicción del alumno | Realidad | Correcto |
|---|------|----------------------|----------|----------|
| 1 | Plan pre-import: qué muestra, qué compara, por qué es engañoso | "+ create", "compara state con HCL, al no estar en state por eso pone create", "es engañoso, primero hay que hacer el import y luego volver a hacer el plan". | **Sólida**. Formulación exacta ("compara state con HCL") que es la formulación crítica de la regla ⭐⭐⭐ #3. Sub-pregunta añadida sobre qué pasaría con `apply` directo (duplicados silenciosos vs errores ruidosos según constraint de unicidad): parcial, faltó el escenario "duplicado silencioso sin cambio en HCL" (la mayoría de recursos AWS permiten duplicados). Refuerzo del profesor: `import` protege del duplicado silencioso, no del error ruidoso. | Aprobado con matiz |
| 2 (crítica) | Optional + Computed: descomponer términos + aplicación al `route` de `aws_route_table` 6.59.0 + contraste con Optional puro | Descomposición correcta de los tres términos (Optional, Computed, Optional+Computed). Aplicación al caso `route`: **fallo de formulación** ("el provider AWS no permite definir rutas inline dentro de aws_route_table"). Contraste correcto. | Corrección quirúrgica: **el provider sí permite `route` inline**. Es Optional. La razón real de Optional+Computed no es "porque no se permite inline" sino "para permitir el patrón dual (inline o `aws_route` separado) sin que HCL vacío borre rutas existentes". Comprensión mecánica sí, formulación conceptual con desliz. | Aprobado con corrección |
| 3 | ID de import de `aws_route_table_association` + de dónde salen las piezas + por qué no hace falta `describe-route-tables` | Respondió sobre `aws_route`, no sobre `aws_route_table_association`. Confusión de vocabulario. | **Fallado**. Respuesta correcta: ID = `subnet_id/route_table_id` (barra), ambas piezas ya están en HCL, no hace falta `describe`. La regla ⭐⭐⭐ #28 (candidata de S12-E) **no aterrizada**. Aterrizaje pospuesto a operativa del bloque de imports. | Fallado, refuerzo diferido a empírico |
| 4 (crítica) | Anatomía RT en Terraform: 3 estructuras + ruta que nunca se declara + razones | 3 recursos correctos. Ruta local correctamente identificada como imposible/inútil de declarar. 4 razones bien justificadas (AWS la crea, no la borra, no la recrea, Terraform no la gestiona). | **Sólida**. Deuda de S12-E cerrada. | Aprobado |
| 5 | Comando exacto entre `git commit` y `git push` + qué verifica + por qué es ceremonia no negociable | Comando: `git status --short --branch`. Justificación: "se entrena para que en contexto profesional sea automática". | **Fallado**. Confusión de reglas: `git status` va entre `add` y `commit` (regla vieja); la regla nueva de S12-E candidata #30 es **`git log -1 --format=full`** entre `commit` y `push`. Justificación demasiado genérica: contexto específico = banca, donde `push --force` y `--amend` sobre commits pusheados están prohibidos. Regla candidata ⭐⭐⭐ #30 **no aterrizada**. Aterrizaje pospuesto a operativa del bloque de commits. | Fallado, refuerzo diferido a empírico |

### Resultado global del warmup

**Ninguna crítica fallada** (Q2 y Q4 aprobadas). Se decidió NO cortar la sesión. Sí falladas Q3 y Q5, **ambas sobre reglas candidatas ⭐⭐⭐ creadas hace 24h en S12-E**. Aterrizaje verbal correcto en Q1, Q2 y Q4 no implica aterrizaje operativo — se pactó comprobación empírica en el bloque de imports (Q3 al importar reglas SG con posible ID compuesto, Q5 al commitear).

## Bloque 2 (25 ago) — Vocabulario Security Groups (calibración fallida)

**Error de calibración pedagógica del profesor**. Se planificó introducción del vocabulario SG completo antes del HCL (regla nueva de S12-D obligatoria), pero el bloque se expandió a **4 conceptos + 4 verificaciones + escenarios X/Y sobre schema Optional+Computed en `aws_security_group.ingress`/`egress` + patrón moderno vs histórico**, todo antes de tocar la consola AWS. ~45 min de conceptos densos sin ver realidad. Feedback del alumno al final: "buen bloque me has metido, eh?".

Corrección del profesor sin softening:

> **Error de método:** 4 conceptos + 4 verificaciones + Escenarios X/Y en 45 min es demasiado para "vocabulario previo al HCL". El bloque debió cortarse en Concepto 4 y dejar 5-6 para el momento en que aparecieran en HCL. Regla derivada: **máximo 3 conceptos consecutivos con verificación entre cada uno, después toca ver realidad. Si el bloque necesita más conceptos, es señal de que hay que dividir en dos sesiones o intercalar con descubrimiento AWS**.

### Verificaciones ejecutadas en el bloque

- **V1** (Concepto SG a nivel de ENI): Predicción alumno "2 SGs, se suman" ante el escenario "asociar `task-manager-ec2-sg` a EC2 con default de VPC existente en la VPC". **Fallada**: el default NO se aplica automáticamente a toda ENI de la VPC — solo aparece como fallback si nadie eligió otro SG al lanzar el recurso. Refuerzo con analogía técnica (ClassLoader parent en JVM: existe siempre en la jerarquía pero solo actúa como fallback cuando el child no encuentra la clase). Regla mnemotécnica: **"el default es fallback, no wallpaper"**. Hipótesis del alumno reformulada: Opción B (creó `task-manager-ec2-sg` explícitamente al lanzar EC2, default no asociado), marcada para verificación empírica en Bloque 3.
- **V2** (Stateful vs stateless): Predicción alumno correcta ("no hace falta regla egress ya que es stateful, tiene estado y recuerda que ha entrado"). Aterrizado.
- **V3+4+5** (Patrón moderno + `referenced_security_group_id` + separación ingress/egress en 2 recursos):
  - (a) Predijo 2 recursos (uno para ingress, uno para egress). **Fallado**. Correcto: patrón moderno = **un recurso por regla individual**. Fórmula mental: **N reglas AWS → N+1 recursos Terraform**.
  - (b) Predijo "referencio con el id del sg" sin dar el atributo. Correcto: `referenced_security_group_id`.
  - (c) Justificación parcial (dio "cada regla tiene su propio id, se puede importar por separado"). Razón real de la separación ingress/egress en dos recursos distintos: AWS API expone endpoints separados (`AuthorizeSecurityGroupIngress` / `AuthorizeSecurityGroupEgress`), el schema Terraform copia esa asimetría.
- **V6** (Escenario X vs Y para `ingress`/`egress` en `aws_security_group`): Predicción alumno correcta ("Escenario X"). Justificación adecuada. Marcado para verificación empírica en Bloque 4.

## Bloque 3 (25 ago) — Descubrimiento realidad SGs con `describe-security-groups`

Recalibración de scope tras densidad del Bloque 2: **VPC Endpoint fuera de S12-F**, se pacta para S12-G. Solo cerrar ec2-sg (posible db-sg si sobra tiempo).

Comando ejecutado: `aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-0d36eccf71cddeda7" --output json`. Output procesado:

- **3 SGs en la VPC** confirmados: `sg-036772953179b5905` (task-manager-ec2-sg), `sg-0d3abd728ee60c9e5` (task-manager-db-sg), `sg-01f966cb344439254` (default). NO se importa el default (decisión pactada, análoga a Main RT).
- **`task-manager-ec2-sg`**: 2 reglas ingress (TCP 8080 desde `88.11.202.24/32` con description `"TCP port 8080"`, TCP 22 desde `88.11.202.24/32` con description `"SSH from home"`) + 1 regla egress (all `-1` hacia `0.0.0.0/0`, sin description). **Total: 4 recursos Terraform** = 1 contenedor + 2 ingress + 1 egress.
- **`task-manager-db-sg`**: 1 regla ingress (TCP 5432 desde `sg-036...` vía `UserIdGroupPairs`, description `"PostgreSQL from EC2 app tier"`) + 1 regla egress (all `-1` hacia `0.0.0.0/0`, sin description). **Total: 3 recursos Terraform** = 1 contenedor + 1 ingress SG-ref + 1 egress.

**Corrección conjunta al modelo mental**: el prompt asumía que 8080 estaría abierto desde `0.0.0.0/0`; realidad = restringido a IP casa (`88.11.202.24/32`). Configuración más segura que el ejemplo pedagógico. La `Description` del SG ec2 dice `"SSH access from my IP for task-manager EC2"` pero el SG también tiene regla 8080 — desactualizada. **Se importa tal cual está en AWS** (regla ⭐⭐⭐ #7 S12-B: en brownfield la fuente de verdad es AWS). Candidato a cleanup en sesión futura.

**Hipótesis B confirmada empíricamente** (`aws ec2 describe-instances --filters "Name=tag:Name,Values=task-manager-ec2" --query 'Reservations[0].Instances[0].SecurityGroups'`): la EC2 tiene solo `sg-036772953179b5905`, no el default. Modelo mental "el default es fallback, no wallpaper" aterrizado con evidencia.

## Bloque 4 (25 ago) — Import contenedor `aws_security_group.ec2` (empírico controlado Escenario X)

Antes de HCL, verificación de docs de import por el alumno. **Aterrizaje incompleto de regla #28** en este primer intento: el alumno respondió con el comando ejecutable en lugar de con formulación en prosa del formato. Aceptado como buena fe pero anotado como refuerzo para reglas de patrón moderno donde el ID es compuesto (`sgr-...`).

HCL escrito por el alumno (contenedor mínimo con `name`, `description`, `vpc_id = aws_vpc.main.id`, description copiada carácter a carácter del `describe`).

### Incidente pedagógico #1 de S12-F — "trampa deliberada" inventada por el profesor

El profesor sugirió "trampa deliberada" al pedir predicción de `terraform validate`, insinuando la existencia de un atributo obligatorio no declarado que haría fallar el validate. **Falso**: `aws_security_group` en provider 6.59.0 requiere solo HCL semánticamente coherente y `name`+`description`+`vpc_id` es suficiente. El alumno predijo correctamente `success` y no se dejó llevar por la pista. Corrección del profesor sin softening:

> **Regla derivada (aterrizaje pedagogo):** Cuando el profesor no sabe con certeza el schema, marcarlo como "verificar" en vez de inventar trampas didácticas. Aplica misma regla que se le pide al alumno. Regla nueva de S12-E aplicada mal por el profesor por segunda vez en dos sesiones.

Ciclo pactado ejecutado sin más incidentes:

1. `terraform validate` → `Success`.
2. **Predicción inicial fallada** del alumno: `No changes`. **Regresión crítica** — Q1 del warmup verbalizada correctamente, en operativo caída. Regla candidata (S12-C): "una regla aterrizada verbalmente NO es una regla aterrizada empíricamente". Reformulación exigida por el profesor sin softening. Predicción corregida: `+ 1 create`, `Plan: 1 to add, 0 to change, 0 to destroy`. Aterrizaje empírico regla #26 al segundo intento.
3. `terraform plan` → `Plan: 1 to add`. Único recurso `aws_security_group.ec2`. **Señal empírica temprana de Escenario X**: plan mostró `+ egress = (known after apply)` y `+ ingress = (known after apply)`, no `+ ingress = []`. Si fueran Optional puros, saldrían como listas vacías. `known after apply` = pista fuerte de Computed.
4. `terraform import aws_security_group.ec2 sg-036772953179b5905` → `Import successful`.
5. `terraform plan` → **`No changes`**. **Escenario X confirmado empíricamente**: el schema `aws_security_group` marca `ingress` y `egress` como `Optional + Computed` en provider 6.59.0. HCL contenedor sin bloques inline no borra las reglas existentes. **Regla ⭐⭐⭐ #27 se replica**: verificada ahora en un recurso distinto (`aws_security_group.ingress`/`egress`) al de S12-E (`aws_route_table.route`). Ya no es "aparece en un recurso" — es patrón del provider.

### Interrupción no anunciada por urgencia médica (~07:45 el 25 ago)

Alumno tuvo que salir por urgencia médica sin poder avisar. Sesión cerrada a mitad del Bloque 4, después de importar solo el contenedor ec2-sg (serial 18). Reanudación pactada implícitamente al día siguiente.

## Bloque 0 nuevo (26 ago) — Reanudación tras hueco de ~23h

Aplicación estricta de disciplina banca: **cualquier reanudación no continua es un Bloque 0 nuevo, no pase directo**. En 23h puede haber cambiado cualquier cosa (drift, rotación IP, otra sesión).

Verificación:
- `git log --oneline -5` → HEAD sigue en `0a3e90b`, `origin/main` sincronizado.
- `git status` → `modified: main.tf` (esperado, contenedor ec2-sg sin commitear).
- `terraform plan` → `No changes`. Escenario X confirmado 24h después.
- `curl -s https://ifconfig.me` → `88.11.202.24`. IP sin rotación. Reglas SSH/8080 siguen alineadas.
- `aws s3 cp - | jq '.serial'` → **18**, coincide con lo esperado.
- `aws rds describe-db-instances --query 'DBInstances[0].DBInstanceStatus' --output text` → `stopped`. Contador RDS sin disparo.
- Fecha sistema: miércoles 26 ago 2026. Margen deadline RDS: 5 días.

Repo íntegro, state consistente. Ventana de 3h16 disponible (06:44 – 10:00). Scope recalibrado: cerrar ec2-sg completo + db-sg completo. VPC Endpoint se mantiene fuera. Confirmado por el alumno "opción A sin prisas".

## Bloque 5 (26 ago) — Import reglas ec2-sg (patrón moderno con `sgr-...`)

**API distinta necesaria**. El output de `describe-security-groups` (usado en Bloque 3) **no expone los `sgr-...`** — es API vieja. Para el patrón moderno hay que consultar `aws ec2 describe-security-group-rules --filters "Name=group-id,Values=sg-036..."`. Aprendizaje empírico:

> **Regla operativa (candidata S12-F #2):** El patrón moderno del provider AWS tiene su propia API en AWS (`describe-security-group-rules`) que devuelve los `SecurityGroupRuleId` (`sgr-...`). La API vieja (`describe-security-groups`) no los expone. Consecuencia operativa: **en brownfield con patrón moderno hay que consultar la API nueva antes de importar reglas**.

Output procesado: 3 `sgr-...` identificados en ec2-sg (SSH, HTTP, egress).

Convención de naming pactada: `ec2_ssh_home`, `ec2_http_home`, `ec2_all_out`. Sufijo `_home` señala origen IP residencial (semánticamente relevante cuando la IP rote — la IP concreta vive en `cidr_ipv4`, el naming describe propósito).

### Vocabulario específico patrón moderno (introducido antes del HCL)

Atributos del recurso `aws_vpc_security_group_ingress_rule`:
- Obligatorios: `security_group_id`, `ip_protocol` (**ojo**: `ip_protocol`, no `protocol` como en el histórico).
- Puertos (obligatorios si `ip_protocol` no es `-1` ni `icmp`): `from_port`, `to_port`.
- Origen (exactamente UNO): `cidr_ipv4` (**string único**, no lista), `cidr_ipv6`, `referenced_security_group_id`, `prefix_list_id`.
- Opcionales recomendados: `description`, `tags`.

Cambios notables vs histórico: `protocol` → `ip_protocol`, `cidr_blocks = ["..."]` → `cidr_ipv4 = "..."`, bloque anidado → recurso independiente.

### Ciclo pactado: 3 reglas ec2 sin incidencias

**Ingress SSH 22** (`sgr-0c2351003d54ef1af`): HCL correcto, predicción `+ create` acertada, import limpio, plan post-import `No changes`, serial 19.

**Ingress HTTP 8080** (`sgr-0360f1a003ba2b406`): mismo patrón, sin incidencias, serial 20.

**Egress all_out** (`sgr-0875adb6f2e86f9f6`): **empírico controlado a nivel de atributo**. Verificación docs del alumno: `from_port`/`to_port` son Optional. HCL minimalista (sin `from_port`/`to_port`/`description`). `validate` → `Success`. `plan` limpio, import limpio, `No changes`, serial 21. Aprendizaje empírico:

> **Regla operativa (candidata S12-F #3):** Cuando `ip_protocol = "-1"` en `aws_vpc_security_group_egress_rule` (provider 6.59.0), los atributos `from_port`/`to_port` se pueden **omitir** del HCL. El schema los acepta como Optional en ese contexto. HCL minimalista más limpio que declararlos como `-1`.

Balance intermedio: **regla candidata #26 aterrizada 4 veces consecutivas** en la sesión (validate, plan pre-import contenedor, planes pre-import reglas × 3). Regla candidata #28 aterrizada empíricamente por operativa. Promoción a locked al cierre de sesión.

## Bloque 6 (26 ago) — Commit ec2-sg (regla #30 aterrizada, regla #31 fallada)

Mensaje bilingüe compuesto conjuntamente. Subject Conventional Commits, cuerpo EN + `---` + cuerpo ES sin acentos ni ñ, incluyendo hallazgos empíricos S12-F candidatos #1 (schema Optional+Computed replicado en `aws_security_group`) y #3 (omisión `from_port`/`to_port` en egress `-1`).

Pasos ejecutados:
1. `git status` (working tree con `main.tf` modified). ✓
2. `git add main.tf`. ✓
3. `git diff` (sin argumentos) → vacío. **Pregunta técnica del alumno**: "por qué no sale nada en el diff??". Aprendizaje aterrizado:

> **Regla operativa (candidata S12-F #4):** `git diff` sin argumentos = working tree vs staged. Tras `git add`, ambos coinciden, no muestra nada. El comando correcto para releer visualmente lo que va a entrar en commit es `git diff --staged` (working tree o mejor dicho staged vs HEAD). **`git diff --staged` es el comando de revisión visual antes de commit**. En banca es lo que revisa el peer en el PR; verlo tú primero es disciplina.

4. `git commit` (sin `-m`, editor multilínea).
5. `git log -1 --format=full` → cuerpo del commit verificado íntegro (subject Conventional Commits, `---` presente, parte ES sin acentos, body EN + ES completo). **Regla candidata ⭐⭐⭐ #30 aterrizada empíricamente**.
6. **Incidente pedagógico #2 de S12-F**: alumno ejecutó `git push` **sin confirmación conjunta pactada**. Regla candidata ⭐⭐⭐ #31 no aterrizada por segunda sesión consecutiva. Push ya ejecutado (commit `fd46ccd` en `origin/main`) — no reescribir historia. Corrección del profesor sin softening + regla operativa emergente:

> **Regla operativa (aterrizaje forzado #31):** Ceremonia artificial explícita antes del próximo push. Formato obligatorio de triple confirmación:
>
> ```
> Tole confirma: [SÍ / NO] cuerpo del commit revisado y correcto
> Claude confirma: [SÍ / NO / pendiente]
> Claude autoriza push: [SÍ / NO / pendiente]
> ```
>
> **No pushear hasta que los tres digan SÍ / autorizado**. Ceremonia se hace incómoda hasta que salga sola. Regla #31 aterriza empíricamente o queda 3ª sesión candidata.

## Bloque 7 (26 ago) — Import contenedor `aws_security_group.db`

### Error productivo del alumno cazado por Terraform

Primer intento de import falló:

```
Error: resource address "aws_vpc_security_group.db" does not exist in the configuration.
```

Alumno escribió `aws_vpc_security_group` (con `_vpc_`) en el comando de import. HCL declara `aws_security_group` (sin `_vpc_`). Asimetría de naming del provider: contenedor mantiene nombre histórico (`aws_security_group`) por retrocompatibilidad, reglas modernas llevan prefijo `_vpc_` (`aws_vpc_security_group_ingress_rule`, `aws_vpc_security_group_egress_rule`). Aprendizaje empírico:

> **Regla operativa (candidata S12-F #5):** El patrón moderno del provider AWS usa **naming asimétrico**. Contenedor = `aws_security_group` (nombre histórico, retrocompatibilidad). Reglas = `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` (con prefijo `_vpc_`). Consistencia sacrificada por retrocompatibilidad. **Confirmar tipo de recurso exacto en la doc antes de escribir import**.

Positivo del error: Terraform paró antes de tocar state. Error ruidoso, mensaje explícito y accionable. Regla ⭐⭐⭐ #14 (import es READ-ONLY, peligro está en apply posterior) aplicada en su forma más benigna. Segundo intento con `aws_security_group.db` — import limpio, `No changes`, serial 22.

Escenario X confirmado por 3ª vez consecutiva en la sesión (route en aws_route_table + ingress/egress en aws_security_group.ec2 + ingress/egress en aws_security_group.db). Patrón consolidado.

## Bloque 8 (26 ago) — Import regla ingress `db_postgres_from_ec2` (patrón "SG-references-SG") — INCIDENTE MAYOR

**Elemento nuevo de la sesión**: patrón "SG referencia a SG" con `referenced_security_group_id` en lugar de `cidr_ipv4`. Aterrizajes conceptuales previos al HCL:

1. **Mecánica**: la regla dice "PostgreSQL 5432 desde **cualquier ENI que tenga el SG `sg-036...` asociado**", no "desde el CIDR de la subnet privada" ni "desde una IP concreta". Micro-segmentación por identidad de SG. Ventajas: escala automáticamente con nuevas EC2s con mismo SG; sobrevive a movimientos entre subnets; deniega tráfico dentro de la subnet si no tiene el SG asociado; auditoría más clara.
2. **Atributo Terraform**: `referenced_security_group_id = aws_security_group.ec2.id` (referencia por address, no ID hardcodeado). Antipatrón: hardcodear `sg-...` literal (rompe el grafo de dependencias del state).
3. **Trampa a esperar en plan pre-import**: `referenced_security_group_id = "sg-036772953179b5905"` (resuelto porque el contenedor ec2 ya está en state). Si sale `(known after apply)`, señal de dependencia rota.

### Ciclo pactado ejecutado con incidente de referencias mal escritas

Descubrimiento `sgr-...` con `describe-security-group-rules` sobre `sg-0d3abd728ee60c9e5`: 2 reglas identificadas.

Predicciones escritas + HCL escrito por el alumno. **Primera versión del HCL: sin `.id` al final de las referencias**. `terraform validate` **falla** con dos errores:

```
Error: Incorrect attribute value type
  aws_security_group.db is object with 14 attributes
  Inappropriate value for attribute "security_group_id": string required, but have object.

Error: Incorrect attribute value type
  aws_security_group.ec2 is object with 14 attributes
  Inappropriate value for attribute "referenced_security_group_id": string required, but have object.
```

**Reacción del alumno**: añadir comillas alrededor de las expresiones para hacer callar el validator. `"aws_security_group.db"` y `"aws_security_group.ec2"` como strings literales. **Segundo `validate` pasó Success** — semánticamente mal pero sintácticamente aceptado (el schema espera string, y string literal es un string).

Ni el alumno ni el profesor cazaron la pista visual en el plan pre-import:

```
+ referenced_security_group_id = "aws_security_group.ec2"
+ security_group_id            = "aws_security_group.db"
```

**Import ejecutado limpio** (AWS leyó los valores reales `sg-036...` y `sg-0d3...` y los escribió en state). Plan post-import lanzó bandera roja:

```
-/+ destroy and then create replacement
~ referenced_security_group_id = "sg-036772953179b5905" -> "aws_security_group.ec2"
~ security_group_id            = "sg-0d3abd728ee60c9e5" -> "aws_security_group.db" # forces replacement
```

**STOP inmediato del profesor**: bajo ningún concepto ejecutar `apply`. Análisis mecánico:

- HCL tenía strings literales (con comillas).
- State tenía los `sg-...` correctos (AWS API los leyó bien al importar).
- Plan comparó HCL literal vs state real → drift permanente.
- `security_group_id` es atributo `ForceNew` en el schema → `-/+` (destroy + create).
- Si se ejecutara `apply`: regla vieja borrada en AWS, regla nueva rechazada por AWS (string `"aws_security_group.db"` no es `sg-...` válido). Resultado: **regla PostgreSQL borrada, tu EC2 no puede conectar a la DB, app rota**. Escenario peor que apply-que-corrompe: **apply-que-borra-y-no-recupera**.

### Corrección sin apply

HCL editado: `"aws_security_group.db"` → `aws_security_group.db.id` (sin comillas, con `.id`). Idem con `.ec2`. `validate` Success, `plan` → `No changes`, serial estable en 23 (edit HCL no incrementa serial). `terraform state show` confirmó que el state siempre tuvo los `sg-...` correctos — el problema era exclusivo del HCL.

### Aprendizajes empíricos del incidente (candidatos S12-F)

> **Regla operativa (candidata S12-F #6):** Cuando el plan pre-import muestra valores extraños en atributos de referencia (strings sospechosos con nombres de recursos entre comillas, `known after apply` donde debería haber un ID literal resuelto), parar y analizar antes del import. Los errores de referencias mal escritas se manifiestan primero en el plan pre-import, no en el import. Aplica también al pedagogo (fallo del profesor al no cazar la pista).

> **Regla operativa (candidata S12-F #7):** En HCL de Terraform, referencias a otros recursos se escriben **SIN comillas** y con el atributo específico al final. `aws_security_group.db.id`, no `"aws_security_group.db"` ni `aws_security_group.db`. Casos:
>
> | Sintaxis | Interpretación | Uso |
> |----------|---------------|-----|
> | `aws_security_group.db.id` | Referencia al atributo `id` | Correcto |
> | `aws_security_group.db` | Referencia al objeto completo | Solo válido en pocos contextos (error de "string required") |
> | `"aws_security_group.db"` | String literal | Casi siempre error semántico, aunque pase validate |
> | `"${aws_security_group.db.id}"` | Interpolación antigua | Válida pero deprecada, no usar |
>
> Regla mnemotécnica: **referencias sin comillas, strings con comillas**. Si mezclas, Terraform interpreta comillas primero.

> **Regla operativa (candidata S12-F #8):** El ciclo pactado no es ceremonia para el caso feliz; es red de seguridad para el caso malo. Su valor se demuestra exactamente cuando algo va mal, no cuando todo va bien. El caso feliz lo justifica ex-ante; el caso malo lo confirma ex-post. **Sin ciclo pactado, este incidente habría destruido la regla PostgreSQL y roto la conexión EC2↔DB con deadline RDS 31 ago encima**.

## Bloque 9 (26 ago) — Import egress `db_all_out` + verificación de referencias

Ciclo cerrado limpio. HCL con `security_group_id = aws_security_group.db.id` correctamente escrito (sin comillas, con `.id`). Sub-predicción del alumno sobre `security_group_id` en plan pre-import (`aws_security_group.db.id`) vs realidad (`"sg-0d3abd728ee60c9e5"`). Modelo mental refinado:

> **Regla operativa (candidata S12-F #9):** El plan resuelve referencias HCL a valores finales antes de mostrar el output. Si en HCL escribes `aws_security_group.db.id`, en plan verás `"sg-0d3abd728ee60c9e5"`. Si en plan ves la expresión HCL literal entre comillas (`"aws_security_group.db"`), es señal de referencia mal escrita (probablemente con comillas literales). Corolario de #7.

Import `sgr-0154019e64b32845c` limpio, `No changes`, serial 24.

**db-sg completo**: contenedor + 1 ingress SG-ref + 1 egress. Serial trajectory S12-F: 17 → 18 → 19 → 20 → 21 → 22 → 23 → 24. **+7 imports individuales**.

## Bloque 10 (26 ago) — Commit db-sg (regla #31 aterrizada por caso positivo real)

Mensaje bilingüe compuesto documentando: patrón SG-references-SG con micro-segmentación por identidad, hallazgos empíricos #7 (referencias sin comillas) y #5 (naming asimétrico contenedor vs reglas), previsión S12-G.

Pasos ejecutados:
1. `git status`, `git add main.tf`, `git diff --staged`. Diff mostró 29 líneas (contenedor db + 2 reglas + reformatos de alineación en reglas ec2 anteriores).
2. **Bug real detectado por el profesor en el `git diff --staged`**: el bloque `aws_security_group.db` tiene `vpc_id = "vpc-0d36eccf71cddeda7"` (hardcodeado) en lugar de `vpc_id = aws_vpc.main.id` (referencia declarativa como el bloque ec2 análogo). Mismo antipatrón que las referencias con comillas literales del Bloque 8. `validate` no lo caza porque el string es semánticamente un `vpc-...` válido.
3. `git commit` ya ejecutado antes del hallazgo (commit local `68e186d`, no pusheado).
4. **Confirmación conjunta ejecutada**: Tole confirmó SÍ (cuerpo del commit correcto según `git log -1 --format=full`), Claude confirmó **NO** por bug detectado, Claude NO autorizó push.
5. **Regla candidata ⭐⭐⭐ #31 aterrizada por caso positivo real**: la triple confirmación existe precisamente para atrapar el caso en que uno de los tres dice NO. En los dos commits anteriores todo era SÍ y parecía teatro. En este tercer intento el mecanismo justifica su existencia.

### Corrección con `git commit --amend --no-edit`

Opción 1 pactada (amend legítimo porque commit no pusheado; alternativas 2 fixup-commit y 3 dejar-bug rechazadas). Flujo:

- Editar `main.tf`: `"vpc-0d36eccf71cddeda7"` → `aws_vpc.main.id`.
- `terraform validate` → `Success`.
- `terraform plan` → **`No changes`**. Cambio HCL cosmético: ambas expresiones resuelven al mismo `vpc-0d36eccf71cddeda7`, plan compara HCL resuelto vs state, coinciden. Regla candidata #9 replicada.
- `git add main.tf`, `git status` (ahead of origin/main by 1), `git diff --staged` (una línea).
- `git commit --amend --no-edit`. Hash cambió `68e186d` → `878df45`. Mensaje preservado idéntico.
- `git log -1 --format=full` confirmó cuerpo íntegro tras amend.
- Triple confirmación conjunta ejecutada limpia (Tole SÍ, Claude SÍ, Claude autoriza SÍ).
- `git push` → `fd46ccd..878df45 main -> main`. Push limpio.

Aprendizajes empíricos del episodio:

> **Regla operativa (candidata S12-F #10, mixta pedagogo+alumno):** Antes de `terraform validate` del primer HCL nuevo de una sesión (o del primer HCL de un patrón nuevo dentro de una sesión), pegar el bloque al chat y verificación conjunta línea por línea. La eficacia del ciclo pactado depende de que las revisiones sean visuales, no de que Terraform "diga OK". Validate no cazará strings hardcodeados que son semánticamente válidos (CIDRs, IDs con formato correcto).

> **Regla operativa (candidata S12-F #11):** El momento `git diff --staged` justifica retroactivamente todo el ciclo pactado. Si detecta 1 bug real cada 5 commits, ya paga el coste de 5 revisiones. La revisión visual es el momento donde el ojo humano añade valor que el validator + plan + import no pueden añadir.

## Aprendizajes empíricos consolidados en S12-F

### Promociones desde candidatas de S12-E (a **locked ⭐⭐⭐**)

1. **⭐⭐⭐ #26 (locked S12-F):** El `plan` pre-import es engañoso — siempre dirá `+ create` para addresses nuevos porque el state no conoce el recurso hasta el import. El diagnóstico útil ocurre en el `plan` post-import. **Aterrizada 4 veces consecutivas hoy** tras fallo inicial en operativo (regresión desde warmup verbalizado correcto).

2. **⭐⭐⭐ #28 (locked S12-F):** No todos los IDs de import son identificadores AWS opacos. Consultar sección "Import" de docs oficiales del provider antes de cada tipo de recurso nuevo. **Aterrizada empíricamente** en 4 recursos de patrón moderno (SGs + reglas) con verificación previa en cada uno.

3. **⭐⭐⭐ #30 (locked S12-F):** El mensaje de commit se verifica con `git log -1 --format=full` **ANTES** de `git push`. Reescribir historia pusheada no es opción en banca (protected branches). **Aterrizada empíricamente** en los 2 commits de hoy.

4. **⭐⭐⭐ #31 (locked S12-F, por caso positivo real):** La ceremonia de triple confirmación conjunta pre-push existe para atrapar el caso en que uno de los tres dice NO. **Aterrizada empíricamente** en el commit db-sg: `git diff --staged` detectó bug real (`vpc_id` hardcodeado), Claude confirmó NO, se aplicó `--amend` en local antes del push. En los dos commits anteriores parecía teatro; en este tercer intento el mecanismo justificó su existencia.

### Nuevas reglas empíricas de S12-F (candidatas)

5. **⭐⭐⭐ #S12F-1 (candidata):** El schema `Optional + Computed` observado en S12-E para `aws_route_table.route` **se replica** en `aws_security_group.ingress`/`egress` en provider 6.59.0. HCL contenedor sin bloques inline no borra las reglas existentes. Ya no es "aparece en un recurso" — es **patrón del provider AWS** para atributos que gestionan colecciones anidadas cuando existe patrón moderno separado.

6. **⭐⭐⭐ #S12F-2 (candidata):** El patrón moderno del provider AWS tiene su propia API en AWS (`describe-security-group-rules`) que devuelve los `SecurityGroupRuleId` (`sgr-...`). La API vieja (`describe-security-groups`) no los expone. Consecuencia: en brownfield con patrón moderno hay que consultar la API nueva antes de importar reglas.

7. **⭐⭐⭐ #S12F-3 (candidata):** Cuando `ip_protocol = "-1"` en `aws_vpc_security_group_egress_rule`, los atributos `from_port`/`to_port` se pueden omitir del HCL. Schema los acepta como Optional en ese contexto.

8. **⭐⭐⭐ #S12F-4 (candidata):** `git diff --staged` = staged vs HEAD. Es el comando de revisión visual antes de commit (equivale a lo que verá el peer en un PR). `git diff` sin argumentos = working tree vs staged, queda vacío tras `git add`.

9. **⭐⭐⭐ #S12F-5 (candidata):** Naming asimétrico del provider AWS en el patrón moderno de SGs. Contenedor = `aws_security_group` (histórico, retrocompatibilidad). Reglas = `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` (prefijo `_vpc_`). Confirmar tipo de recurso exacto en la doc antes de escribir import.

10. **⭐⭐⭐ #S12F-6 (candidata):** Cuando el plan pre-import muestra valores extraños en atributos de referencia (strings sospechosos con nombres de recursos entre comillas, `known after apply` donde debería haber un ID literal resuelto), parar y analizar antes del import. Aplica también al pedagogo.

11. **⭐⭐⭐ #S12F-7 (candidata):** Referencias HCL entre recursos requieren **sin comillas** y con el atributo específico al final (ej: `aws_security_group.db.id`). Escribir `"aws_security_group.db"` con comillas literales pasa validate pero el plan post-import dispara `-/+ destroy and create replacement` porque state tiene el `sg-...` real y HCL tiene el string literal. Regla mnemotécnica: **referencias sin comillas, strings con comillas**.

12. **⭐⭐⭐ #S12F-8 (candidata):** El ciclo pactado no es ceremonia para el caso feliz; es red de seguridad para el caso malo. Su valor se demuestra cuando algo va mal, no cuando todo va bien. Sin ciclo pactado, el incidente de comillas literales habría destruido la regla PostgreSQL con deadline RDS a 5 días.

13. **⭐⭐⭐ #S12F-9 (candidata):** El plan resuelve referencias HCL a valores finales antes de mostrar output. HCL `aws_security_group.db.id` → plan muestra `"sg-0d3abd728ee60c9e5"`. Si en plan ves la expresión HCL literal entre comillas, es señal de referencia mal escrita.

14. **⭐⭐⭐ #S12F-10 (candidata, mixta pedagogo+alumno):** Antes de `terraform validate` del primer HCL nuevo de una sesión o del primer HCL de un patrón nuevo, pegar el bloque al chat y verificación conjunta línea por línea. Validate no caza strings hardcodeados semánticamente válidos.

15. **⭐⭐⭐ #S12F-11 (candidata):** El momento `git diff --staged` justifica retroactivamente todo el ciclo pactado. Si detecta 1 bug real cada 5 commits, ya paga el coste de 5 revisiones. Aterrizado con caso real hoy (bug `vpc_id` hardcodeado detectado antes del push).

### Regla operativa emergente para prompts de continuación

16. **Regla derivada (aplica al pedagogo):** El ground truth del número de recursos en state es `terraform state list | wc -l`, no el conteo mental al redactar el prompt de continuación. El prompt S12-F afirmaba "13/13 recursos de red importados" cuando eran 14 (enumeró los 14 pero contó 13). Verificar con `wc -l` antes de escribir cifras resumen en prompts.

## Estado exacto al cierre de S12-F

Terraform:
- CLI 1.15.8, provider AWS 6.59.0 (~> 6.58 en versions.tf).
- Backend S3 con `use_lockfile = true` (native locking).
- State en `s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate`, serial **24**, lineage sin cambios, resources = **21**.
- `terraform plan` global = `No changes`.

Recursos en state (21):
- **Red (14, desde S12-E):** `aws_vpc.main`, `aws_subnet.private_1a`, `aws_subnet.private_1b`, `aws_subnet.public_1a`, `aws_subnet.public_1b`, `aws_internet_gateway.task_manager`, `aws_route_table.public`, `aws_route_table.private_1a`, `aws_route_table.private_1b`, `aws_route.public_to_igw`, `aws_route_table_association.public_1a`, `aws_route_table_association.public_1b`, `aws_route_table_association.private_1a`, `aws_route_table_association.private_1b`.
- **Seguridad (7, nuevos en S12-F):** `aws_security_group.ec2`, `aws_vpc_security_group_ingress_rule.ec2_ssh_home`, `aws_vpc_security_group_ingress_rule.ec2_http_home`, `aws_vpc_security_group_egress_rule.ec2_all_out`, `aws_security_group.db`, `aws_vpc_security_group_ingress_rule.db_postgres_from_ec2`, `aws_vpc_security_group_egress_rule.db_all_out`.

Commits desde S12-E:
- `fd46ccd` feat(infra): import ec2 security group and its rules
- `878df45` feat(infra): import db security group and its rules (rehecho con `--amend` antes del push)

Pendiente commitear en frío:
- `bitacora/Sesion12-Import-Checklist.md` con las 7 casillas nuevas tachadas.
- `bitacora/Sesion12-F-AWS-Diario.md` (este documento).

RDS: `stopped`. Contador de 7 días con margen (última verificación 26 ago; deadline auto-arranque 31 ago = 5 días margen). IP casa: `88.11.202.24`, sin rotación durante la sesión (verificado 26 ago con `curl -s https://ifconfig.me`).

## Pendientes para S12-G (~2h estimadas, matutinas)

Bloque de conectividad interna (VPC Endpoint, arrastrado desde S12-F) y arrancar bloque de aplicación:

1. **VPC Endpoint**: `aws_vpc_endpoint` con `service_name = "com.amazonaws.eu-west-1.s3"` + `route_table_ids = [aws_route_table.private_1a.id, aws_route_table.private_1b.id]`. Este import cerrará el capítulo de "ruta `pl-6da54004` sin owner Terraform" — el endpoint adoptará ownership de la ruta al ser el atributo `route_table_ids` el que gestiona la asociación con las RTs. **Verificación empírica esperada**: ¿cómo se comporta el schema del atributo `route_table_ids` respecto al Escenario X? Predicción teórica: probable Optional + Computed (patrón del provider aplicado a colecciones). No asumir — verificar empírico.
2. **S3 uploads** + sub-recursos (`aws_s3_bucket`, `aws_s3_bucket_policy`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block`). Verificar empíricamente si `aws_s3_bucket` en provider 6.x separa versioning/encryption/policy en recursos independientes (probable — mismo patrón moderno de granularidad).
3. **IAM Role + Instance Profile** para la EC2 (permisos hacia S3 uploads).
4. **EC2** (`aws_instance.task_manager_ec2`). Verificación empírica: SG asociado + Instance Profile + AMI + subnet + key pair.
5. **RDS** (`aws_db_instance.task_manager_db`). Verificación crítica: parameter group, security groups, subnet group.
6. **`terraform plan` global final** = `No changes` en la infra completa.
7. **ADRs pendientes**: A2 (Terraform vs CloudFormation/CDK), A3 (Secrets Manager vs Parameter Store), A9 candidato (política RDS Stop timer), A10 candidato (Main RT sin gestionar), A11 candidato (VPC Endpoint gestiona ruta, no `aws_route` explícito), A12 candidato (default SG sin gestionar).

**Prioridad si el tiempo se acorta**: VPC Endpoint primero (cierra bloque S12-F pactado), después EC2 (permite verificar `task-manager-api` funcional). RDS + IAM roles + S3 después si sobra.

### Reglas operativas OBLIGATORIAS para S12-G

- Al arrancar: `git log --oneline -5` + `git status` + `terraform plan` + `jq '.serial'` (esperado: 24) + `aws rds describe-db-instances` (esperado: `stopped`). Si algo no cuadra, PARAR antes de escribir HCL.
- **Verificar RDS**: si hoy es ≥ 31 ago 2026 (deadline auto-arranque), estado será `available` o `starting`. Parar + `aws rds stop-db-instance` + esperar `stopped` antes de tocar Terraform.
- Ciclo pactado obligatorio con predicción escrita en cada paso — regla ⭐⭐⭐ #24 aplicada sin excepción.
- Vocabulario nuevo (VPC Endpoint tipos Gateway vs Interface, IAM Role vs Instance Profile) introducido explícitamente antes de aparecer en preguntas o HCL — regla nueva de S12-D. **Máximo 3 conceptos consecutivos con verificación entre cada uno, después toca ver realidad** — regla derivada de S12-F por sobrecarga en Bloque 2.
- Verificación conjunta línea por línea del primer HCL nuevo antes de `terraform validate` — regla candidata S12-F #10. Aplicar especialmente a bloques con referencias entre recursos (candidatos a bug de comillas literales).
- Triple confirmación conjunta obligatoria antes de `git push` con formato explícito (Tole confirma / Claude confirma / Claude autoriza) — regla ⭐⭐⭐ #31.
- Formato 24h en la duración pactada al arrancar la sesión.
- Bitácora S12-F releída antes del warmup — regla operativa 48-72h.

## Meta-observaciones de método

1. **Error de calibración pedagógica del profesor en Bloque 2 (25 ago)**. Se metieron 4 conceptos + 4 verificaciones + Escenarios X/Y sobre schema en ~45 min de "vocabulario previo al HCL". Feedback del alumno: "buen bloque me has metido, eh?". Regla derivada:

    > **Máximo 3 conceptos consecutivos con verificación entre cada uno, después toca ver realidad (`describe-*` o consola AWS)**. Si el vocabulario necesita más conceptos, dividir en dos sesiones o intercalar con descubrimiento AWS. La regla nueva de S12-D ("vocabulario antes del HCL") no autoriza densidad ilimitada — sigue vigente el principio de "conceptos por bloque cognitivo, no por dominio conceptual".

2. **Error del profesor: "trampa deliberada" inventada sobre atributo obligatorio faltante en `aws_security_group`**. El profesor insinuó que faltaba un atributo obligatorio en el HCL del contenedor ec2. Falso. El alumno predijo correctamente `success` y no se dejó llevar por la pista. Regla derivada:

    > Cuando el profesor no sabe con certeza el schema, marcarlo como "verificar" en vez de inventar trampas didácticas. Aplica misma regla que se le pide al alumno. **Segunda vez en dos sesiones consecutivas que el profesor falla esta regla propia**. Consolidar con formulación explícita: **antes de emitir predicción teórica con confianza sobre schema del provider, formular con "sospecho X pero no seguro, verificamos"**.

3. **Error del profesor: no cazó pista visual en plan pre-import de referencias con comillas literales**. El output mostraba `+ referenced_security_group_id = "aws_security_group.ec2"` — indicativo claro de comillas literales en HCL. Volumen de output grande + prisa entre pasos hizo que la pista pasara desapercibida. Regla derivada:

    > **Sub-regla del ciclo pactado (aplica al pedagogo):** cuando se pide sub-predicción específica sobre un atributo (dos opciones dadas), verificar output contra esas dos opciones antes de dejar avanzar. Si sale una tercera opción no prevista, es señal fuerte de anomalía — parar y analizar. Aplica también a valores extraños en atributos de referencia (strings entre comillas que parecen expresiones HCL).

4. **Alumno se adelantó al push del commit ec2-sg sin triple confirmación conjunta**. Segunda sesión consecutiva de este patrón (S12-E + S12-F). El profesor propuso ceremonia artificial explícita (formato Tole confirma / Claude confirma / Claude autoriza) para aterrizar la regla candidata #31 en el siguiente commit. **Aterrizó en el segundo commit del día por caso positivo real** (Claude confirmó NO por bug detectado en `git diff --staged`), justificando la ceremonia. Regla #31 promocionada a locked por caso positivo, no solo por ceremonia.

5. **Recuento incorrecto en el prompt de continuación S12-F redactado por el profesor**. El resumen decía "13/13 recursos de red importados" cuando eran 14 (enumeraba los 14 nombres pero contó 13). Detectado por evidencia empírica del alumno (`terraform state list | wc -l` → 14). Sin escándalo, corregido en este diario. Regla derivada:

    > **El ground truth del número de recursos en state es `terraform state list | wc -l`, no el conteo mental al redactar el prompt de continuación**. Aplica al pedagogo antes de escribir cifras resumen.

6. **Urgencia médica interrumpió la sesión el 25 ago (~07:45) sin posibilidad de aviso**. Alumno se disculpó al día siguiente. Reanudación gestionada con Bloque 0 nuevo completo (regla banca: cualquier reanudación no continua = verificación de estado completa). Regla derivada:

    > **Sesión interrumpida ≠ sesión continua**. Al reanudar tras hueco > 6h (o al día siguiente), Bloque 0 completo obligatorio: `git log`, `git status`, `terraform plan`, `jq '.serial'`, `aws rds describe-db-instances`, `curl ifconfig.me` (si hay reglas SG con IP residencial). Tratar como nueva sesión que hereda contexto, no como continuación literal.

7. **Bug de `vpc_id` hardcodeado en contenedor `aws_security_group.db` detectado en `git diff --staged`**. Mismo antipatrón que el bug de comillas literales del Bloque 8. El pedagogo no verificó HCL línea por línea antes del `validate` porque estaba en modo ágil tras 6 imports fluidos. Regla derivada:

    > **Ritmo ágil no autoriza saltarse verificación conjunta del HCL nuevo**. Cuando el patrón está aterrizado y los imports fluyen, la fatiga del pedagogo hace que baje la guardia sobre el HCL. Introducir checkpoint explícito: antes del `validate` del primer recurso de cada sub-bloque temático, pegar HCL completo al chat + verificación conjunta línea por línea. Ceremonia añadida a la ceremonia = disciplina banca.

8. **`git commit --amend --no-edit` aplicado legítimamente sobre commit no pusheado**. Corrección del bug `vpc_id` hardcodeado sin violar disciplina banca (commit aún local). Alternativas (fixup commit, dejar bug) descartadas conscientemente. Aterrizaje del músculo `--amend --no-edit`: útil de saber que preserva el mensaje del commit y solo cambia el árbol.

9. **Duración real de la sesión (~4h25 en dos ventanas) vs pactado en cada arranque (2h el 25, 3h16 el 26)**. Sesión larga por interrupción médica + amplitud de scope inicial. Cierre a las 09:50 aprox del 26 ago con margen para diario en caliente. Sin ceder a "meter algo más" (VPC Endpoint quedó fuera pese a haber tiempo — decisión pactada previamente respetada). Buena disciplina operativa.

10. **Bitácora escrita por el profesor en modo "notas borrador"** a petición explícita del alumno ("Haz las notas siguiendo el formato que te he pasado"). Igual que S12-E, se pactó paralelización. **Este documento requiere revisión y adaptación por el alumno antes de commitear**. No es producto final — es andamiaje escrito para acelerar el paso "en frío" sin sacrificar la reflexión personal del alumno.
