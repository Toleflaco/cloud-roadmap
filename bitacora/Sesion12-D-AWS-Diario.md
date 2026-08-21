# Sesión 12-D — Import brownfield RT pública + su ruta + sus 2 associations (parte 7 de la Sesión 5 oficial del roadmap)

**Fecha:** 21 agosto 2026
**Duración:** ~2h (17:15 – 19:15 aprox, ventana vespertina desde casa)
**Estado:** Parcial. Cierre S12-D con **RT pública completa** importada al state (`aws_route_table.public` + `aws_route.public_to_igw` + `aws_route_table_association.public_1a` + `aws_route_table_association.public_1b`) y `terraform plan` = `No changes` verificado tras cada import. Total **10/13 recursos** en state (VPC + 4 subnets + IGW + RT pública + ruta pública + 2 associations públicas). Recalibración honesta respecto al prompt original: el objetivo planeado eran 3 RTs + routes + associations + arranque SGs (~2h). Se recortó explícitamente scope a mitad de sesión — se movieron 2 RTs privadas + 2 associations privadas + 2 SGs a S12-E. Motivo del recorte: introducción tardía del concepto "association" (error de método mío, ver Meta-observaciones) consumió ~30 min extra de contexto conceptual. Cero bugs de copy-paste esta vez — mejora empírica clara sobre S12-C. Regla 48-72h reforzada tras corte inicial ("no te voy a mentir, no la he releído"). Ciclo pactado respetado en los 4 imports.

## Objetivo pedagógico

Continuar la adopción brownfield sistemática iniciada en S12-A/B y consolidada parcialmente en S12-C. Cubrir en orden:

1. Bloque 0 — Cierre de cabos sueltos S12-C (diario + checklist sin commitear detectados en `git status`).
2. Warmup — validar consolidación de conceptos S12-C (bug del IGW + ciclo pactado, import vs state mv, `.terraform/` vs state vs main.tf, categorías de atributos, Opción A vs B para IGW).
3. Descubrimiento realidad RTs con `describe-route-tables` — analizar JSON denso (routes + associations anidadas).
4. Introducción conceptual **de la anatomía de una Route Table en Terraform** — recurso NUEVO, vocabulario NUEVO (association, aws_route, aws_route_table_association).
5. Import práctico del bloque RT pública completo (4 recursos) con verificación `plan` = `No changes` tras cada uno.
6. Commit + push del bloque + pactar pasos pendientes para S12-E.

Escenario de aterrizaje empírico: comprobar si la regla ⭐⭐⭐ #19 de S12-C ("releer los IDs de AWS carácter a carácter") tiene tracción bajo estrés real ahora que hay **3 tipos de recursos nuevos** con **2 sintaxis distintas de import** en una sola sesión. Confirmado: cero copy-paste bugs en los 4 imports.

## Bloque 0 — Cierre de cabos sueltos S12-C

Regla operativa OBLIGATORIA del prompt: verificar estado del repo con `git log --oneline -5` + `git status` + `terraform plan` antes del warmup. Aplicado. Descubrimiento:

- **Diario `Sesion12-C-AWS-Diario.md` sin commitear** en filesystem (subido a chat pero no en git). Prompt de continuación anticipaba un commit `docs(bitacora): add S12-C diary + update import checklist` con hash — no existía.
- **`Sesion12-Import-Checklist.md` con modificaciones sin commitear** desde S12-C.
- **`terraform plan` limpio** — `No changes`, 6 recursos refreshed. Sin sorpresas.

Además: alumno preguntado explícitamente por regla 48-72h. Respuesta honesta: "no te voy a mentir, no la he releído". Corrección directa sin softening — la regla la fijó él en S12-C y no es negociable. Aplicado: **relectura completa de bitácora S12-C antes de arrancar warmup**. Coste real ~15 min, sin drama.

Trabajo del bloque 0:
- Alumno colocó diario S12-C en `bitacora/` (previamente solo en upload al chat).
- `git status` mostró ambos ficheros pendientes.
- Commit conjunto (regla: mismo bloque conceptual, un solo commit).
- Ejercicio de composición de mensaje bilingüe **con andamiaje** por parte del profesor — el alumno pidió que le diera el mensaje ("dámelo yo, el inglés se me da mal, y no quiero perder más tiempo traduciendo"). Respuesta con push-back directo: **evitar el inglés porque "no avanzamos" es exactamente el patrón que hay que romper** dada la orientación laboral a banca/consultoras/empresas europeas. Compromiso: andamiaje del profesor esta vez, el alumno lo intenta él el siguiente commit.

Hash `edf1fa2`. Push OK. Repo limpio antes de arrancar warmup.

### Nota operativa capturada

**Prompt de continuación no valida sin verificar filesystem**. El prompt asumía que el diario S12-C ya estaba commiteado, pero el hash `<hash-ultimo>` era literal (nunca sustituido) — pista de que la escritura del prompt precedió al commit real. Regla derivada: **el prompt de continuación es intención, no hecho consumado. `git log --oneline -5` es el único ground truth del estado del repo**.

## Bloque 1 — Warmup: repaso de conceptos de S12-C

Cinco preguntas de predicción antes de arrancar contenido nuevo, sin abrir diarios S12-A/B/C.

### Preguntas y desempeño

| # | Tema | Predicción del alumno | Realidad | Correcto |
|---|------|----------------------|----------|----------|
| 1 (crítica) | Bug IGW vpc_id 71→72 + regla ciclo pactado | Causa: "autocomplete del IDE + no releí ID". Arreglo: "editar HCL desde describe-vpc". Regla operativa: "asegurarme bien de los IDs". | Causa correcta con matiz (fue autocomplete desde otra subnet, no del VPC). Arreglo correcto en esencia. **Regla operativa incompleta**: mezcló ⭐⭐⭐ #19 (releer IDs) con la ⭐⭐⭐ #17 (disciplina de ciclo pactado). La pregunta pedía la #17. Refuerzo directo: el bug SE CAZÓ precisamente porque el ciclo pactado (HCL → validate → plan → import → plan No changes) no se saltó — el paso "plan post-import" es el que atrapa el error, no un trámite. Sin ese paso, el error habría quedado latente en HCL y explotado en el próximo apply. Segunda parte añadida: por qué basta con editar HCL y NO reimportar/apply — el mapping en state ya era correcto (import es read-only en AWS), el problema estaba solo en HCL. | Parcial tras refuerzo (dos piezas faltantes recuperadas) |
| 2 | Diferencia `terraform import` vs `state mv` | Import: "añade recurso al state, escribe en el state lo que hay en AWS". State mv: "renombra entrada que ya existe en state". Usos: import cuando no está gestionado, mv cuando ya está y hay que renombrarlo. | Correcto en las tres partes principales. **Faltó la parte del "qué NO escribe cada uno"** — pieza clave para no confundirlos bajo estrés. Refuerzo: import NO escribe en AWS (read-only), NO escribe en HCL (lo escribes tú a mano antes); solo escribe mapping en state. State mv NO toca AWS, NO toca HCL, NO reimporta; solo cambia address en state. Punto crítico compartido: ninguno toca AWS. Mnemotécnica: "Address vive en Terraform, id vive en AWS". | Aprobado con matiz añadido |
| 3 (crítica) | `.terraform/` vs S3 state vs main.tf | Los tres correctos con etiquetas claras: `.terraform/` "dependencias y metadatos, se regenera"; S3 state "el estado real, si se borra riesgo destrucción"; main.tf "código declarativo, si se borra Terraform no sabe qué gestionar". | Correcto. Refuerzo de precisión sobre `.terraform/`: contiene binarios del provider AWS descargado (~500MB en `providers/`) + config del backend (a qué S3 conectar). "Dependencias y metadatos" está bien pero vago. **RECUPERACIÓN de la recaída de S12-C** — este concepto era deuda reabierta. Hoy aterrizó limpio. | Aprobado con precisión de vocabulario |
| 4 | 3 categorías de atributos + ejemplos | Cat 1: "el nombre que le damos nosotros" (tags). Cat 2: "el id que le da AWS". Cat 3: "map_public_ip_on_launch = false". | Correcto los tres. Ejemplos adicionales añadidos: Cat 2 también incluye `arn`, `owner_id`, `default_route_table_id`; Cat 3 también `enable_dns_support = true` en VPC. Vocabulario del alumno más funcional que el técnico ("el nombre" en vez de "argumento obligatorio declarado en HCL") pero comprensión correcta. | Aprobado |
| 5 | 2 opciones IGW attachment en provider AWS 6.x | "No me acuerdo sin ver la bitácora". Honesto. | Refuerzo directo: **Opción A** (elegida) `aws_internet_gateway` con `vpc_id` como atributo interno — un recurso, un import. **Opción B** IGW sin `vpc_id` + `aws_internet_gateway_attachment` separado — dos recursos, dos imports. Por qué se eligió A: simplicidad + un solo import + recomendación por defecto del provider desde 5.x. Regla mnemotécnica ⭐⭐⭐ #11 recordada: "1 VPC = máximo 1 IGW. La diferencia público/privado se hace a nivel de Route Table, no de IGW". | Fallado, refuerzo directo aplicado |

### Resultado global del warmup

**1 acierto limpio (P4) + 3 parciales aprobados con matiz (P1, P2, P3) + 1 fallo con refuerzo (P5) de 5**. Mejor ratio que S12-C (0/5 aciertos limpios + 5 parciales). **Las dos preguntas críticas (P1 y P3) se aprobaron**, aunque P1 requirió refuerzo denso — no se activó corte de S12-D. Recuperación completa de la recaída conceptual `.terraform/` vs S3 (P3), que era deuda de S12-B reabierta en S12-C. La regla 48-72h aplicada bajo corrección directa da tracción real.

### Errores del profesor durante el warmup

Ninguno significativo. Refuerzos calibrados por magnitud del hueco. La corrección al alumno sobre el "dámelo tú el commit message" fue directa sin softening, alineada con vigilancia del método.

### Errores viejos NO recaídos

- **Confusión address ↔ id**: consolidada.
- **`.terraform/` vs state en S3**: recuperada limpiamente, no volvió a recaer.
- **Modelo mental "plan compara HCL vs state"**: aplicado limpio durante los 4 imports.
- **Regla ⭐⭐⭐ #19 (releer IDs)**: aplicada empíricamente. Cero copy-paste bugs en los 4 imports pese a que la subnet 1a y 1b se parecen mucho (`0af881...` vs `066074...`), pese a que la ruta requería concatenar dos IDs con `_`, y pese a que las associations requerían concatenar dos IDs con `/`.

### Regla operativa confirmada de S12-C

Los conceptos empíricos consolidados requieren relectura de notas cada 48-72h. Hoy S12-D ocurrió 2 días después de S12-C — dentro de ventana. Sin embargo, la relectura previa NO se hizo espontáneamente ("no la he releído"). Se aplicó tras corrección directa. Regla derivada: **la regla 48-72h necesita disparador explícito en el prompt de continuación** — no basta con dejarla como convención asumida. Añadir como checkbox obligatorio antes del warmup.

## Bloque 2 — Verificación de estado inicial

Post-warmup. Confirmación mecánica del state antes de escribir HCL nuevo.

```bash
cd infra
terraform state list        # esperado: 6 recursos
aws s3 cp s3://toleflaco-terraform-state-2026/envs/dev/terraform.tfstate - | jq '.serial'
```

**Resultado**: 6 recursos exactos (`aws_vpc.main`, `aws_subnet.private_1a/1b`, `aws_subnet.public_1a/1b`, `aws_internet_gateway.task_manager`). Serial=9, coincide con estimación del prompt (5 previos + 1 pub 1a + 1 pub 1b + 1 IGW + 1 state mv = 9). Cadena de state consistente. `terraform plan` post-refresh = `No changes`.

### Nota operativa capturada

Alumno ejecutó `terraform state list` desde `~/proyectos/cloud-roadmap` (raíz del repo) en vez de `infra/`. Resultado: `No state file was found!`. Terraform requiere ejecutarse en el directorio donde vive `.terraform/`. **Regla operativa refinada**: leer el prompt (`~/proyectos/cloud-roadmap$` vs `~/proyectos/cloud-roadmap/infra$`) antes de ejecutar cualquier comando Terraform — el CWD importa.

## Bloque 3 — Descubrimiento realidad RTs

Comando de verificación:

```bash
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-0d36eccf71cddeda7"
```

### Predicción vs realidad

Predicción del alumno: **3 RTs**. Realidad AWS: **4 RTs** (3 tuyas + Main RT `rtb-01af7b83e0427bbba`).

**Diagnóstico honesto del alumno**: "puse dos privadas y una pública, la Main no la puse". Regla derivada nueva capturada:

> En descubrimiento AWS, cuenta primero lo que AWS crea automáticamente (Main RT, default SG, default NACL), después lo tuyo. La existencia silenciosa es fallback silencioso.

### Análisis del JSON

JSON denso comparado con el de subnet o IGW — cada RT tiene 3 estructuras anidadas:

- `Routes[]`: lista de rutas dentro de la RT.
- `Associations[]`: lista de subnets asociadas.
- `Tags[]`: metadatos.

Datos extraídos por RT:

| RT | Nombre | Rutas totales | Rutas explícitas gestionables | Associations |
|---|---|---|---|---|
| `rtb-07f9363299f58b0b3` | task-manager-rtb-public | 3 (local + IGW + VPC Endpoint) | 1 (solo IGW) | 2 (public 1a + 1b) |
| `rtb-0be3472cd9db77b55` | rtb-private1-eu-west-1a | 2 (local + VPC Endpoint) | 0 | 1 (private 1a) |
| `rtb-09250fc195ff54f09` | rtb-private2-eu-west-1b | 2 (local + VPC Endpoint) | 0 | 1 (private 1b) |
| `rtb-01af7b83e0427bbba` | (sin tag, Main RT) | 1 (local) | 0 | Main association (meta) |

### Decisiones pactadas aplicadas al descubrimiento

Del prompt de continuación:

- **Main RT NO se importa**. Es fallback silencioso de AWS, sin tag Name, sin subnets asociadas explícitas. Documentar como candidato ADR-A10.
- **Ruta VPC Endpoint NO se importa como `aws_route` explícito**. Se delega al recurso `aws_vpc_endpoint` cuando se importe en S12-E — ese recurso crea la ruta implícitamente al asociarse a RTs. Si se declarara ahora como `aws_route`, chocaría con el VPC Endpoint después.
- **Ruta local (`10.0.0.0/16 → local`) NO se declara ni se importa**. La crea AWS automáticamente al crear la RT. Aparece en TODAS las RTs sin excepción. No es un recurso Terraform gestionable.

## Bloque 4 — Introducción conceptual: anatomía RT en Terraform

**Salto pedagógico crítico corregido a media sesión**. El profesor arrancó el análisis del JSON preguntando por "associations" y "aws_route" sin haber introducido el vocabulario. El alumno paró con corrección directa: "no entiendo lo que me dices de asociaciones y rutas... eso de asociaciones no lo he visto, no puedo decirte que es ni que no es... hace dos chats pasó lo mismo. Si no tengo ni idea de esto, me preguntas cosas que no sé... tengo que fallar si o si, o acertar de milagro". Corrección aceptada sin softening (ver Meta-observaciones #1).

Reencuadre: **paramos el análisis del JSON, volvemos al Bloque 4 del prompt (Anatomía RT en Terraform) que estaba planificado ANTES de tocar HCL**.

### Analogía técnica introductoria

Una Route Table es una **tabla de reenvío de paquetes**, idéntica a la tabla de routing de un router doméstico o de un servidor Linux. En WSL: `ip route show` devuelve algo como:

```
default via 192.168.1.1 dev eth0
192.168.1.0/24 dev eth0
```

Dos rutas en una tabla de routing. Cada línea: "para llegar a este destino (izquierda), sal por este sitio (derecha)".

En AWS es idéntico. Una **Route Table** es un objeto AWS que contiene una lista de **rutas** (routes). Cada ruta tiene:
- **Destino** (CIDR block o prefix list): "paquetes que van a esta red..."
- **Target** (gateway): "...sálelos por aquí" (IGW, VPC Endpoint, NAT, peering, o `local`).

Hasta aquí una RT es solo una lista de instrucciones. No sirve sin alguien que la use.

### Quién usa una RT: las subnets, vía associations

Las **subnets** consultan una RT para saber cómo enrutar sus paquetes hacia fuera. La relación "subnet X usa RT Y" es la **association**.

- Una subnet solo puede estar asociada a **una RT a la vez**.
- Una RT puede tener **muchas subnets asociadas**.
- Si una subnet no está explícitamente asociada a ninguna RT, AWS la asocia automáticamente a la **Main RT** (por eso Main RT existe siempre — es el fallback).

### Anclaje empírico desde la consola AWS

Momento clave: el alumno **abrió la consola AWS** al perderse con el JSON. La consola AWS usa la palabra "**Subnet associations**" literalmente en la UI. Regla derivada nueva:

> La palabra que la consola AWS usa para un concepto es la palabra que Terraform copia. Si no reconoces vocabulario en Terraform, abre la consola primero — el vocabulario está allí escrito.

Aplicado: la consola muestra "**Explicit subnet associations (2)**" con las 2 subnets públicas listadas. **1 línea en "Explicit subnet associations" = 1 recurso `aws_route_table_association` en Terraform**. Anclaje mental funcionó.

Análogamente para rutas: consola muestra "**Routes (3)**" con columna "**Route Origin**" que distingue:
- `Create Route Table` = ruta implícita creada por AWS (la `local`). **NO se declara en Terraform**.
- `Create Route` = ruta explícita creada por humano/consola. Candidata a ser `aws_route` en Terraform.

### Anatomía en Terraform: 3 recursos separados

- **`aws_route_table`** — la RT como objeto. Solo `vpc_id` + `tags`. **No contiene rutas ni associations dentro**.
- **`aws_route`** — UNA ruta individual dentro de una RT. Se referencia por `route_table_id`. Se declara una vez por cada ruta explícita.
- **`aws_route_table_association`** — UNA relación entre una subnet y una RT. Se referencia por `subnet_id` + `route_table_id`. Una por cada subnet asociada.

Decisión del provider (pactada en prompt): usar recursos separados en vez de bloques anidados dentro de `aws_route_table`. Razones: modularidad + import individual + convención comunitaria (HashiCorp recomienda desde 2019).

### Conteo total tras aterrizaje conceptual

- `aws_route_table` × 3 = 3
- `aws_route` × 1 (solo la pública → IGW) = 1
- `aws_route_table_association` × 4 (2 públicas + 1 priv 1a + 1 priv 1b) = 4

**Total 8 imports** para cerrar el bloque de red.

## Bloque 5 — Recorte de scope aplicado bajo presión temporal

Cálculo honesto post-Bloque 4: 8 imports con ciclo pactado por cada uno + sintaxis nueva de import para 2 tipos de recurso desconocidos en ~55 min restantes = **no factible sin comprometer método**.

Propuesta de recorte pactada explícitamente:

- **S12-D (hoy)**: solo **RT pública completa**. 4 imports. Bloque más denso y más didáctico — introduce los 3 tipos nuevos por primera vez.
- **S12-E (siguiente)**: 2 RTs privadas + 2 associations privadas (4 imports más) + arranque SGs si sobra tiempo.

Alumno aceptó recorte. Regla operativa aplicada: **mejor consolidar antes que acumular deuda** (regla S12-C confirmada). Recorte explícito, no acumulación silenciosa.

## Bloque 6 — Import RT pública (`aws_route_table.public`)

Recurso 1 de 4 del bloque.

### Marco mental antes de HCL

Atributos declarados (aplicando regla ⭐⭐⭐ #10 "declara todo atributo semánticamente significativo"):
- `vpc_id` (obligatorio, Cat 1): referencia a `aws_vpc.main.id` (Opción B — usar referencia del state, no hardcodear).
- `tags.Name` (Cat 1): `"task-manager-rtb-public"` — leído carácter a carácter desde consola.

NO declarados:
- `route` (bloque anidado): no usamos — decisión pactada de recursos separados.
- `propagating_vgws`: no aplica, sin VGWs.

### Ciclo pactado ejecutado

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "task-manager-rtb-public"
  }
}
```

`terraform fmt` (silencio) → `terraform validate` (Success) → `terraform plan`:

**Predicción explícita del alumno**: "(B) 1 to add, ya que en el state no está declarado ese recurso al no haberse el import". Correcto. Aterrizaje empírico del modelo mental HCL vs state, no HCL vs AWS.

Output plan: `+ vpc_id = "vpc-0d36eccf71cddeda7"` (único no-Computed, resuelto desde state), resto `(known after apply)`. `+ tags` y `+ tags_all` ambos aparecen (default_tags vacío del provider, coinciden).

`terraform import aws_route_table.public rtb-07f9363299f58b0b3` — **releído carácter a carácter contra consola antes de ejecutar**. Import successful. `terraform plan` post-import: **`No changes`** en primera iteración.

### Aterrizaje empírico

**HCL escrito bien a la primera + import limpio + plan No changes**. Cero drama. Contraste directo con S12-C, donde el bug del IGW causó `~ update in-place`. Regla ⭐⭐⭐ #19 aplicada bajo estrés real — no solo verbalizada.

## Bloque 7 — Import ruta pública (`aws_route.public_to_igw`)

Recurso 2 de 4. **Tipo de recurso NUEVO**.

### Marco mental antes de HCL

Atributos de `aws_route`:
- `route_table_id` (obligatorio): a qué RT pertenece.
- **Un `destination_*` obligatorio**: `destination_cidr_block` para IPv4 CIDR, `destination_ipv6_cidr_block` para IPv6, `destination_prefix_list_id` para VPC Endpoints (no aplica aquí).
- **Un `*_id` de target obligatorio, excluyente**: `gateway_id` para IGW/VPC Endpoint, `nat_gateway_id`, `transit_gateway_id`, `vpc_peering_connection_id`, `network_interface_id`.

Para esta ruta (destino `0.0.0.0/0` → target IGW):
- `route_table_id` = `aws_route_table.public.id`
- `destination_cidr_block` = `"0.0.0.0/0"`
- `gateway_id` = `aws_internet_gateway.task_manager.id`

### Sintaxis de import especial

`aws_route` no tiene ID único propio en AWS. Se identifica por combinación RT + destino:

```
<route_table_id>_<destination>
```

Separador: **guion bajo `_`**. Para destinos CIDR IPv4:

```
rtb-07f9363299f58b0b3_0.0.0.0/0
```

### Ciclo pactado ejecutado

HCL escrito con `fmt` (reformateo de alineación `=`) + `validate` OK + `plan` = `1 to add`. Output relevante: `+ gateway_id = "igw-0ab423637224cab0c"` + `+ route_table_id = "rtb-07f9363299f58b0b3"` — ambos resueltos desde state, sin hardcodear. `+ origin = (known after apply)` — aquí AWS pondrá `CreateRoute`.

Import ejecutado con sintaxis exacta. **ID interno del state generado por Terraform**: `r-rtb-07f9363299f58b0b31080289494` — distinto del ID que le pasas al import. Razón: el ID de import (`_0.0.0.0/0`) es convención del provider para localizar el recurso en AWS; el ID interno es sintético generado por Terraform después. Anécdota, no acción.

Plan post-import: **`No changes`**. 8 recursos en state.

## Bloque 8 — Import association pública 1a (`aws_route_table_association.public_1a`)

Recurso 3 de 4. **Tipo de recurso NUEVO**.

### Marco mental antes de HCL

Atributos mínimos:
- `subnet_id` (obligatorio si association a subnet).
- `route_table_id` (obligatorio).

Existe `gateway_id` alternativo para gateway route table associations (IGW/VGW) — no aplica.

Punto conceptual: **una subnet solo puede tener UNA association a la vez**. Si Terraform detecta que la subnet ya está asociada a otra RT y tú declaras otra, choca. Aquí no hay problema — las subnets ya están asociadas exactamente a esta RT en AWS.

### Sintaxis de import especial (distinta de aws_route)

Formato association subnet-a-RT:

```
<subnet_id>/<route_table_id>
```

Separador: **barra `/`**, no guion bajo. **Inconsistencia del provider** — `aws_route` usa `_`, `aws_route_table_association` usa `/`. Frase ⭐⭐⭐ candidata:

> Sintaxis de import cambia por tipo de recurso: `aws_route` usa `_`, `aws_route_table_association` usa `/`. Verificar docs oficiales del provider antes de ejecutar cada tipo nuevo.

### Ciclo pactado ejecutado

HCL con 2 atributos declarados (`subnet_id` y `route_table_id`, ambos por referencia del state). `fmt` sin cambios + `validate` OK + `plan` = `1 to add`. Output mínimo: solo 4 atributos totales (2 declarados + `id` computed + `region` default).

Import: `terraform import aws_route_table_association.public_1a subnet-0af881e02d4a9322b/rtb-07f9363299f58b0b3`. **ID del state resultante**: `rtbassoc-02026c1395e7b8f68` — coincide con el `RouteTableAssociationId` que aparecía en el JSON de descubrimiento. Cadena limpia: HCL ↔ state (ID interno AWS) ↔ realidad AWS.

Plan post-import: **`No changes`**. 9 recursos en state.

## Bloque 9 — Import association pública 1b (`aws_route_table_association.public_1b`)

Recurso 4 de 4. Replicación con verificación de ID de subnet (1b es `subnet-066074bd45c1a46f6`, no confundir con 1a `subnet-0af881e02d4a9322b`).

Ejecución del ciclo pactado completo en un solo pase — patrón ya conocido tras Bloque 8. HCL + fmt + validate + plan (1 to add) + import + state list (10 recursos) + plan (No changes).

**Predicción explícita saltada por el alumno** — tras haberlo pedido en Bloque 8. Regla operativa (ver Meta-observaciones #2): **la predicción escrita es parte del ciclo pactado, no ornamento**. Marcada como deuda de método para S12-E.

## Bloque 10 — Commit + push del bloque RT pública

Verificación pre-commit: `git status` + `git diff infra/main.tf`. Diff limpio, un solo fichero modificado, 4 bloques añadidos secuencialmente (RT + ruta + 2 associations). Micro-detalle no crítico: 2 líneas en blanco al final del diff — `terraform fmt` no las quitó, no rompe. Se corregirá en el próximo `fmt`.

### Composición del mensaje bilingüe por el alumno

**Segundo commit del día donde el alumno intentó el mensaje él mismo** (compromiso del Bloque 0). Primer intento:

- Título demasiado largo (~90 chars, límite ~72).
- "route publics" — construcción incorrecta.
- Mezcla ES/EN dentro del body (línea EN empezando con "Añadir").
- Falta separador `---`.
- Falta decisión pactada sobre VPC Endpoint route.

Andamiaje del profesor: piezas EN entregadas por bloque, alumno compone. Segunda iteración con correcciones específicas (tildes en parte ES, `and` colado en línea ES → `y`, duplicación del título en la parte ES, faltaba punto final EN). Versión final aceptada.

Estructura final del mensaje:

```
feat(infra): import public route table and its route + associations

Import 4 resources for the public route table block: aws_route_table,
aws_route, and 2 aws_route_table_association.
The VPC Endpoint route is intentionally not imported, it will be created
by aws_vpc_endpoint in S12-E.
Total managed resources: 10. Post-import plan returns No changes.

---

Importar 4 recursos para el bloque de la RT publica: aws_route_table,
aws_route, y 2 aws_route_table_association.
La ruta del VPC Endpoint no se importa a proposito, se creara por
aws_vpc_endpoint en S12-E.
Total recursos gestionados: 10. El plan post-import devuelve No changes.
```

Hash `738265e`. Push OK a `origin/main`.

### Nota operativa capturada

Alumno usó `git add .` en vez de `git add infra/main.tf`. Funcionó porque no había ruido, pero `git add .` es hábito peligroso — un día se lleva al staging algo no deseado (temporal, dump, generado). **Regla operativa**: en repos serios, siempre `git add <path específico>`.

## Comandos AWS CLI ejecutados (marcados en rojo para notas)

Comandos nuevos de S12-D:

```bash
# Verificar todas las RTs de un VPC
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"

# Verificar RT específica por ID
aws ec2 describe-route-tables --route-table-ids <rtb-id>
```

Sintaxis de import específica por recurso (regla operativa: verificar docs del provider antes de cada tipo nuevo):

```bash
# aws_route
terraform import aws_route.<address> <route-table-id>_<destination-cidr>
# Ejemplo: terraform import aws_route.public_to_igw rtb-07f9363299f58b0b3_0.0.0.0/0

# aws_route_table_association (subnet a RT)
terraform import aws_route_table_association.<address> <subnet-id>/<route-table-id>
# Ejemplo: terraform import aws_route_table_association.public_1a subnet-0af881e02d4a9322b/rtb-07f9363299f58b0b3

# aws_route_table (simple)
terraform import aws_route_table.<address> <rtb-id>
```

## Frases ⭐⭐⭐ candidatas (nuevas de S12-D)

1. "En descubrimiento AWS, cuenta primero lo que AWS crea automáticamente (Main RT, default SG, default NACL), después lo tuyo. La existencia silenciosa es fallback silencioso, y silencio no es ausencia."
2. "La palabra que la consola AWS usa para un concepto es la palabra que Terraform copia. Si no reconoces vocabulario en Terraform, abre la consola primero — el vocabulario está allí escrito."
3. "Route Table en Terraform son 3 recursos separados: `aws_route_table` + `aws_route` (uno por cada ruta explícita) + `aws_route_table_association` (uno por cada subnet asociada). La ruta local nunca cuenta — la crea AWS implícitamente y no es gestionable."
4. "Sintaxis de import cambia por tipo de recurso: `aws_route` usa `_`, `aws_route_table_association` usa `/`. Verificar docs oficiales del provider antes de ejecutar cada tipo nuevo."
5. "La predicción explícita antes del `plan` es parte del ciclo pactado, no ornamento. Saltarla debilita el aprendizaje aunque el import salga bien porque desconecta el modelo mental de la ejecución."
6. "El prompt de continuación es intención, no hecho consumado. `git log --oneline -5` es el único ground truth del estado del repo antes de arrancar sesión."

Total acumulado del arco Terraform (S12-A + S12-B + S12-C + S12-D): **25 frases ⭐⭐⭐**.

## Deuda arrastrada actualizada

### Deuda nueva (Sesión 12-D)

- **Bloque de red incompleto**: 2 RTs privadas (`rtb-0be3472cd9db77b55`, `rtb-09250fc195ff54f09`) + 2 associations privadas (private 1a + private 1b) pendientes. Planificado S12-E.
- **Ruta VPC Endpoint** sigue sin importar. Delegada al recurso `aws_vpc_endpoint` cuando llegue en S12-E. Ninguna de las 3 RTs tuyas tendrá esta ruta como `aws_route` explícito.
- **Main RT sin importar**: decisión ADR-A10 candidato — documentar por qué NO se gestiona con Terraform (fallback silencioso de AWS, sin tag, sin subnets asociadas explícitas).
- **2 SGs + reglas** pendientes de import. Planificado S12-E (o S12-F si scope se pasa).
- **Predicción explícita saltada en 2/4 imports** de hoy (Bloque 7 y Bloque 9). Regla operativa refinada: la predicción escrita es parte del ciclo, no ornamento. Vigilar en S12-E.
- **Concepto de "association" introducido tardíamente** (error de método del profesor, ver Meta-observaciones #1). Consecuencia: ~30 min extra consumidos + confusión visible en el alumno. Regla operativa refinada: vocabulario nuevo introducido explícitamente ANTES de aparecer en preguntas o ejercicios, no en paralelo.
- **README de portfolio pendiente actualizar** con S3 integration + presigned URLs + VPC Endpoint + adopción brownfield con Terraform. Acumulada desde S6-S8.
- **ADRs pendientes reservados para tras cerrar bloque Terraform**:
  - ADR-A2: Terraform vs CloudFormation vs CDK.
  - ADR-A3: HCL vs Terragrunt vs Terraspace.
  - ADR-A6: DynamoDB locking vs S3 native locking.
  - ADR-A7: `terraform import` vs recrear desde cero.
  - ADR-A8 (candidato): declarar defaults críticos en HCL vs aceptar defaults del provider.
  - ADR-A9 (candidato de S12-C): Opción A vs B del provider AWS para IGW.
  - **ADR-A10 (candidato nuevo S12-D): decisión de NO importar la Main RT** — fallback silencioso de AWS, sin gestión Terraform.
  - **ADR-A11 (candidato nuevo S12-D): decisión de NO importar la ruta VPC Endpoint como `aws_route`** — delegar al recurso `aws_vpc_endpoint` que la crea implícitamente al asociarse a RTs.

### Deuda arrastrada de sesiones anteriores (siguen abiertas)

- **RDS y EC2 parados desde S12-A**. Trampa auto-arranque a 7 días: **fecha límite 24 ago**. Hoy 21 ago — **3 días de margen**. Si S12-E no ocurre antes del 24, arrancar y parar RDS manualmente para resetear timer. No dejarlo sin controlar.
- **Sesión de repaso conceptual pendiente** (heredada de S12-C, no ejecutada). Ya menos urgente ahora que warmup S12-D salió razonable, pero conviene programarla al cierre del arco Terraform.
- **Cuidado con `aws s3 cp terraform.tfstate`**: state en claro puede contener secretos. Alternativa segura: `terraform state list` / `terraform state show`.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2**.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location**.
- **`postgresql-client` en EC2 en v16 vs server v18**.
- **Billing access para IAM user `tole`** — activar desde root.
- **Verificación empírica del tráfico por VPC Endpoint** — postpuesta al módulo Observabilidad.
- **`tags_all` y `default_tags` a nivel provider** — sigue apareciendo en cada plan como duplicado silencioso.

### Deudas cerradas hoy

- **Cabos sueltos S12-C**: diario S12-C + checklist actualizado commiteados en `edf1fa2`.
- **Regla 48-72h aplicada tras corrección directa**: relectura completa de bitácora S12-C antes de warmup.
- **Warmup S12-C consolidando conceptos**: 1 acierto limpio + 3 parciales aprobados + 1 fallo con refuerzo. Mejor ratio que S12-C (0/5).
- **Recuperación de recaída `.terraform/` vs S3** (deuda reabierta en S12-C): aterrizada limpiamente hoy.
- **`aws_route_table.public` importado**: HCL a la primera, plan `No changes`.
- **`aws_route.public_to_igw` importado**: primer contacto con `aws_route` + sintaxis `_`, plan `No changes`.
- **`aws_route_table_association.public_1a` importado**: primer contacto con `aws_route_table_association` + sintaxis `/`, plan `No changes`.
- **`aws_route_table_association.public_1b` importado**: replicación limpia, plan `No changes`.
- **Cero copy-paste bugs en 4 imports**: regla ⭐⭐⭐ #19 aterrizada empíricamente bajo estrés real. Mejora clara sobre S12-C.
- **Ciclo pactado respetado en los 4 imports** (con el hueco de las predicciones explícitas, ver deuda nueva).
- **Alumno compuso commit message bilingüe con andamiaje del profesor** (segundo intento). Progreso vs Bloque 0 donde pidió que se lo diera hecho.
- **Concepto RT en Terraform (3 recursos separados) introducido** con anclaje empírico desde consola AWS.
- **Sintaxis de import por tipo de recurso documentada**.

## Para retomar en Sesión 12-E

**Prerrequisito obligatorio**: relectura de esta bitácora S12-D antes de arrancar. Regla 48-72h aplicada — añadir checkbox explícito al prompt de continuación S12-E ("bitácora S12-D releída: [sí / no]" **antes** del warmup, no como convención asumida).

**Warmup obligatorio S12-E (~15 min)** — sin abrir diarios:

1. Qué son las 3 estructuras Terraform que modelan una Route Table completa. Nómbralas y explica qué hace cada una. Cuál NO se declara nunca y por qué.
2. Sintaxis de import de `aws_route` y `aws_route_table_association`. Cuál usa `_` y cuál usa `/`. Regla operativa derivada.
3. Por qué NO se importa la ruta del VPC Endpoint como `aws_route` explícito. Qué recurso se ocupará de ella cuando llegue.
4. Por qué NO se importa la Main RT. Qué la caracteriza en AWS.
5. Por qué el bug de copy-paste del IGW en S12-C no se reprodujo en S12-D pese a tener 4 imports con IDs largos y 3 tipos de recurso distintos. Qué regla operativa ⭐⭐⭐ se aplicó bajo estrés.

Las críticas: pregunta 1 (anatomía RT — introducida hoy) y pregunta 2 (sintaxis de import por tipo — dato operativo que no debe fallar). Si fallan cualquiera de las dos: pactar corte de S12-E antes de RTs privadas.

**Objetivo S12-E** (~2h con calibración realista):
1. Warmup (~15 min).
2. Verificación estado inicial (~5 min).
3. Import RT privada 1a + su association (~25 min): `aws_route_table.private_1a` + `aws_route_table_association.private_1a`.
4. Import RT privada 1b + su association (~25 min): `aws_route_table.private_1b` + `aws_route_table_association.private_1b`.
5. Commit + push del bloque RTs privadas.
6. Si sobra tiempo real: arrancar SGs (`aws_security_group` + `aws_security_group_rule`). Si no, cerrar en verde y pactar SGs para S12-F.
7. Actualización checklist + bitácora S12-E.

**Objetivo S12-F (probable)**: 2 SGs + reglas + S3 uploads + IAM Role + Instance Profile + EC2 + RDS + VPC Endpoint + plan global final + ADRs + bitácora final.

**Decisiones pactadas para S12-E**:
- Las 2 RTs privadas siguen mismo patrón que la pública: `aws_route_table` + `aws_route_table_association`. **Sin `aws_route`** — no tienen rutas explícitas gestionables (solo local + VPC Endpoint delegada).
- Address propuestos alineados con convención: `aws_route_table.private_1a`, `aws_route_table.private_1b`, `aws_route_table_association.private_1a`, `aws_route_table_association.private_1b`.

**Regla operativa OBLIGATORIA para S12-E**:

Al arrancar, antes del warmup: verificar estado del repo con `git log --oneline -5` + `git status` + `terraform plan` desde `infra/`. Si plan no sale `No changes`, PARAR y analizar antes de escribir HCL nuevo.

Durante los imports: ciclo pactado obligatorio con predicción explícita escrita. HCL → pégamelo aquí → verificación conjunta → validate → plan (predicción escrita antes) → import → plan No changes. NO saltarse ningún paso, incluida la predicción.

## Meta-observaciones de método

1. **Error de método del profesor: introducción tardía del concepto "association"**. Salté el Bloque 4 del prompt ("Anatomía RT en Terraform") y fui directo a extraer del JSON preguntando por associations sin haberlas introducido. Alumno paró con corrección directa y honesta: "no entiendo lo que me dices de asociaciones y rutas... hace dos chats pasó lo mismo... tengo que fallar si o si". Corrección aceptada sin softening ni excusas. Reencuadre a Bloque 4 con analogía técnica (routing table Linux + consola AWS). Regla derivada reforzada:

> Vocabulario técnico nuevo requiere introducción explícita, no de pasada. El profesor debe verificar que el marco mental está pactado ANTES de introducir cualquier pregunta o ejercicio que use el vocabulario. Si el alumno tiene que "adivinar" qué significa una palabra a partir de contexto, el profesor ha fallado el paso previo.

Es la segunda vez que ocurre este patrón según el alumno ("hace dos chats pasó lo mismo"). Deuda de método a vigilar activamente en S12-E — verificar antes de cada bloque nuevo si hay vocabulario no introducido.

2. **Predicción explícita saltada en 2/4 imports** (Bloque 7 y Bloque 9). El profesor la pidió en Bloque 6, la validó en Bloque 8 con feedback, y aun así fue saltada en el 4º recurso. Regla derivada nueva:

> La predicción explícita escrita antes del `plan` es parte del ciclo pactado, no ornamento. Saltarla debilita el aprendizaje aunque el import salga bien porque desconecta el modelo mental de la ejecución. Cuando se salta reiteradamente, marcar como deuda de método explícita.

3. **Cero copy-paste bugs en 4 imports pese a alta densidad de IDs**: mejora empírica clara sobre S12-C. Regla ⭐⭐⭐ #19 aplicada bajo estrés real. Contrasta con S12-C donde la regla se verbalizó correctamente en warmup pero recayó 90 min después. Aquí no recayó — dato positivo. Aterrizaje empírico verdadero requiere repetición bajo estrés + errores reproducidos; S12-D es la primera sesión donde no hubo recaída.

4. **Alumno pidió "dámelo tú" el commit message por frustración con el inglés**: "no quiero perder más tiempo traduciendo, porque sino no vamos a avanzar en la lección". Respuesta directa sin softening: **evitar el inglés porque "no avanzamos" es exactamente el patrón que hay que romper** dada la orientación laboral a banca/consultoras/empresas europeas. Andamiaje entregado (piezas EN + estructura), alumno compone. Compromiso pactado: siguiente commit lo intenta él. Cumplido en Bloque 10, con 2 iteraciones de corrección. Progreso real. Regla derivada:

> Cuando el alumno reporta fricción con el inglés técnico como "pérdida de tiempo", NO ceder a la solicitud de sustituir. Ofrecer andamiaje graduado (piezas + estructura → alumno compone). La resistencia al inglés bajo presión es el hábito exacto que la búsqueda de empleo requiere romper.

5. **Alumno frustrado con concepto que no aterriza al primer intento** ("me pierdo con las asociaciones y con eso... si no tengo ni idea de esto, me preguntas cosas que no sé"). Respuesta correcta: reconocer error de método propio sin softening, parar, reencuadrar recortando scope. NO minimizar la frustración. NO decir "no es difícil" ni "ya casi lo tienes". La frustración es señal fiable de error de método, no rasgo del alumno. Regla operativa fijada tras S12-C confirmada empíricamente hoy: **cuando el alumno dice "me pierdo" o equivalente, parar, reconocer error de método, y reencuadrar recortando scope**.

6. **Recorte de scope aplicado bajo presión temporal sin acumular deuda silenciosa**. Cálculo honesto en Bloque 5: 8 imports en 55 min no factibles sin comprometer método. Recorte explícito pactado (RT pública sola hoy, resto S12-E). Regla ⭐⭐⭐ de S12-A confirmada: **cerrar en verde tramos completos es mejor que acumular trabajo**. Aplicada aquí sin drama — 4 imports limpios cerrados hoy > 8 imports apurados con método comprometido.

7. **"No te voy a mentir, no la he releído"** — honestidad radical del alumno sobre la regla 48-72h. Corrección directa aplicada (relectura obligatoria antes de warmup), no minimizada como "no pasa nada". Regla derivada:

> La honestidad radical del alumno sobre incumplimiento de reglas operativas es información valiosa, no confesión a suavizar. Corregir con la acción requerida sin drama y sin acumular reproche.

8. **Alumno preguntó explícitamente por deudas acumuladas** ("he visto todas las deudas que hay, son muchísimas"). Respuesta: las deudas están **inventariadas y priorizadas** en el memory, no perdidas. La lista de "topics to reactivate" existe precisamente para no arrastrarlas como ansiedad de fondo. Se atacan por mini-sesiones cuando toque, no todas a la vez. Regla operativa derivada:

> Cuando el alumno expresa ansiedad por deudas acumuladas, recordarle que están inventariadas y priorizadas. La lista de deuda técnica no es una acusación, es una herramienta de gestión que evita que las deudas se pierdan de vista o se ejecuten en paralelo caóticamente.

9. **Prompt de continuación con hash literal sin sustituir** (`<hash-ultimo>`): pista de que la escritura del prompt precedió al commit real del diario S12-C. `git log` fue el ground truth. Regla capturada en Bloque 0.

10. **Alumno usó `git add .` en vez de `git add <path específico>`**. Funcionó por suerte (sin ruido en árbol). Corrección directa sin drama, sin cambio retroactivo. Regla capturada para próximas veces. Ejemplo de corrección proactiva sobre hábito peligroso antes de que cause daño.

11. **Duración real ~2h vs pactado ~2h**. Sin desvío temporal significativo. Recorte de scope en Bloque 5 fue lo que mantuvo la duración dentro de rango.

12. **Cierre en verde**: 4 recursos importados con `No changes`, commit `738265e` pusheado, repo limpio. Bitácora y checklist quedan como deuda **cerrada por el alumno en frío** (no bajo cansancio vespertino). Buena decisión operativa — escritura reflexiva de bitácora sale mejor en frío.
