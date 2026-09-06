# Sesión 12-G — Import brownfield VPC Endpoint S3 Gateway (cierre bloque conectividad interna) + hallazgo Optional+Computed como patrón arquitectónico

**Fecha:** 6 septiembre 2026 (domingo, ventana matutina). Sesión tras hueco de 10 días desde S12-F (26 ago) por prueba técnica de trabajo entregada 1 sep sin respuesta a día de hoy.
**Duración:** ~3h honestas (08:00 - ~11:00). Estimación inicial 2h expandida a 3h por regla operativa "sesión interrumpida ≠ sesión continua" que exige Bloque 0 completo + warmup extendido tras hueco largo.
**Estado:** Cierre limpio del bloque de conectividad interna con 1 solo import (VPC Endpoint Gateway hacia S3). Total 22/22 recursos gestionados (14 red + 7 seguridad + 1 VPC Endpoint). `terraform plan` global = `No changes`, serial 25. Commit `b7c1ad4` pusheado a `origin/main` limpio con triple confirmación conjunta ejecutada (por 4ª vez consecutiva desde S12-F). RDS: `stopped` verificado al arrancar, sin auto-arranque durante la sesión (contador reseteado el 30 ago aprox por AWS tras el deadline del 31 ago). IP casa: `88.11.202.24` sin rotación durante los 10 días. Bloque IAM Role + Instance Profile NO entró — pactado formalmente para S12-H sin drama. Sesión con **dos aprendizajes empíricos de peso**: (1) patrón `Optional + Computed` promocionable a decisión arquitectónica del provider AWS (4ª y 5ª evidencia consecutiva en 3 sesiones), (2) regla nueva S12-F #10 (verificación conjunta línea por línea del HCL antes de validate) aterrizada por caso positivo real en su primer día de aplicación efectiva — cazó bug de referencias sin `.id` que habría reproducido el patrón destructivo de S12-F.

## Objetivo pedagógico

Cerrar el bloque de conectividad interna pendiente desde S12-F importando el **VPC Endpoint Gateway hacia S3** (`vpce-0122ecf0ee7226fb9`), delegando en él la gestión de la ruta `pl-6da54004 → vpce-...` que hoy existe en varias route tables sin owner Terraform. Objetivos empíricos paralelos: (i) verificar que el schema `Optional + Computed` observado en atributos anidados (S12-E `route`, S12-F `ingress`/`egress`) **se replica también en tipos de atributo distintos** (listas de referencias externas + documentos JSON generados por AWS); (ii) introducir vocabulario nuevo denso (Prefix Lists AWS-managed, Gateway vs Interface, ENI, AZ como refresco) tras hueco de 10 días respetando regla máximo-3-conceptos; (iii) validar empíricamente la regla nueva S12-F #10 en su primer día de aplicación operativa — la sesión anterior no tuvo casos donde disparara, hoy sí.

## Bloque 0 — Reanudación tras hueco de 10 días (protocolo reforzado)

Regla nueva S12-F obligatoria: **sesión interrumpida > 6h = Bloque 0 completo, no pase directo**. Aplicable con más razón a 10 días. Verificación intensificada:

- `git log --oneline -5` → HEAD en `35eaf8c docs(bitacora): add S12-F diary`, `origin/main` sincronizado. Hash coincide con lo que el prompt S12-G esperaba.
- `git status` → `working tree clean`.
- `terraform plan` → `No changes`, 21 recursos refreshed.
- `terraform state list | wc -l` → **21**.
- `aws s3 cp - | jq '.serial'` → primer intento del alumno con comando mal escrito (`aws s3 cp - | jq '.serial'` sin S3 path ni guion final). Corrección inmediata del profesor con formulación completa (`aws s3 cp s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate - | jq '.serial'`). Serial confirmado: **24**.
- Estado RDS verificado con `aws rds describe-db-instances --db-instance-identifier task-manager-db --query 'DBInstances[0].DBInstanceStatus' --output text` → `stopped`. Sin auto-arranque activo — asumimos que AWS arrancó el 30-31 ago y Tole (o AWS auto-detección) lo re-paró en algún momento entre 26 ago y 6 sep sin dejar rastro en la memoria del alumno. **Contador reseteado** — nuevo deadline auto-arranque 12 sep aprox.
- IP casa: `curl -s https://ifconfig.me` → `88.11.202.24`. Sin rotación durante los 10 días. Reglas SG SSH 22 y HTTP 8080 siguen alineadas con IP real. Bien.

**Recalibración de scope explícita**: prompt S12-G apuntaba a "VPC Endpoint + IAM Role + Instance Profile = 3 imports". Recalibración del profesor a **solo VPC Endpoint** por:
- Hueco de 10 días erosiona modelo mental → warmup + vocabulario tomarán más tiempo.
- VPC Endpoint tiene verificación empírica crítica sobre `route_table_ids` (Escenario X vs Y) que merece tiempo sin prisa.
- IAM Role tiene JSON heredoc (`assume_role_policy`) propenso a errores, no material para sesión con warmup largo previo.

Alumno acepta recalibración conservadora. Ventana inicial 2h. **Extendida a 3h por Tole** durante Bloque 3 sin drama tras ver que ritmo real superaba lo planificado.

Nota derivada del error del comando `jq`: **regla operativa candidata** — los comandos AWS CLI + jq no se memorizan; se guardan como snippets. La estructura sí se aprende (`aws <service> <verb>-<resource>`) pero los filtros/queries JMESPath se copian y adaptan. Pregunta que hizo el alumno más adelante sobre esto (Bloque 3) confirmó la duda como legítima, no ignorancia.

## Bloque 1 — Warmup extendido: repaso de conceptos de S12-F tras 10 días

Cinco preguntas de predicción antes de arrancar VPC Endpoint. Las críticas: Q1 (Optional+Computed, aplicable directamente hoy al schema de `aws_vpc_endpoint.route_table_ids` y `policy`) y Q2 (referencias HCL sin comillas, el HCL de hoy tendrá 3 referencias dentro de una lista, exactamente el tipo de bloque donde S12-F reventó).

Antes de arrancar, alumno declaró: "me va a costar un mundo el warmup, ten paciencia". Aceptado sin drama por el profesor. Regla operativa emergente: **cuando el alumno anuncia dificultad tras hueco largo, aceptar sin drama y reforzar con ejemplo directo tras dos fallos consecutivos en lugar de tras uno**.

### Preguntas y desempeño

| # | Tema | Predicción del alumno | Realidad | Correcto |
|---|------|----------------------|----------|----------|
| 1 (crítica) | Escenario X en `aws_security_group.ingress`/`egress`: qué muestra plan post-import + nombre del comportamiento del schema + contraste con Optional puro | (a) "marca un update queriendo borrar reglas -/+ replace". (b) "porque el name va entre comillas, no sé el nombre exacto Optional+Compute". (c) "se lo tragaría??" | **Tres partes falladas** en primer intento. Regresión clara: en S12-F el concepto se aterrizó verbalmente y empíricamente, en S12-G tras 10 días se perdió el detalle mecánico. Correcciones sin softening: (a) plan sale `No changes`, no drift. (b) el nombre es `Optional + Computed` (dos palabras), no relacionado con comillas del name — confusión de capas (schema del provider vs sintaxis HCL). (c) Optional puro intentaría borrar; Optional+Computed respeta lo que hay. **Refuerzo con reformulación en palabras propias**: aterrizada al segundo intento con formulación "si no lo declaro se respeta lo que hay en AWS/state" + ejemplo real de S12-F. | Fallada, aterrizada al 2º intento con refuerzo |
| 2 (crítica) | Referencias HCL correctas + tres formulaciones alternativas erróneas + regla mnemotécnica | (a) `vpc_id = aws_vpc.main.id` — **correcto**. (b) "las tres fallarían" — correcto en dirección pero sin detalle mecánico. (c) "duda". | (a) correcto. (b) refuerzo con detalle recurso por recurso: sin `.id` sin comillas falla validate (`object` vs `string`), con comillas sin `.id` pasa validate pero rompe post-import (`-/+ destroy and create`), con comillas y `.id` idem. Referencia al bug real de S12-F (ingress `db_postgres_from_ec2` con comillas literales). (c) profesor cerró la regla mnemotécnica: "referencias sin comillas, strings con comillas. Si mezclas, Terraform interpreta comillas primero". Reformulación del alumno correcta al primer intento tras refuerzo. | Fallada (c), aterrizada tras refuerzo |
| 3 | Anatomía del ciclo git entre editar main.tf y push: comandos ordenados, qué caza `git diff --staged`, formato triple confirmación | Enumeración parcial con 4 errores: (i) `git add .` en vez de `git add main.tf` (antipatrón brownfield IaC). (ii) `git commit -m "..."` no sirve para bilingüe multilínea. (iii) `git diff --staged` mencionado pero fuera de secuencia. (iv) `git log --oneline -1` redundante. **Y omisión importante**: triple confirmación mencionada como concepto pero no integrada en la secuencia. **No contestó (b)** sobre qué caza el diff que validate no caza. | Correcciones sin softening: nunca `git add .` en repo IaC, siempre `git commit` sin `-m` para editor multilínea, `git diff --staged` va entre `add` y `commit`, triple confirmación va entre `log` y `push`. Ejemplo real S12-F: commit db-sg donde `git diff --staged` cazó bug `vpc_id` hardcodeado. Alumno reformuló correctamente al 2º intento. | Fallada (a) parcial y (b), aterrizada tras refuerzo |
| 4 (⭐⭐⭐ #3 S12-A) | Terraform compara HCL vs state en plan pre-import: qué muestra + qué compara + cuándo es fiable | Tres partes correctas al primer intento: "+ create", "compara HCL vs state, lo que escribo en HCL con lo que gestiona Terraform", "después del import ya que lo que hay en AWS es lo que hay en state". | **Sólida en primer intento**. Concepto más veces reforzado del módulo, sólido en modelo mental. Complementos menores del profesor: precisión sobre state = fichero remoto en S3 backend, y que plan post-import es fiable solo si import terminó con "Import successful!". | Aprobado con complementos |
| 5 | Ciclo pactado como red de seguridad: antipatrón de apply directo + caso real S12-F + regla derivada | (a) "hay que seguir todo el ciclo... porque puede pasar el validate y la visualización del diff nos muestre error" — mezcla ciclo Terraform con ciclo git. (b) "las comillas en el recurso, hubiera borrado lo que tenía y habría creado otro recurso" — correcto, telegráfico. (c) "duda". | (a) refuerzo: son dos ciclos distintos, uno protege AWS de apply, otro protege el fichero contra bugs semánticos antes de commitear. Etapas específicas del ciclo Terraform que se saltarían: plan pre-import + import + plan post-import. (b) correcto en dirección, con detalle: `sgr-0e83f6e7dc1512630` borrada, regla nueva rechazada por AWS. (c) profesor cerró la regla derivada: "el ciclo pactado se justifica ex-post porque su valor solo se ve cuando algo va mal — cuando todo va bien parece ceremonia excesiva, cuando algo va mal es la única red que evita apagar producción". Formulación banca vs formulación ingeniería personal. | Parcial (a) confusión ciclos, aterrizada tras refuerzo |

### Resultado global del warmup

Duración real: **~35 min** vs 15 min planificados. **Extensión x2.3** por refuerzos post-hueco de 10 días. Esperable, sin drama. Balance:

- **Ambas críticas** (Q1 Optional+Computed, Q2 referencias HCL) aterrizadas al segundo intento con refuerzo directo. Criterio del prompt cumplido para seguir.
- Q3 (git) parcial con 4 errores mecánicos + omisión, aterrizada tras refuerzo. Regla operativa emergente: **el ciclo git y el ciclo Terraform son dos ciclos distintos**, el alumno los confundía en Q5 también.
- Q4 (HCL vs state) sólida en primer intento. Concepto más consolidado del módulo.
- Q5 (ciclo pactado) parcial con confusión ciclos, aterrizada tras refuerzo.

Vocabulario que se cayó durante warmup: **ENI y AZ**. Alumno subió excerpts de mensajes previos preguntando qué eran. Refuerzo del profesor con definiciones completas + aplicación al concepto del día (ENI = tarjeta de red virtual, aplicable a Interface Endpoints; AZ = availability zone, aplicable a alta disponibilidad de Interface Endpoints). Regla operativa emergente: **vocabulario básico aterrizado en sesiones previas puede caerse tras hueco de 10 días, aceptar preguntas de refresco sin considerarlas regresión — es consecuencia esperada del hueco, no fallo pedagógico**.

## Bloque 2 — Vocabulario VPC Endpoint (regla máximo-3-conceptos aplicada)

Regla nueva de S12-F obligatoria: máximo 3 conceptos consecutivos con verificación entre cada uno. Aplicada estrictamente hoy tras error de calibración de S12-F Bloque 2 (4 conceptos + 4 verificaciones + Escenarios X/Y en 45 min).

### Concepto 1 — Qué es un VPC Endpoint mecánicamente

Explicación con analogía técnica adecuada al perfil backend (microservicio interno vs API pública). Introducción del problema (EC2 privada → S3 sin VPC Endpoint = salir a Internet vía NAT, con costes de latencia + facturación NAT Gateway + superficie de ataque). Solución VPC Endpoint (dispositivo virtual dentro de VPC que expone servicio AWS internamente, tráfico se queda dentro de red AWS).

**Verificación 1**: pregunta sobre qué es el `pl-6da54004` que aparece como destino de la ruta gestionable en las RTs privadas. Alumno dijo "duda" — respuesta honesta, concepto Prefix List no aterrizado previamente. Refuerzo del profesor con explicación completa:

- **Prefix List AWS-managed** (`pl-...`) = objeto AWS con nombre que contiene CIDRs actualmente asignados a un servicio en una región. AWS lo mantiene actualizado. Route table dice "destino = `pl-...`", AWS resuelve internamente a los cientos de CIDRs del servicio.
- Dos tipos: **AWS-managed** (los mantiene AWS, no gestionables — el `pl-6da54004` es de este tipo, corresponde a S3 en eu-west-1) y **Customer-managed** (los creas tú con tus propios CIDRs, fuera de scope).

**Verificación 1 reformulada** tras refuerzo: pregunta "por qué NO importamos la ruta `pl-6da54004 → vpce-...` como aws_route explícito". Alumno respondió parcialmente: "la gestiona AWS directamente la ruta pl-6da..., la ha creado él, si no es eso duda". Refuerzo con corrección: **AWS mantiene la Prefix List (`pl-6da54004`), pero la ruta que la usa** (`pl-6da54004 → vpce-...` dentro de las RTs) **es creada por el VPC Endpoint como efecto secundario de declararse con `route_table_ids`**. Dueño lógico = `aws_vpc_endpoint`, no un `aws_route` independiente. Antipatrón declarar los dos: conflicto de ownership → drift alternante. **Regla mnemotécnica derivada**: "una entidad AWS tiene un único dueño lógico en Terraform state".

### Concepto 2 — Gateway vs Interface

Introducción de los dos tipos con contraste sistemático:
- **Gateway**: solo S3 + DynamoDB. Gratis. Sin ENIs. Se conecta a route tables. Tráfico desde dentro de VPC.
- **Interface**: casi todos los demás servicios (SQS, SNS, Secrets Manager, KMS, ECR, etc.). Paga (~$7-8/mes por ENI en 1 AZ + $0.01/GB). Crea ENIs con IPs privadas en subnets. Tráfico desde dentro de VPC + opcionalmente on-prem.

Explicación mecánica: Tu caso hoy = Gateway hacia S3.

**Verificación 2**: (a) qué tipo de endpoint usarías para Secrets Manager, (b) por qué AWS regala Gateway gratis. Alumno respondió parcialmente correcto: (a) Interface con justificación correcta, (b) "para que uses DynamoDB y S3 en vez de otras alternativas (duda)". Refuerzo con formulación memorable: **"Gateway es gratis porque S3 y DynamoDB son productos ancla — AWS los subvenciona en conectividad para venderlos en volumen"**. Concepto aterrizado.

### Concepto 3 — Cómo Terraform modela el VPC Endpoint

Recurso único `aws_vpc_endpoint`. Atributos comunes (`vpc_id`, `service_name`, `vpc_endpoint_type`, `policy`, `tags`). Específicos de Gateway (`route_table_ids`). Específicos de Interface (`subnet_ids`, `security_group_ids`, `private_dns_enabled`). ID de import opaco (`vpce-...`).

**Empírico crítico anunciado antes del ciclo**: el schema del atributo `route_table_ids` — ¿es Optional+Computed o Optional puro? Predicción teórica del profesor: Optional+Computed (patrón replicado). Verificaremos empíricamente. Similarmente para `policy`.

**Verificación 3**: (a) contar referencias sin comillas en el HCL modelo, (b) qué cambiaría al añadir un segundo VPCE hacia DynamoDB. Alumno respondió correctamente al primer intento en ambas partes con matiz menor (no explicitó que el address del recurso también cambia).

**Balance del Bloque 2**: 3 conceptos consecutivos con verificación entre cada uno, regla máximo-3 respetada. Duración real ~50 min (vs 15-20 planificados) por refuerzos en verificaciones y por vocabulario nuevo denso (Prefix Lists, tipos de endpoint, atributos específicos por tipo). Aceptable dado el hueco de 10 días.

## Bloque 3 — Descubrimiento realidad VPC Endpoint (sorpresa gorda)

Objetivo pactado: extraer del VPC Endpoint real los datos exactos para el HCL + verificar la ruta `pl-6da54004` en las 2 RTs privadas.

**Pregunta legítima del alumno antes de ejecutar**: "los comandos describe, ¿tendría que aprendermelos de memoria?". Respuesta del profesor sin softening pero constructiva:

> **Regla operativa candidata:** No se memorizan comandos AWS CLI. Se memorizan estructuras (`aws <service> <verb>-<resource-plural>`) + convenciones de verbos (`describe-*`, `list-*`, `get-*`, `create/delete/modify-*`) + recursos del stack habitual. Los comandos concretos con sus filtros/queries JMESPath se guardan como snippets personales, se copian de doc, se generan con LLMs y se validan. En producción nadie los recita de memoria. Herramientas que ayudan: `aws <service> help`, autocompletion, `aws-shell`. **Memoriza estructuras, no invocaciones**.

Comandos ejecutados:

**Descubrimiento principal** con `aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=vpc-0d36eccf71cddeda7" --output json`:

- 1 VPC Endpoint confirmado: `vpce-0122ecf0ee7226fb9`.
- `ServiceName`: `com.amazonaws.eu-west-1.s3`.
- `VpcEndpointType`: `Gateway`.
- **`RouteTableIds`: 3 IDs, no 2** — sorpresa gorda:
  - `rtb-07f9363299f58b0b3` (RT **pública**, `aws_route_table.public`).
  - `rtb-0be3472cd9db77b55` (RT privada 1a).
  - `rtb-09250fc195ff54f09` (RT privada 1b).
- `State`: `available`.
- `PolicyDocument`: policy default AWS (`{"Version":"2008-10-17","Statement":[{"Effect":"Allow","Principal":"*","Action":"*","Resource":"*"}]}`).
- `Tags`: `Name = "task-manager-vpce-s3"`.
- `CreationTimestamp`: `2026-08-02T15:23:06+00:00` — creado en fase bootstrap manual de S11 antes del roadmap Terraform.

**Descubrimiento secundario** con `aws ec2 describe-route-tables --query ...`: confirmó que la ruta `pl-6da54004 → vpce-0122...` existe en las 3 RTs (pública + 2 privadas), todas con `Origin: CreateRoute` y `State: active`.

### Análisis de la sorpresa — 3 RTs vs 2 esperadas

El prompt S12-G decía "route table IDs a asociar: `aws_route_table.private_1a.id` + `aws_route_table.private_1b.id`". Dos. Realidad AWS = tres. Alguien (probablemente Tole en S11 sin darle importancia) asoció también la RT pública.

**Semánticamente cuestionable**: subnets públicas ya alcanzan S3 vía IGW más rápido y sin coste extra. La ruta al VPC Endpoint en la RT pública es redundante. Pero **está ahí en AWS**, y la disciplina brownfield manda respetar la realidad antes de refactorizar.

Dos caminos analizados conjuntamente:

- **Camino A**: importar tal cual con 3 RTs. Plan post-import = `No changes`. Realidad AWS respetada. Deuda técnica anotada para corrección futura.
- **Camino B**: HCL con solo 2 privadas → drift → apply modificaría AWS (desasociar RT pública). Cambio benigno pero es el primer apply real del roadmap, no queremos mezclar import + cambio de intención en la misma sesión.

**Alumno eligió A** con formulación "todo esto es nuevo para mí". Decisión pactada. Deuda documentada:

> **Deuda técnica S12-G #1** (candidato ADR-A13): `aws_vpc_endpoint.s3` importado con `route_table_ids = [public, private_1a, private_1b]` para respetar realidad brownfield. La RT pública asociada al VPC Endpoint es probable error histórico de bootstrap (S11 manual) sin valor operativo — las subnets públicas ya alcanzan S3 vía IGW más rápido y sin extra. Corrección diferida a sesión de "primer apply del roadmap" (S12-I o S13).

## Bloque 4 — Import VPC Endpoint (regla S12F-10 aterrizada por caso positivo real)

### Escritura del HCL — bug capturado en verificación conjunta línea por línea

Address propuesto: `aws_vpc_endpoint.s3`. Pactado con alumno.

Alumno escribió HCL con **bug crítico**: 4 referencias sin sufijo `.id`.

```hcl
# BUG — versión inicial
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.main                                    # falta .id
  vpc_endpoint_type = "Gateway"
  service_name = "com.amazonaws.eu-west-1.s3"
  route_table_ids = [
    aws_route_table.private_1a,                            # falta .id
    aws_route_table.private_1b,                            # falta .id
    aws_route_table.public                                 # falta .id
  ]
  tags = {
    Name = "task-manager-vpce-s3"
  }
}
```

**Regla nueva S12-F #10 (verificación conjunta línea por línea antes de validate) cazó el bug antes de tocar CLI**. Sin esta regla:

1. `terraform validate` habría fallado con `Error: Incorrect attribute value type. Inappropriate value for attribute "vpc_id": string required, but have object.` Idéntico mensaje al que Tole vio en S12-F con `security_group_id = aws_security_group.db`.
2. Reacción predecible del alumno (evidencia histórica de S12-F): añadir comillas para hacer callar el validator (`vpc_id = "aws_vpc.main"`).
3. `validate` pasa como string literal. Import ejecuta limpio. **Plan post-import lanza `-/+ destroy and then create replacement`** porque state tiene `vpc-0d36...` real, HCL tiene string literal `"aws_vpc.main"`.
4. Si aplicara: **VPC Endpoint borrado, nuevo VPCE rechazado por AWS** → ruta `pl-6da54004` desaparece de las 3 RTs → EC2 pierde path interno a S3 → uploads rotos.

**Regla candidata S12-F #10 promocionable a locked ⭐⭐⭐**: aterrizada por caso positivo real en su primer día efectivo de aplicación. Mismo patrón de promoción que regla ⭐⭐⭐ #31 en S12-F (triple confirmación aterrizada por caso positivo cuando cazó el bug `vpc_id` hardcodeado). Regla derivada:

> **Regla operativa candidata (S12-G #1):** El patrón de bug de referencias mal escritas se repite entre sesiones. En S12-F fue con comillas literales, en S12-G fue con `.id` omitido. Ambos comparten mecánica: el alumno escribe referencia sin sintaxis exacta y el validator no da feedback semántico útil. Verificación conjunta línea por línea del HCL con referencias entre recursos es no negociable hasta que el patrón salga sin pensar (mínimo 3 sesiones consecutivas sin fallo).

HCL corregido por el alumno tras señalización del profesor:

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_1a.id, aws_route_table.private_1b.id, aws_route_table.public.id]
  tags = {
    Name = "task-manager-vpce-s3"
  }
}
```

Verificación conjunta OK: 4 referencias con `.id` sin comillas. `service_name`, `vpc_endpoint_type`, `tags.Name` como strings con comillas. Convención `referencias sin comillas, strings con comillas` respetada. Autorizado a validate.

### Ciclo pactado ejecutado limpio

1. **Predicción validate**: `success` — acertada. `terraform validate` → `Success! The configuration is valid.`
2. **Predicción plan pre-import** (5 sub-predicciones): recurso `create`, otros no afectados, `1 to add`, `route_table_ids` con 3 IDs resueltos, `policy` con `known after apply`. **Todas acertadas al primer intento**.
3. `terraform plan` → `+ create` para `aws_vpc_endpoint.s3`. Confirmado en output:
   - `route_table_ids = ["rtb-07f9...", "rtb-0925...", "rtb-0be3..."]` (3 IDs resueltos, sin rastro de expresiones HCL literales — bug ya eliminado).
   - `policy = (known after apply)` (Escenario X pre-confirmado).
   - `vpc_id = "vpc-0d36eccf71cddeda7"` (referencia `aws_vpc.main.id` resuelta al string real).
   - Multiples atributos `known after apply` esperados (`arn`, `dns_entry`, `network_interface_ids`, etc.).
4. **Predicción import**: comando `terraform import aws_vpc_endpoint.s3 vpce-0122ecf0ee7226fb9`, serial 25, mensaje `Import successful`. **Acertadas**.
5. `terraform import` → `Import successful!`
6. **Predicción plan post-import**: `No changes`, con justificación mecánica invocando Optional+Computed. **Acertada al primer intento**.
7. `terraform plan` → `No changes. Your infrastructure matches the configuration.`
8. Verificación final: `aws s3 cp - | jq '.serial'` → **25**. `terraform state list | wc -l` → **22**.

**Escenario X confirmado empíricamente por 3ª y 4ª vez consecutiva** en atributos de distintos tipos:

- **`route_table_ids`** (lista de strings): HCL declara 3 IDs, state importó los mismos 3, plan cuadra.
- **`policy`** (JSON document string): no declarado en HCL, state tiene la policy default AWS, plan `No changes`.

Optional+Computed no es exclusivo de bloques anidados (`route`, `ingress`, `egress`). Aplica también a listas de referencias externas y documentos JSON generados por AWS. **Ya no es "patrón del provider"** — es **decisión arquitectónica del provider AWS para atributos que gestionan colecciones, referencias, o documentos AWS-generated**. Regla candidata #S12F-1 promocionable a locked ⭐⭐⭐.

## Bloque 5 — Commit + push con triple confirmación (4ª vez consecutiva)

Mensaje bilingüe compuesto por profesor con adopción del alumno. Contenido:
- Import VPC Endpoint Gateway hacia S3 con 3 RTs (documentando la deuda técnica de RT pública).
- Hallazgo empírico Optional+Computed como patrón arquitectónico (4 tipos de atributo distintos, 3 sesiones consecutivas).
- Hallazgo empírico regla S12F-10 aterrizada por caso positivo real.
- Próxima sesión S12-H (IAM Role + Instance Profile).

Pasos ejecutados:
1. `git status` → `main.tf` modified. ✓
2. `git add main.tf` (no `git add .` — regla derivada de warmup Q3). ✓
3. `git diff --staged` → 13 líneas añadidas, un solo bloque `aws_vpc_endpoint.s3`, referencias con `.id`, sin comillas literales, sin cambios accidentales. Revisión visual OK. ✓
4. `git commit` sin `-m`, editor multilínea. Hash local: `b7c1ad4`. ✓
5. `git log -1 --format=full` → cuerpo íntegro, subject Conventional Commits, separador `---` presente, parte ES sin acentos ni ñ. ✓
6. **Triple confirmación conjunta ejecutada explícitamente**:
   - Tole confirma: SÍ cuerpo del commit revisado y correcto.
   - Claude confirma: SÍ — diff limpio (bloque bien escrito, referencias con `.id`, sin comillas literales, sin cambios accidentales), commit body íntegro y bien formateado.
   - Claude autoriza push: SÍ — proceder.
7. `git push` → `35eaf8c..b7c1ad4 main -> main`. Push limpio.

**Regla ⭐⭐⭐ #31 aterrizada por 4ª vez consecutiva**. Aterrizaje por caso normal hoy (no positivo real como en S12-F): todo estaba correcto, la ceremonia se ejecutó limpia. Ambos tipos de aterrizaje son válidos — la ceremonia no depende de que "haya bug para justificarla", depende de que se ejecute cada vez para que cuando haya bug esté ahí para cazarlo.

Balance: 4 commits consecutivos del bloque AWS (fd46ccd, 878df45, b7c1ad4) con triple confirmación conjunta explícita. Patrón consolidado, promocionable a "hábito internalizado" tras 5-6 aplicaciones.

## Aprendizajes empíricos consolidados en S12-G

### Promociones desde candidatas a **locked ⭐⭐⭐**

1. **⭐⭐⭐ #S12F-1 (locked S12-G):** El schema `Optional + Computed` es **decisión arquitectónica del provider AWS**, no coincidencia por recurso. Aplica a atributos que gestionan colecciones, referencias externas, o documentos JSON generados por AWS. **5 evidencias empíricas** en 4 recursos distintos:
   - `aws_route_table.route` — bloques anidados de rutas (S12-E).
   - `aws_security_group.ingress` — bloques anidados de reglas ingress (S12-F).
   - `aws_security_group.egress` — bloques anidados de reglas egress (S12-F).
   - `aws_vpc_endpoint.route_table_ids` — lista de referencias string (S12-G).
   - `aws_vpc_endpoint.policy` — documento JSON string (S12-G).

    **Consecuencia operativa**: declarar valor exacto en HCL funciona; omitirlo respeta lo que hay en state sin borrarlo. Predicción reforzada para atributos futuros: policies IAM, bucket policies S3, tags, listas de subrecursos referenciados.

2. **⭐⭐⭐ #S12F-10 (locked S12-G):** **Verificación conjunta línea por línea del HCL antes de `terraform validate`** cuando el HCL contiene referencias a otros recursos. Aterrizada por caso positivo real en S12-G: cazó bug de 4 referencias sin `.id` en el HCL del VPC Endpoint. Sin la regla, habría reproducido el patrón destructivo de S12-F (comillas literales → drift → destroy replacement). El pedagogo revisa las líneas nuevas, señala inconsistencias que validate no caza (referencias sin `.id`, comillas literales alrededor de expresiones, valores hardcodeados donde debería haber referencias).

3. **⭐⭐⭐ #31 aterrizada 4ª vez** (locked S12-F): triple confirmación conjunta pre-push. Aterrizaje por caso normal en S12-G (todo correcto), tras aterrizaje por caso positivo real en S12-F (bug `vpc_id` hardcodeado detectado). Patrón consolidado.

### Nuevas reglas empíricas de S12-G (candidatas)

4. **⭐⭐⭐ #S12G-1 (candidata):** El patrón de bug de referencias mal escritas se repite entre sesiones. En S12-F fue con comillas literales, en S12-G fue con `.id` omitido. Mecánica común: alumno escribe referencia sin sintaxis exacta, validator no da feedback semántico útil. Consecuencia: verificación conjunta línea por línea del HCL con referencias entre recursos es no negociable hasta que el patrón salga sin pensar (mínimo 3 sesiones consecutivas sin fallo).

5. **⭐⭐⭐ #S12G-2 (candidata):** Los comandos AWS CLI + jq no se memorizan; se guardan como snippets. La estructura del comando (`aws <service> <verb>-<resource-plural>`) sí se aprende con el tiempo, pero los filtros/queries JMESPath se copian de doc, se generan con LLMs, se validan. Convención de verbos: `describe-*` (EC2, VPC, RDS), `list-*` (IAM, S3), `get-*` (atributo específico), `create/delete/modify-*` (mutación). Herramientas: `aws <service> help`, autocompletion, `aws-shell`.

6. **⭐⭐⭐ #S12G-3 (candidata):** Una entidad AWS tiene un único dueño lógico en Terraform state. Si dos recursos podrían gestionarla (ej: `aws_route` explícito vs `aws_vpc_endpoint` con `route_table_ids`), elegir el que tiene la relación semántica más estrecha (aquí: el endpoint conoce a las RTs, no al revés). Antipatrón: declarar los dos → drift alternante en cada plan.

7. **⭐⭐⭐ #S12G-4 (candidata):** Realidad AWS ≠ intención de diseño. En brownfield, el descubrimiento (`describe-*`) puede revelar configuraciones inesperadas que no coinciden con la intención documentada del prompt. Regla operativa: **primero importar la realidad tal cual (Camino A), después refactorizar con apply pactado explícito (Camino B)**. Mezclar import + cambio de intención en la misma sesión es antipatrón. Corolario de regla ⭐⭐⭐ #17.

8. **⭐⭐⭐ #S12G-5 (candidata):** Tras hueco > 7 días, vocabulario básico aterrizado en sesiones previas puede caerse. Aceptar preguntas de refresco sin considerarlas regresión — es consecuencia esperada del hueco, no fallo pedagógico. En S12-G se cayeron ENI y AZ (aterrizados en S12-F y S11 respectivamente). Warmup post-hueco debe incluir 5-10 min de "refresco de vocabulario básico" antes de arrancar preguntas conceptuales, o aceptar extensión de warmup por refuerzos ad-hoc.

9. **⭐⭐⭐ #S12G-6 (candidata):** El ciclo git y el ciclo Terraform son dos ciclos distintos con propósitos complementarios pero disjuntos. **Ciclo Terraform** (HCL → validate → plan pre-import → import → plan post-import) protege AWS de apply destructivo. **Ciclo git** (status → add → status → diff --staged → commit → log --format=full → triple confirmación → push) protege el fichero contra bugs semánticos antes de commitear. Confundirlos lleva a saltar pasos de uno pensando que el otro los cubre. Formulación memorable: **"un ciclo protege AWS, otro protege la historia"**.

10. **⭐⭐⭐ #S12G-7 (candidata):** El aterrizaje de una regla puede ocurrir por dos vías: **caso positivo real** (la regla caza un bug de verdad — S12-F #31 y S12-G #10) o **caso normal** (la regla se ejecuta limpia varias veces sin cazar nada — S12-G #31 en su 4ª aplicación). Ambos son válidos. La ceremonia no depende de que "haya bug para justificarla" — depende de que se ejecute cada vez para que cuando haya bug esté ahí. Corolario: **una regla nueva se promociona a locked tras 3-5 aplicaciones exitosas mixtas (algunas positivas, algunas normales), no tras N aplicaciones limpias sin nada que cazar**.

## Estado exacto al cierre de S12-G

Terraform:
- CLI 1.15.8, provider AWS 6.59.0 (~> 6.58 en versions.tf).
- Backend S3 con `use_lockfile = true`.
- State en `s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate`, serial **25**, lineage sin cambios, resources = **22**.
- `terraform plan` global = `No changes`.

Recursos en state (22):
- **Red (14, desde S12-E)**: `aws_vpc.main`, 4 subnets, `aws_internet_gateway.task_manager`, 3 RTs, `aws_route.public_to_igw`, 4 associations.
- **Seguridad (7, desde S12-F)**: 2 contenedores SG + 3 reglas ec2 + 2 reglas db.
- **Conectividad interna (1, nuevo en S12-G)**: `aws_vpc_endpoint.s3` (vpce-0122ecf0ee7226fb9) con `route_table_ids = [public, private_1a, private_1b]` y `policy` default AWS.

Commits desde S12-F:
- `b7c1ad4 feat(infra): import s3 vpc endpoint with three route tables`

Pendiente commitear en frío:
- `bitacora/Sesion12-Import-Checklist.md` con casilla VPC Endpoint tachada.
- `bitacora/Sesion12-G-AWS-Diario.md` (este documento).

RDS: `stopped`. Contador con margen (verificación 6 sep: `stopped`; próximo deadline auto-arranque ~12-13 sep, aprox 7 días desde ahora).

Deuda técnica anotada:
- **S12-G #1** (candidato ADR-A13): RT pública asociada al VPC Endpoint sin valor operativo. Corrección diferida a "primer apply del roadmap" (S12-I o S13).

## Pendientes para S12-H (~2h estimadas, matutinas)

Bloque de identidad para EC2 (arrastrado desde S12-G) + arranque bloque de aplicación si sobra:

1. **IAM Role para EC2** (`aws_iam_role.ec2_task_manager` con `assume_role_policy` como JSON heredoc para `Principal: {Service: ec2.amazonaws.com}`).
2. **Policy attachments** (`aws_iam_role_policy_attachment.*` — patrón moderno, un recurso por policy attached). Descubrir con `aws iam list-attached-role-policies --role-name <name>` cuáles están attached.
3. **Instance Profile** (`aws_iam_instance_profile.ec2_task_manager` como envoltorio del Role para asociar a EC2).
4. **S3 uploads bucket** + subrecursos (bucket-policy, versioning, encryption, public-access-block) — solo si sobra tiempo, probablemente S12-I.
5. **EC2 instance** — S12-I.
6. **RDS instance** — S12-I (con recordatorio auto-arranque).

**Prioridad si el tiempo se acorta**: IAM Role + Instance Profile primero (bloque coherente + necesarios para asociar a EC2 después). Policy attachments según cuántas haya.

### Verificaciones empíricas esperadas en S12-H

- **`assume_role_policy`**: predicción teórica Optional + Computed. Verificar empíricamente. Si Optional puro, hay que declarar el JSON heredoc completo con `jsonencode()`.
- **`aws_iam_role.tags`**: predicción teórica Optional + Computed (regla ⭐⭐⭐ #S12F-1 locked aplicada).
- **Address del policy attachment**: naming convention pactar antes de escribir HCL (`aws_iam_role_policy_attachment.<role>_<policy_semantica>`).
- **JSON heredoc en HCL**: propenso a errores de sintaxis. Verificación conjunta línea por línea del HCL antes de validate más crítica que nunca (regla ⭐⭐⭐ #S12F-10 locked aplicada).

### Reglas operativas OBLIGATORIAS para S12-H

- Al arrancar: `git log --oneline -5` + `git status` + `terraform plan` + `jq '.serial'` (esperado: 25) + `aws rds describe-db-instances` (esperado: `stopped`) + `curl -s https://ifconfig.me` (esperado: `88.11.202.24` — si rotó, no bloquea IAM pero anotar).
- Ciclo pactado obligatorio con predicción escrita en cada paso.
- Vocabulario nuevo (IAM Role vs Instance Profile, assume_role_policy vs managed policies, JSON heredoc en HCL) introducido explícitamente antes de aparecer en preguntas o HCL. **Máximo 3 conceptos consecutivos con verificación entre cada uno**.
- **Verificación conjunta línea por línea del HCL antes de validate** (regla ⭐⭐⭐ #S12F-10 locked, aplicar con máxima disciplina en bloques con JSON heredoc).
- Triple confirmación conjunta obligatoria antes de git push (regla ⭐⭐⭐ #31 locked).
- Formato 24h en la duración pactada al arrancar la sesión.
- **Bitácora S12-G releída antes del warmup** — regla operativa 48-72h. Si el hueco vuelve a ser > 7 días, incluir 5-10 min de refresco de vocabulario básico al inicio del warmup.

## Meta-observaciones de método

1. **Hueco de 10 días erosionó vocabulario básico**. Se cayeron ENI y AZ (aterrizados previamente). Alumno preguntó honestamente subiendo excerpts. Refuerzo del profesor sin drama. Regla derivada (S12G-5): **tras hueco > 7 días, incluir refresco de vocabulario básico al inicio del warmup, o aceptar extensión de warmup por refuerzos ad-hoc**.

2. **Warmup extendido a 35 min vs 15 planificados (x2.3)**. Esperable dado el hueco. Alumno anunció dificultad al inicio ("me va a costar un mundo, ten paciencia"). Aceptado sin drama. Regla operativa emergente: **cuando el alumno anuncia dificultad tras hueco largo, reforzar con ejemplo directo tras dos fallos consecutivos en lugar de tras uno, y aceptar extensión de tiempo sin recortar scope conceptual**.

3. **Bloque 2 (vocabulario VPC Endpoint) extendido a 50 min vs 15-20 planificados**. Vocabulario nuevo denso (Prefix Lists AWS-managed, Gateway vs Interface, atributos por tipo). Regla máximo-3-conceptos respetada estrictamente hoy (post-error de calibración de S12-F Bloque 2). Verificaciones entre conceptos añadieron tiempo pero pagaron con aterrizaje sólido.

4. **Pregunta legítima del alumno sobre memorizar comandos `describe`**. No ignorancia — duda operativa real. Respuesta constructiva del profesor con regla derivada (S12G-2): **memoriza estructuras, no invocaciones**. Anticipación de práctica profesional (nadie los recita en producción).

5. **Sorpresa gorda en descubrimiento**: 3 RTs asociadas al VPC Endpoint en vez de 2 esperadas. Análisis conjunto de dos caminos (A: respetar realidad, B: corregir con apply). Pactado Camino A explícitamente. Deuda técnica documentada. Regla derivada (S12G-4): **primero importar la realidad tal cual, después refactorizar con apply pactado explícito**.

6. **Regla nueva S12F-10 aterrizada por caso positivo real en su primer día efectivo**. Cazó bug de 4 referencias sin `.id` en el HCL del VPC Endpoint. Sin la regla, habría reproducido el patrón destructivo de S12-F (comillas literales → drift → destroy replacement). Regla promocionable a locked ⭐⭐⭐ al cierre.

7. **Predicción sub-nivel sobre `route_table_ids` y `policy` en plan pre-import acertadas al primer intento** por el alumno. Modelo mental de Optional+Computed sólidamente aterrizado tras la reformulación del warmup. Progreso visible respecto al primer intento de la sesión.

8. **Triple confirmación ejecutada limpia por 4ª vez consecutiva**. Aterrizaje por caso normal (todo correcto) en S12-G, tras aterrizaje por caso positivo (bug cazado) en S12-F. Regla derivada (S12G-7): **una regla se promociona a locked tras 3-5 aplicaciones exitosas mixtas, no tras N aplicaciones limpias sin nada que cazar**.

9. **Alumno mencionó contexto laboral al inicio** ("la prueba la entregué el día 1, de momento silencio, creo que voy a tener que seguir en paro"). Profesor abordó brevemente sin sobreextenderse: 5 días laborables es normal para procesos españoles, silencio ≠ rechazo hasta 2 semanas laborables completas. Regla operativa emergente: **abordar preocupaciones laborales del alumno con brevedad honesta al inicio de la sesión, después cabeza en el roadmap; el trabajo del roadmap es evidencia demostrable en portfolio, no preparación teórica**.

10. **Duración real ~3h vs pactada inicialmente 2h**. Tole aceptó extensión durante Bloque 3 sin drama ("seguimos el tiempo que sea necesario, te dije 2 horas pero pueden ser 3"). Cierre a las ~11:00 con margen. Sin ceder a "meter algo más" (IAM Role quedó fuera pese a haber tiempo — decisión pactada temprano respetada). Buena disciplina operativa.

11. **Bitácora escrita por el profesor en modo "notas borrador"** a petición explícita del alumno (opción 1: ahora en caliente). Igual que S12-E y S12-F. **Este documento requiere revisión y adaptación por el alumno antes de commitear**. No es producto final — es andamiaje para acelerar el paso "en frío" sin sacrificar la reflexión personal.
