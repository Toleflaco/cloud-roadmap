# Sesión 12-K — Import brownfield EC2 instance + RDS instance con drift `skip_final_snapshot` reconciliado empíricamente y aterrizaje del mapping Categoría 1/2/3/4 del schema del provider AWS

**Fecha:** sábado 12 septiembre 2026 (ventana vespertina 15:30 – ~18:15, ~2h 45min efectivos). Sesión de una sola ventana continua, sin interrupciones externas. Ventana ampliada en caliente respecto a la planificación original (15:30-17:30, 2h justas) tras señal explícita del alumno *"no te preocupes por el tiempo puedo estar más tiempo"* al plantearse recorte pactado en el arranque del Bloque 4.
**Duración total:** ~2h 45min honestas. Estimación inicial del prompt de continuación S12-K: 1h 30min - 2h para 2 imports densos con descubrimiento previo hecho. **Desviación real +45min a +1h 15min** por (a) introducción del mapping Categoría 1/2/3/4 en caliente como vocabulario nuevo denso, (b) 3 iteraciones extra sobre HCL EC2 con correcciones de método por antipatrones detectados, (c) drift `skip_final_snapshot` que requirió 3 iteraciones con 3 refutaciones teóricas del profesor + verificación empírica del state antes de la reconciliación final.
**Estado:** Cierre limpio con **2 imports densos** (EC2 + RDS). Total 32/32 recursos gestionados objetivo del módulo AWS brownfield (14 red + 7 seguridad + 1 VPC Endpoint + 4 IAM + 3 S3 + 1 DB Subnet Group + 1 EC2 + 1 RDS). `terraform plan` global = `No changes`, serial **35**. Commit `d6880b1` pusheado a `origin/main` limpio con triple confirmación conjunta (**8ª aplicación consecutiva**, 3ª sin amend previos desde S12-G, aterrizaje S12-H mantenido 3ª sesión consecutiva). RDS: `stopped` reportado al arrancar por el alumno, no bloqueante para el import. IP casa: `95.121.15.184` reportada, sin cambio desde S12-J. Bitácora S12-J NO releída antes del warmup — opción (b) pactada explícitamente al arranque (proceder sin releer con compensación en verificación conjunta reforzada). Bloque 11 (checklist + bitácora S12-K) pactado en frío al día siguiente. Sesión con **densidad pedagógica muy alta**: 2 imports densos, introducción de mapping Cat 1/2/3/4 como vocabulario nuevo transversal, 3 saltos de método iniciales corregidos progresivamente, 3 refutaciones consecutivas del profesor sobre `skip_final_snapshot` con corrección de método explícita, 4 correcciones a autonarrativa saboteadora del alumno con evidencia empírica, matización S12-K ampliada de ⭐⭐⭐ #S12H-8, 3 reglas candidatas nuevas (#S12K-1, #S12K-2, #S12K-3), 1 candidato ADR nuevo (A20), 1 predicción correcta del alumno superando el análisis teórico del profesor.

## Objetivo pedagógico

Cerrar el bloque de cómputo (EC2 instance) + bloque de base de datos (RDS instance) con los objetivos paralelos de (i) aplicar la matización ampliada de ⭐⭐⭐ #S12H-8 aterrizada en S12-J a EC2 (`id = i-<hex>` opaco → identificador propio → `.id` correcto) y a RDS (predicción `id = identifier` → alias → `.identifier` correcto, refutada empíricamente durante la sesión), (ii) aplicar el Camino 3 pactado en S12-J para el `password` de RDS (omitir del HCL, gestión manual + Bitwarden, ADR-A19), (iii) aplicar la candidata #S12J-1 al escribir HCL de RDS (releer específicamente los campos de la propia instance sin confundir con anidados en `describe-db-instances`), (iv) preparar el estado para primer apply del roadmap (S12-L, milestone de cierre del módulo AWS brownfield).

El objetivo se cumplió íntegramente en scope técnico. Se añadió un objetivo pedagógico emergente no planificado: la introducción del **mapping Categoría 1/2/3/4 del schema del provider Terraform** como marco conceptual explícito para discriminar Required / Optional con default literal / Optional+Computed / Optional que fuerza replacement, en respuesta al antipatrón "todos son optional, así que lo declaro" detectado en el alumno al arranque del bloque `metadata_options` de EC2. El mapping aterrizó al 3er intento y se aplicó consistentemente en 20+ decisiones declarar/omitir a lo largo del HCL de EC2 + RDS.

## Bloque 0 — Verificación al arranque

Sesión con hueco de ~6 horas desde el cierre de S12-J (misma jornada, ventana matutina 08:35 - 09:30, ventana vespertina 15:30 en adelante). Hueco > 6h desde el cierre S12-J, por tanto Bloque 0 completo obligatorio con protocolo reforzado según regla pactada.

Datos reportados por el alumno en el prompt de continuación S12-K (no ejecutados empíricamente al arranque, tomados como declarados):

- Cuánto rato disponible: 2 horas justas (15:30–17:30) — límite bajo de la estimación pactada. Anotado como candidato a recorte de scope si algún bloque se alarga.
- Sitio de conexión: casa de los gatos (Reinosa). Misma máquina `TxM` WSL2 Ubuntu 22.
- Estado RDS: `stopped`. Sin acción, deadline auto-arranque no alcanzado (2026-09-13 05:25 UTC, margen holgado).
- IP casa: `95.121.15.184`. Sin rotación desde S12-J (misma ubicación). No bloqueante para el import.

**Decisión sobre bitácora S12-J no releída**: el alumno marcó "no" al arranque con racional *"ha sido esta mañana la última sesión"*. La regla operativa 48-72h pactada en S12-J dice literalmente *"aplicable incluso a hueco <12h por seguridad"*. Discrepancia detectada por el profesor y explicitada sin softening. Dos opciones planteadas: (a) releer la bitácora S12-J antes del warmup (10-15 min consumo, reduce riesgo de olvidar detalles empíricos), (b) proceder sin releer aceptando riesgo y compensando con verificación conjunta línea por línea reforzada del HCL. Alumno pasó directamente a ejecutar los puntos empíricos del Bloque 0 sin responder a la elección explícita. Profesor interpretó implícitamente **opción (b)** y la anotó explícitamente en su análisis del `git log --oneline -5`.

Los 4 puntos empíricos de la verificación pactada ejecutados sin incidencias:

- `git log --oneline -5` → HEAD en `7a13d48 docs(bitacora): add S12-J diary and update import checklist`, encima de `7e9d3c0 feat(infra): import DB subnet group task-manager-db-subnet-group`, encima de `ef6e5c1 docs(bitacora): add S12-I diary and update import checklist`. Cadena completa hasta S12-H visible. **Nota**: el prompt de continuación S12-K anticipaba *"bitácora S12-J + checklist actualizado pendientes de commit en frío"*; empíricamente `7a13d48` ya estaba pusheado — commit del diario cerrado entre la ventana matutina y la vespertina.
- `git status` → `working tree clean`, `Your branch is up to date with 'origin/main'`.
- `terraform state list | wc -l` → **30**.
- `terraform plan` → `No changes`, 30 recursos refreshed.
- `aws s3 cp .../terraform.tfstate - | jq '.serial'` → **33**.

Aplicación de candidata #S12I-2 al arranque: plan de bloques recordado explícitamente ANTES del warmup, aunque estuviera en el prompt de continuación. Sin confusión inicial del alumno (contraste con S12-I y coherente con S12-J). Aplicación acumulada 3ª limpia consecutiva.

Todo cuadró exactamente con lo esperado del estado al cierre de S12-J. Arranque limpio.

## Bloque 1 — Warmup 2 preguntas

Warmup pactado según locked ⭐⭐⭐ #S12H-1 (máximo 2 preguntas, 5 min techo). Ambas preguntas críticas relacionadas con la aplicación de la matización ampliada de #S12H-8 a EC2 y con la predicción teórica sobre `HttpPutResponseHopLimit`.

Preguntas planteadas:

- **A**: `HttpPutResponseHopLimit = 2` en el bloque `metadata_options` de EC2. Empírico verificado en S12-J: realidad AWS `2` (default histórico AWS cambió de `1` a `2` para no romper contenedores Docker que consumen IMDS desde dentro). Predicción sobre el schema del provider Terraform: (1) Optional+Computed (absorbe realidad sin drift si HCL lo omite) o (2) Optional con default literal `1` (requiere declaración explícita para evitar drift, análogo al `description` del IAM Role S12-H). Predicción del profesor: **Opción 1 con confianza ~60%**, aplicando ⭐⭐⭐ #S12E-1 al profesor con reconocimiento explícito de que las predicciones sobre defaults del provider son sistemáticamente débiles.
- **B**: referencia HCL desde `aws_instance.task_manager_ec2` al Instance Profile importado en S12-H (`aws_iam_instance_profile.ec2_task_manager`). Aplicando #S12H-8 con matización S12-J: schema del Instance Profile con `id = name` → alias → `.name` correcto. Confirma o corrige.

### Respuestas del alumno y análisis

- **Pregunta A**: alumno respondió *"Optional + Computed, no hace falta declararla"*. Predicción alineada con la del profesor. Aterrizaje inmediato del profesor: **la coincidencia entre predicciones NO es evidencia** — solo el `plan` post-import decide. Fallback mental preparado: si aparece `~ http_put_response_hop_limit = 2 -> 1`, declarar explícito. Verificable empíricamente en Bloque 3.
- **Pregunta B**: alumno respondió *".name... el .id es comodín, mejor el que toca"*. **El "qué" correcto** (aterrizaje del atributo semánticamente correcto), pero **la justificación imprecisa**: la formulación *"el .id es comodín"* es exactamente la que la matización S12-J ampliada de #S12H-8 desactiva. La regla ampliada dice literalmente: `.id` es correcto cuando el `id` del recurso destino es identificador propio opaco (subnets, SGs, VPCs) y **no** es comodín.

### Refuerzo sin softening de la matización S12-J

Corrección directa aplicada al alumno: la formulación *"el .id es comodín"* lleva a acertar por reflejo cuando toca `.name`/`.arn`/`.bucket`, pero produce duda o error cuando toca `.id` (subnets, SGs). Repaso mnemónico: **antes de referenciar, preguntarse si el `id` del destino es alias de otro atributo o identificador propio. Si es alias → atributo real. Si es identificador propio → `.id`. El "menos probable equivocarse" es la racionalización del comodín — señal de STOP.**

Las 3 referencias que el alumno iba a escribir en HCL de EC2, anticipadas con formulación correcta:

- `subnet_id = aws_subnet.public_1a.id` → `id = subnet-<hex>` opaco, identificador propio → `.id` correcto.
- `vpc_security_group_ids = [aws_security_group.ec2.id]` → `id = sg-<hex>` opaco, identificador propio → `.id` correcto.
- `iam_instance_profile = aws_iam_instance_profile.ec2_task_manager.name` → `id = name`, alias → `.name` correcto.

Aterrizaje operativo: **la matización S12-J requiere 3 intentos para consolidar** en el alumno (warmup B con justificación imprecisa → HCL Grupo 1 con `.arn` incorrecto → corrección directa). Anotable como aplicación 2ª de la regla pactada *"si un tema no ha aterrizado tras dos intentos, refuerza con ejemplo técnico directo"* (S12-J con `.id` como comodín + hoy con matización aplicada).

Warmup real ~4-5 min, dentro del techo. Cerrado.

## Bloque 3 — HCL EC2 en fichero nuevo `ec2.tf`

Bloque más denso de la sesión — **~1h 15min** de duración real, muy por encima de la estimación original de 30-40 min. Causas principales: introducción del mapping Cat 1/2/3/4 en caliente (vocabulario nuevo transversal), 3 iteraciones extra sobre HCL con correcciones de método por antipatrones detectados, 3 saltos de disciplina de método detectados y corregidos progresivamente.

### Paso 1 — Cabecera del recurso (sin errores mecánicos)

Alumno picó cabecera + Grupo 1 completo (6 atributos raíz) en un solo movimiento tras la introducción del término "opaco" no explicado por el profesor. Aplicación del salto de "paso a paso" pactado — el profesor había planteado picar solo la cabecera vacía, alumno picó Grupo 1 completo. Anotable como fricción de cadencia, no bloqueante.

### Aparición del término "opaco" sin introducción explícita — señal preventiva del alumno

Uso del término "opaco" por parte del profesor en 3 mensajes consecutivos (warmup B corrección, matización #S12H-8 refuerzo, andamiaje Bloque 3) sin introducción explícita del vocabulario. Alumno detectó el patrón y emitió: *"que quiere decir opaco?? es difícil este, vamos a intentarlo paso a paso"*.

Aplicación 2ª consecutiva de la candidata "vamos despacio" (S12-J en Bloque 3 + hoy en warmup B). Aterrizaje operativo: profesor detectó salto de la regla S12-D pactada (vocabulario técnico nuevo requiere introducción explícita antes de aparecer), aplicó corrección sin softening explícita, introdujo el término formalmente ("identificador opaco = string sin semántica externa, no revela información sobre lo que identifica"), y aceptó recalibración de cadencia a "paso a paso" (grupos discretos con verificación entre cada uno, no atributo por atributo).

Regla candidata específica del profesor derivada del caso: **cuando emerja vocabulario técnico nuevo por mi lado en caliente, introducirlo explícitamente antes de usarlo, sin abreviaturas ni contracciones**. Anotable para reforzar en S12-L.

### Grupo 1 — 2 errores mecánicos interceptados por #S12F-10

Primera versión del alumno tras recalibración "paso a paso":

```hcl
resource "aws_instance" "task_manager_ec2" {
  ami           = "ami-04df7d76c1b804451"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private_1a.id
  key_name      = "task-manager-key"
  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]
  iam_instance_profile = aws_iam_instance_profile.ec2_task_manager.arn
}
```

**Error 1 — `subnet_id = aws_subnet.private_1a.id`**: la EC2 empírica está en `subnet-0af881e02d4a9322b`, que en `main.tf` es `aws_subnet.public_1a` (verificado en descubrimiento S12-J). Alumno apuntó a `private_1a` (`subnet-00571f5c84fc414d3`, subnet privada de eu-west-1a). Si hubiera llegado a `terraform plan` post-import, Terraform propondría `~ subnet_id = "subnet-0af881e02d4a9322b" -> "subnet-00571f5c84fc414d3"` con `Forces new resource` → **`-/+ destroy and then create replacement` de la EC2**. Catastrófico. Interceptado por regla ⭐⭐⭐ #S12F-10 antes de `validate`.

Interpretación arquitectónica del error: la EC2 arranca Spring Boot con SSH manual + `nohup` (empírico S12-J, sin `user_data`). Para SSH desde casa requiere IP pública → subnet pública → ruta a IGW. Una subnet privada no tiene ruta a IGW en el scope actual. Aterrizaje operativo: **la referencia HCL tiene que coincidir con la realidad operativa, no con la subnet que "suena" primero**. Extensión de la regla ⭐⭐⭐ #19 a nombres locales de referencia HCL, no solo IDs de AWS.

**Error 2 — `iam_instance_profile = aws_iam_instance_profile.ec2_task_manager.arn`**: contradice la respuesta del alumno en warmup B (hace ~15 min) donde resolvió `.name`. Aplicación de la matización S12-J: `aws_iam_instance_profile.id = name` → alias → `.name` correcto. El `.arn` técnicamente funciona (el schema del `aws_instance.iam_instance_profile` acepta tanto `name` como `arn`), pero salta la disciplina consolidada de la sesión — el patrón "más específico = más seguro" es análogo al comodín `.id` en el otro extremo.

Aterrizaje operativo: **la matización #S12H-8 aún no está consolidada al 2º intento** del alumno. Aplicación de la regla pactada *"si un tema no ha aterrizado tras dos intentos, refuerza con ejemplo técnico directo, no con analogía cotidiana"* — profesor articuló la refutación con salida hipotética de `terraform state show aws_iam_instance_profile.ec2_task_manager` (id = name = "task-manager-ec2-role", arn = string distinto).

Alumno corrigió ambos errores en 2º pase, HCL Grupo 1 cerrado limpio.

### Introducción del mapping Categoría 1/2/3/4 en caliente — vocabulario nuevo denso

Detectado el patrón "todos son optional, así que lo declaro" (formulación exacta del alumno) al arrancar el bloque `metadata_options`, profesor introdujo el marco conceptual explícito para discriminar los 4 casos del schema Terraform:

1. **Categoría 1 — Required**: aparece marcado `(Required)` en Argument Reference. Omitir → `validate` falla.
2. **Categoría 2 — Optional con default literal**: aparece `(Optional)` + línea `Defaults to X` o `Default is X` con X valor concreto hardcodeado en el schema. Si realidad = X → omitir sin drift. Si realidad ≠ X → drift, `plan` propone `~ atributo = <realidad> -> X`. Ejemplo empírico duro: `aws_iam_role.description` en S12-H.
3. **Categoría 3 — Optional+Computed**: aparece `(Optional)` **sin** línea de default. Schema absorbe cualquier valor pre-existente en AWS sin drift si se omite. Ejemplos empíricos: `aws_route_table.route`, `aws_security_group ingress/egress`, `aws_vpc_endpoint.route_table_ids/policy`.
4. **Categoría 4 — Optional que fuerza replacement al cambiar**: aparece `(Optional)` + etiqueta `Forces new resource`. Ortogonal a Cat 2 vs Cat 3. Ejemplo: `name` en `aws_db_subnet_group`.

Regla mnemónica derivada: **"¿aparece la palabra 'default' en la línea del atributo?"** → sí = Cat 2, no = Cat 3. Filtro binario aplicable literalmente al texto del Argument Reference.

Anotable como **regla candidata #S12K-1**: aterrizaje del mapping Cat 1/2/3/4 como marco conceptual reutilizable en todo el roadmap. 20+ aplicaciones prácticas hoy. Falta 1-2 aplicaciones más en apply S12-L para promoción a locked.

### Grupo 2 `metadata_options` — 3 iteraciones para aterrizar la distinción Cat 2 vs Cat 3

Primera versión del alumno tras introducción del mapping: declarar los 5 sub-atributos (`http_tokens`, `http_endpoint`, `http_put_response_hop_limit`, `http_protocol_ipv6`, `instance_metadata_tags`) con racional *"todos son optional, así que lo declaro"*. Sobre-declaración segura contra drift pero pierde el aprendizaje empírico del mapping.

Profesor articuló el trade-off explícito:

- Coste #1 — pérdida de información diagnóstica sobre qué es Cat 2 vs Cat 3.
- Coste #2 — verbosidad innecesaria en atributos Cat 2 con default coincidente o Cat 3.

Propuesta operativa: al menos omitir `http_put_response_hop_limit` para probar empíricamente la predicción del warmup A. Resto a decisión del alumno con distinción Cat 2 vs Cat 3 explícita.

Alumno consultó Argument Reference y clasificó atributo por atributo con racional articulado:

- `http_tokens` → Cat 3 (sin línea "Defaults to") → declarar `= "required"` por documentación de intención de seguridad (control compliance IMDSv2, control esperado en auditorías SOC 2 / PCI DSS / ISO 27001).
- `http_endpoint` → Cat 2 con default `"enabled"` coincidente → omitir sin drift.
- `http_put_response_hop_limit` → **Cat 2 con default literal `1` NO coincidente con realidad `2`** → declarar `= 2` obligatorio para evitar drift. **Refutación empírica de la predicción del warmup A**: los dos apostamos Cat 3, la Argument Reference dice literal *"Defaults to 1"* → Cat 2. Aplicación **4ª acumulada ⭐⭐⭐ #S12E-1**, ahora también aplicable al alumno.
- `http_protocol_ipv6` → Cat 2 con default `"disabled"` coincidente → omitir sin drift.
- `instance_metadata_tags` → Cat 2 con default `"disabled"` coincidente → omitir sin drift.

HCL final del Grupo 2 con **2 atributos declarados, 3 omitidos**. Aplicación limpia del mapping al 2º intento. Aterrizaje sólido de la distinción Cat 2 vs Cat 3.

### Grupo 3 `root_block_device` — aplicación limpia del mapping + racional (a) documentar ADR-A17

Alumno consultó Argument Reference y clasificó los 6 sub-atributos:

- `volume_type`, `volume_size`, `iops`, `throughput` → Cat 3 (todos "Optional sin default listado") → omitir → schema absorbe realidad sin drift.
- `delete_on_termination = true` → Cat 2 con default coincidente.
- `encrypted = false` → Cat 2 con default coincidente.

Alumno declaró los 2 últimos aunque técnicamente omitirlos no produciría drift. Racional articulado en 2 pasos:

- Primer pase: sin racional articulado, aplicó "declarar por si acaso" (mismo antipatrón del Grupo 2).
- Profesor articuló la asimetría respecto al Grupo 2 (omitió Cat 2 coincidentes) y planteó 3 explicaciones posibles con solicitud de racional consciente.
- Segundo pase: alumno articuló **opción (a) documentar deuda técnica ADR-A17 en HCL** (`encrypted = false` visible en revisión de PR, tracking de la deuda) + coherencia estilística intra-bloque con `delete_on_termination`. Racional consciente y defendible.

Aterrizaje operativo importante: **el racional (a) documentar decisión explícita en HCL** emerge como decisión pedagógica válida distinta del racional Cat 2/3 puro. Aplicable a controles compliance y a deudas técnicas visibles. Aterrizaje aplicable en Grupos siguientes.

### Grupo 4 — atributos operativos raíz sueltos + tags

3 atributos empíricos (`ebs_optimized = true`, `disable_api_termination = false`, `instance_initiated_shutdown_behavior = "stop"`). Alumno consultó Argument Reference:

- Los 3 marcados `(Optional)` **sin** línea "Defaults to" → Cat 3 pura.
- Realidad AWS coincide con "default AWS implícito" en los 3.

Alumno declaró los 3 con racional *"no sé si lo mejor es declarar los tres"* — 2ª aparición del patrón "declarar por incertidumbre". Profesor articuló distinción entre racional (a) documentar decisión operativa explícita vs racional (b) declarar por incertidumbre. Alumno reconoció que era (b) y decidió omitir los 3. Aterrizaje **al 3er intento** de la distinción Cat 2 vs Cat 3 aplicada consistentemente en todo el HCL.

Tags: `tags = { Name = "task-manager-ec2" }`. Match empírico único tag. Camino A respetado (importar realidad tal cual).

### Ciclo pactado completo — validate + plan pre-import + import + plan post-import

Aplicación del ciclo pactado con **3 saltos de disciplina detectados y corregidos progresivamente**:

**Salto 1 — candidata #S12I-1** (verificación conjunta ANTES de `validate`): tras eliminación de los 3 atributos operativos del Grupo 4, alumno ejecutó `validate` sin pasar el HCL editado al profesor. Detectado por el profesor: aplicación acumulada de la candidata 3 (S12-I limpia + S12-J limpia + S12-K SALTADA). Regresión respecto a las 2 sesiones anteriores. Corrección: pasar HCL post-eliminación al profesor para verificación diferida antes de `plan`. Alumno pasó el fichero, verificación conjunta limpia.

**`terraform validate`** → `Success! The configuration is valid.` ✓

**Predicción escrita del `plan` pre-import**: `Plan: 1 to add, 0 to change, 0 to destroy` (aplicación limpia ⭐⭐⭐ pre-import plan always shows `+ create`). Nivel 2 con 3 referencias resueltas (`subnet_id`, `vpc_security_group_ids`, `iam_instance_profile`). Confianza ~99% en Nivel 1.

**`terraform plan` pre-import**: confirmó predicción. **Hallazgos empíricos importantes**:

- **Refutación de Cat 2 para `instance_metadata_tags`**: la Argument Reference decía "Defaults to disabled" (Cat 2), pero el `plan` mostró `instance_metadata_tags = (known after apply)` (Cat 3). Formulación de la regla candidata **#S12K-2**: *"la Argument Reference documenta la intención declarada del provider, no el schema real 100%. El plan pre-import expone el schema real. Cuando divergen, gana el plan"*. Aplicable a la regla S12-C aterrizada empíricamente. 1ª aplicación empírica. Falta 1-2 aplicaciones más para promoción a locked.
- Los 4 sub-atributos omitidos del `root_block_device` (`volume_type`, `volume_size`, `iops`, `throughput`) aparecen como `(known after apply)` → **Cat 3 confirmada empíricamente** para los 4.
- Los 3 atributos operativos raíz omitidos aparecen como `(known after apply)` → **Cat 3 confirmada empíricamente**.
- Descubrimiento nuevo: `disable_api_stop = (known after apply)` — atributo del schema no discutido, análogo a `disable_api_termination` pero para `StopInstances`. Cat 3, absorbe sin drift. Anotable como vocabulario nuevo detectado por empírico.
- Descubrimiento nuevo: `force_destroy = false`, `get_password_data = false`, `user_data_replace_on_change = false`, `source_dest_check = true` — atributos con defaults literales hardcodeados en el provider (Cat 2 con default coincidente con realidad). Sin drift esperado.

**Salto 2 — ⭐⭐⭐ #24 saltada**: tras `plan` pre-import, alumno ejecutó `import` seguido de `plan` post-import sin escribir predicción explícita entre medias. Detectado por el profesor: la ⭐⭐⭐ #24 es locked, no candidata. Salto directo sin predicción escrita = 2ª aplicación saltada consecutiva en la sesión. Corrección explícita aplicada al análisis del `plan` post-import — sin daño operativo pero anotable como fricción de método.

**`terraform import aws_instance.task_manager_ec2 i-031f9ec92618edea1`** → Import successful. Aplicación limpia ⭐⭐⭐ #19 (re-lectura del instance-id carácter a carácter). Confirmación empírica de la matización S12-J de ⭐⭐⭐ #S12H-8 aplicada a EC2: `id = i-031f9ec92618edea1` opaco, identificador propio, no alias. **Aplicación 8ª acumulada** de la regla.

**`terraform plan` post-import** → `No changes. Your infrastructure matches the configuration`. ✓

**Consolidaciones empíricas del `plan` post-import**:

- `http_endpoint`, `http_protocol_ipv6` omitidos → absorbidos sin drift. Cat 2 con default coincidente confirmada.
- `instance_metadata_tags` omitido → absorbido a `"disabled"` sin drift. Cat 3 confirmada empíricamente (refutación de Cat 2 según docs, 1ª aplicación #S12K-2).
- 4 sub-atributos `root_block_device` omitidos → absorbidos sin drift. Cat 3 confirmada.
- 3 atributos operativos raíz omitidos → absorbidos sin drift. Cat 3 confirmada.
- `http_tokens = "required"` declarado → sin drift (declaración con valor coincidente al empírico, seguro contra Cat 2 y Cat 3).
- `http_put_response_hop_limit = 2` declarado → sin drift (Cat 2 con default no coincidente, declaración obligatoria).

Verificación estado post-import: `terraform state list | wc -l` = **31**, serial = **34**. ✓

Ciclo cerrado sin fricción tras las 3 correcciones de método interceptadas. Aplicación acumulada 31 del ciclo pactado.

## Bloque 4 — HCL RDS en `rds.tf`

Bloque densísimo — **~55 min** de duración real. Escritura del HCL con 5 grupos discretos + verificación entre cada uno + ciclo pactado con drift real analizado empíricamente + reconciliación con Camino A.

### Recalibración de tiempo pactada al arranque — ventana ampliada

Consumo real del Bloque 3 (EC2): ~1h 15min vs estimación 30-40 min. Desviación de +45min. Reloj disponible antes de arrancar Bloque 4: ~45 min hasta 17:30. Estimación honesta del Bloque 4 (HCL + verificación + commit + push): 45-55 min. **No cabe en 45 min sin recortar método**.

Profesor planteó 3 opciones:

- (A) Cerrar sesión aquí, S12-L mañana con RDS. Ventaja: sin prisa. Coste: 1 sesión más, 1 diario extra.
- (B) Cerrar EC2 hoy con commit + push, arrancar RDS mañana en sesión propia. Ventaja: cierra bloque cómputo hoy, evita prisa. Coste: 1 diario extra, RDS con Bloque 0 propio.
- (C) Arrancar RDS con reloj apretado. Coste: presión aumenta probabilidad de saltos de método (ya 3 en la sesión). Aterrizaje esperable peor que cierre limpio.

**Recomendación del profesor: opción (B)** por consolidación del aterrizaje operativo de EC2 y evitar arrancar RDS en modo apurado (los 3 saltos son bandera de sobrecarga, aunque no verbalizada).

Alumno respondió *"no te preocupes por el tiempo puedo estar más tiempo"*. Aplicación **5ª ⭐⭐⭐ #S12E-1 al profesor**: lectura de "sobrecarga por saltos de método" era interpretativa, autoconocimiento operativo del alumno es la fuente de verdad. Corrección sin softening: ventana ampliada NO es licencia para relajar método — solo margen para aplicarlo mejor. Predicción escrita antes de cada `plan` sin excepciones + verificación conjunta antes de `validate` sin excepciones.

### Paso 1 — Grupo 1 identidad + engine + red + credenciales

Primera versión del alumno con 5 atributos declarados (`identifier`, `engine`, `instance_class`, `db_subnet_group_name`, `vpc_security_group_ids`). Nombre local escrito como `task_manager` (colisión con `aws_db_subnet_group.task_manager` ya presente + inconsistencia con `task_manager_ec2` de hace ~1h). Corrección del nombre local a `task_manager_db`.

Profesor solicitó racional articulado para los 6 atributos que faltaban (`engine_version`, `db_name`, `username`, `availability_zone`, `multi_az`, `publicly_accessible`) con especial atención a `db_name` y `username` (posibles Cat 4 → riesgo si omites).

Alumno respondió con lista condensada:
- `engine_version` → declarado por argumento compliance banca del profesor (racional aceptado, no propio).
- `db_name` → omito, sin racional articulado.
- `username` → declarado, Required.
- `availability_zone`, `multi_az`, `publicly_accessible` → omito, sin racional articulado.

**Corrección de método crítica sin softening — `db_name` omitido sin verificación de categoría**: es el atributo que el profesor marcó como el más peligroso de omitir sin verificación. Si fuera Cat 4 + Cat 2 con default vacío, omitir produciría `~ db_name = "task_manager" -> ""` con force replacement en `plan` post-import → **destruir la RDS con datos** en un apply hipotético. Interceptado por el ciclo pactado antes de cualquier apply (⭐⭐⭐ #14), pero el diagnóstico habría sido feo.

**Auto-observación del profesor sin softening**: en los últimos 4-5 intercambios el profesor pidió racional articulado y el alumno respondió con listas condensadas de una línea. **La pregunta del profesor también fue larga y densa** — 6 atributos con clasificación pedida a la vez es demanda alta cuando el alumno lleva ~1h 30min de sesión. Ratio observable: densidad del ask ≠ cadencia "vamos paso a paso" pactada. Corrección de método operativa: profesor recortó el ask a 2 atributos por tanda, empezando por el más crítico (`db_name`).

### Introducción de la abreviatura "Optional Force" sin explicar — 2ª corrección de método por vocabulario

Al plantear predicciones sobre `db_name` y `username`, profesor usó abreviatura "Optional Force" para referirse a Categoría 4 sin introducción explícita. Alumno detectó: *"cuando dices Optional Force, no veo que ponga eso en la sección de Argument Reference"*.

Aplicación 2ª consecutiva de la regla S12-D violada por el profesor en la sesión (después de "opaco" al arrancar Bloque 3). Regla candidata derivada del profesor consolidada en 2ª aplicación: **cuando emerja vocabulario técnico nuevo por mi lado, introducirlo explícitamente antes de usarlo, sin abreviaturas ni contracciones**. Corrección aplicada: "Optional Force" = Cat 4 del mapping (Optional + "Forces new resource").

### Análisis tanda a tanda del Grupo 1 con cadencia recortada

**Tanda 1 — `db_name`**: alumno pegó texto exacto de Argument Reference. Sin línea "Defaults to" en el texto → Cat 3 aplicando mapping literal. Alumno formuló *"solo pone optional, no sé distinguir si es Categoría 2, 3 o la que sea, si solo pone Optional y en el describe, ya pone el nombre lo tendría que poner??"* + autonarrativa *"con mi ignorancia total"*. Preguntó también si el profesor podría acceder a Argument Reference directamente en lugar del alumno pegar el texto.

**Corrección de la autonarrativa saboteadora sin softening (aplicación 2ª candidata S12-J en la sesión)**: repaso empírico de competencia del alumno demostrada en la propia sesión (matización #S12H-8 aplicada correctamente a EC2, distinción Cat 2 vs Cat 3 aterrizada al 3er intento en Grupo 4 EC2, aplicación del mapping a `db_name` correctamente aplicada como Cat 3 aunque formulada como "solo optional", 5 atributos Grupo 1 RDS picados con 0 errores mecánicos, capacidad de pegar texto Argument Reference exacto = método científico). Distinción operativa articulada: **"no sé distinguir esto ahora mismo" ≠ "ignorancia total"** — la primera es lectura precisa del propio estado epistémico, la segunda es autosabotaje. Aplicable a entrevistas (cuando entrevistador pregunta técnica y candidato acaba de responder correctamente 3 cosas seguidas, la frase "no sé nada" borra la evidencia empírica que el entrevistador está viendo).

Regla candidata S12-J refinada: **la autonarrativa saboteadora aparece más frecuentemente cuando el alumno acaba de aplicar bien el método sin verse aplicándolo bien**. Aplicable narrativa entrevista. 2ª aplicación consolidada.

**Pregunta operativa sobre acceso a Argument Reference — decisión (A) modo Socrático puro**: profesor tiene herramientas de fetch web disponibles (`web_search`, `web_fetch`). No las ha usado por decisión pedagógica pactada — método Socrático dice "tú das pistas no soluciones completas" + "NO dumpear traducciones". 3 opciones planteadas:

- **(A) Modo Socrático puro**: alumno lee Argument Reference, pega texto, profesor analiza contra mapping. Ventaja: aprende a leer docs autónomamente. Coste: más lento.
- **(B) Verificación bajo demanda**: modo (A) por defecto, profesor hace fetch bajo pedido explícito. Ventaja: red de seguridad para casos ambiguos.
- **(C) Fetching compartido al inicio de bloque**: profesor pega texto al inicio de cada bloque de recursos nuevo. Ventaja: elimina fricción de "no sé si copié bien". Coste: acerca a "co-lectura".

**Alumno eligió (A)** con racional implícito de autonomía. Anotable como aterrizaje explícito del pacto pedagógico Socrático al arrancar S12-K + resto del roadmap AWS. Habilidad transferible directamente a entrevistas técnicas y trabajo real banca (típicamente restringe uso de asistentes IA sobre infra productiva por compliance).

Cierre `db_name`: mantener omitido, Cat 3 aplicada correctamente. Riesgo latente anotado (Cat 4 encubierta por texto ambiguo *"If this parameter is not specified, no database is created"*): no modificar `db_name` post-import salvo con apply pactado explícito.

**Tanda 2 — `availability_zone` + `multi_az`**: ambos clasificados Cat 3 (Optional sin default listado). Omitir con racional *"son opcionales y quiero que los absorba"*. Aplicación 3ª consecutiva candidata S12-J en la sesión (autonarrativa "pero la razón que te puedo dar es que no la tengo muy clara" corregida con evidencia empírica — la frase *"son opcionales y quiero que los absorba"* ES un racional articulado completo del mapping Cat 3).

**Tanda 3 — `publicly_accessible`**: alumno clasificó Cat 3 con racional *"omito"*. **Corrección técnica sin softening**: el texto pegado por el alumno decía literal *"Default is false"* → Cat 2 con default coincidente aplicando mapping literal, no Cat 3. Decisión operativa (omitir) mantenida — sin coste técnico — pero clasificación errónea. Aterrizaje operativo: el mapping funciona como filtro binario, la regla es literal *"¿aparece la palabra 'default' en la línea?"*. Alumno decidió finalmente **declarar `publicly_accessible = false`** por racional (a) documentar control compliance ISO 27001 A.13.1 (coherencia estilística con `http_tokens = "required"` del Grupo 2 EC2).

Grupo 1 RDS cerrado con **8 atributos declarados**.

### Paso 2 — Grupo 2 Storage

Alumno consultó Argument Reference para los 4 atributos:

- `allocated_storage = 20` → Required, declarar. ✓
- `storage_type` → clasificado Cat 3 por alumno (*"al ser optional, lo omito"*), **corrección técnica sin softening 2ª aparición del mismo error**: el texto pegado tenía *"The default is 'io1' if iops is specified, 'gp2' if not"* → Cat 2 con default condicional. Refuerzo con ejemplo técnico directo aplicado (regla pactada "si no ha aterrizado tras dos intentos"). Decisión omitir mantenida (default `"gp2"` coincidente con realidad → sin drift), clasificación corregida a Cat 2.
- `storage_encrypted = true` → Cat 2 con default `false` NO coincidente con realidad `true` → declarar obligatorio para evitar drift. Aplicación limpia del mapping (Cat 2 sin coincidencia → declarar).
- `kms_key_id` → Cat 3 (Optional sin default listado) → omitir → schema absorbe ARN de `aws/rds` managed.

Grupo 2 cerrado con **2 atributos declarados**. Consolidación de la regla mnemónica *"¿aparece 'default' en el texto?"* al 3er intento tras refuerzo con ejemplo técnico directo.

### Paso 3 — Grupo 3 Backup

Alumno consultó Argument Reference para los 5 atributos y clasificó **los 5 correctamente al primer intento**:

- `backup_retention_period = 1` → Cat 2 default `0` no coincidente → declarar obligatorio.
- `backup_window` → Cat 3 → omitir.
- `maintenance_window` → Cat 3 → omitir.
- `copy_tags_to_snapshot = true` → Cat 2 default `false` no coincidente → declarar obligatorio.
- `deletion_protection = true` → Cat 2 default `false` no coincidente → declarar obligatorio + racional (a) compliance banca (control resiliencia operativa EBA/BdE).

Aterrizaje sólido de la regla mnemónica *"¿aparece 'default'?"* aplicada consistentemente. Grupo 3 cerrado con **3 atributos declarados**.

### Paso 4 — Grupo 4 Operación

Alumno consultó Argument Reference para los 6 atributos:

- `auto_minor_version_upgrade` → Cat 2 default `true` coincidente. Declarado con racional impreciso *"por si se produce cambio"*. Corrección de método sin softening: racional operativo sería *"declarar para protegerme contra cambios futuros del default del provider"*, no *"por si se produce cambio"*. Decisión mantenida, articulación imprecisa anotada.
- `ca_cert_identifier` → Cat 3 (Optional sin default listado). **Alumno omitió inicialmente**, después cambió a declarar `= "rds-ca-rsa2048-g1"` sin racional articulado. Profesor solicitó articulación explícita del cambio: opción (a) aterrizaje meta-patrón "aplicar racional (a) consistentemente a controles compliance" o opción (b) cambio por sugerencia sin filtro. **Alumno confirmó opción (a)**. Consolidación del meta-patrón coherencia compliance a 4 atributos en RDS: `publicly_accessible = false` + `deletion_protection = true` + `ca_cert_identifier = "rds-ca-rsa2048-g1"`. Patrón consistente identificable en revisión de PR banca.
- `iam_database_authentication_enabled` → Cat 3 (texto sin línea "Defaults to") → omitir → schema absorbe `false` sin drift.
- `performance_insights_enabled` → Cat 2 default `false` coincidente → omitir sin drift.
- `parameter_group_name` → Cat 3 → omitir → schema absorbe managed default `default.postgres18`.
- `option_group_name` → Cat 3 → omitir → schema absorbe managed default `default:postgres-18`.

Grupo 4 cerrado con **2 atributos declarados**.

### Paso 5 — Grupo 5 Tags

Aplicación limpia candidata #S12J-1: `tags = { Project = "task-manager" }` — tag de la RDS instance, NO confundir con `TagList: []` del subnet group anidado en `describe-db-instances`. Camino A respetado. Aplicación acumulada 2ª de la candidata (S12-J caso positivo real + hoy aplicación limpia). Falta 1-2 aplicaciones más para promoción a locked.

### Ciclo pactado — validate + plan pre-import + import + plan post-import

**Aplicación limpia candidata #S12I-1**: alumno pasó HCL COMPLETO ANTES de `validate` para verificación conjunta. Aplicación **2ª limpia consecutiva** en la sesión tras corrección del salto del Bloque 3. Recuperación de disciplina consolidada.

**`terraform validate`** → `Success!` ✓

**Predicción escrita ⭐⭐⭐ #24 del `plan` pre-import**: alumno escribió *"Plan: 1 to add, 0 to change, 0 to delete"* (léxico impreciso — `destroy`, no `delete`). Sustancia correcta, corrección terminológica menor aplicada. **Aplicación limpia de la ⭐⭐⭐ #24 esta vez** — sin salto. Contraste explícito con el salto del Bloque 3. Recuperación de disciplina consolidada 2ª aplicación.

**`terraform plan` pre-import**: `Plan: 1 to add, 0 to change, 0 to destroy`. **4 hallazgos empíricos importantes**:

- **Hallazgo 1**: `db_name = (known after apply)` → **Cat 3 confirmada empíricamente**. El riesgo latente catastrófico (Cat 2 con default vacío → destroy+create de la RDS) queda descartado al 100%. Aplicación del mapping literal validada por empírico.
- **Hallazgo 2**: 6 atributos omitidos aparecen todos como `(known after apply)` → Cat 3 confirmada consistentemente (`availability_zone`, `backup_window`, `maintenance_window`, `parameter_group_name`, `option_group_name`, `iam_database_authentication_enabled`, `storage_type`, `kms_key_id`). Confianza en el mapping restaurada al ~95% para atributos RDS. `multi_az = (known after apply)` refuta clasificación Cat 3 con default coincidente, confirma Cat 3 pura.
- **Hallazgo 3**: 4 atributos NUEVOS descubiertos con default literal hardcodeado en el `+ create`, no discutidos en ningún Grupo: `apply_immediately = false`, `dedicated_log_volume = false`, `delete_automated_backups = true`, `monitoring_interval = 0`, `skip_final_snapshot = false`. Todos con default coincidente con realidad AWS típica → sin drift esperado post-import. Anotable como enriquecimiento del mapa mental sobre `aws_db_instance`. Aplicación 2ª #S12K-2 (`plan` pre-import expone schema real completo, incluyendo atributos que docs no priorizan). 1 aplicación anterior en EC2 (`instance_metadata_tags`). Falta 1-2 aplicaciones más para promoción a locked.
- **Hallazgo 4**: `password_wo = (write-only attribute)` — atributo Terraform 1.11+ nueva feature "write-only attributes". Confirmación empírica del **Camino 3 pactado (ADR-A19)** funcionando sin fricción. Sin declarar `password` ni `password_wo` en HCL, schema absorbe la ausencia sin drift esperado. ✓

Descubrimientos técnicos menores adicionales: `engine_version_actual`, `identifier_prefix`, `master_user_secret*`. Todos `(known after apply)` sin coste.

**`terraform import aws_db_instance.task_manager_db task-manager-db`** → Import successful. Aplicación limpia ⭐⭐⭐ #19 (re-lectura del `db-instance-identifier` carácter a carácter). **Descubrimiento crítico**:

**El `id` del recurso en state es `db-CMRXOHT44O5AJNYKRNPJZMNZ5A`**, NO `task-manager-db` como predije. Aplicación 6ª ⭐⭐⭐ #S12E-1 al profesor. Refutación empírica de la matización S12-J de #S12H-8 aplicada a RDS:

- Predicción del profesor: `id = identifier` = alias → referenciar RDS con `.identifier`.
- Empírico: `id = "db-CMRXOHT44O5AJNYKRNPJZMNZ5A"` — identificador propio opaco distinto del `identifier` legible.

**Formulación de la matización S12-K de ⭐⭐⭐ #S12H-8**: nuevo caso — recursos donde el `id` de state es distinto del alias legible que usa el `import` command. `aws_db_instance` no encaja limpiamente en la dicotomía "id = alias" vs "id = identificador propio opaco". El `identifier` es alias de negocio legible (`task-manager-db`) usado para el argumento del `import`; el `id` del state es un identificador opaco de recurso distinto (`db-<hex>`) generado por AWS internamente al crear la instance. Para futuras referencias HCL a `aws_db_instance`, comprobar empíricamente con `terraform state show` cuál es el `id` antes de decidir entre `.id`, `.identifier`, `.arn`. Anotable como aprendizaje meta del roadmap, aplicable en apply S12-L.

### Drift `skip_final_snapshot` — 3 iteraciones con 3 refutaciones consecutivas del profesor

**`terraform plan` post-import** → `Plan: 0 to add, 1 to change, 0 to destroy` con `~ update in-place` mostrando:

- `+ apply_immediately = false` (schema añade atributo control-only al state).
- `~ skip_final_snapshot = true -> false` (drift real).

**PARADA OPERATIVA aplicada — regla operativa OBLIGATORIA S12-K + regla S12-C**: drift detectado, análisis antes de cualquier acción.

**Iteración 1 — análisis inicial del profesor**: interpretación del drift como `apply_immediately` schema-only no-op + `skip_final_snapshot` mal etiquetado en Grupo 5 (*"solo importa en destroy, no en import — mencionable pero no operativo hoy"*, framing incorrecto en la introducción del Grupo 5). Reformulación: `skip_final_snapshot` es Cat 2 con default `false` según Argument Reference. Realidad AWS post-import: `true`. Aplicación 6ª ⭐⭐⭐ #S12E-1.

**Decisión operativa 1 — Opción B con `final_snapshot_identifier`**: alumno consultó Argument Reference. `skip_final_snapshot` Cat 2 default `false`. `final_snapshot_identifier` dependiente ("Must be provided if `skip_final_snapshot` is set to false"). Alumno eligió declarar `skip_final_snapshot = false` + `final_snapshot_identifier = "task-manager-db-final-snapshot"` con racional (a) coherente con `deletion_protection = true` (controles compliance de protección de datos, banca real, EBA/BdE resiliencia operativa).

Alumno editó HCL, aplicación limpia candidata #S12I-1 3ª vez (pasó HCL ANTES de `validate`), ejecutó `validate` + `plan`. Empírico: **`~ skip_final_snapshot = true -> false`** sigue apareciendo idéntico al plan anterior.

**Iteración 2 — refutación empírica del análisis anterior del profesor**: la declaración de `skip_final_snapshot = false` en HCL NO reconcilió el drift. Reformulación del análisis: `skip_final_snapshot` **NO es control-only de Terraform sobre destroy futuro** (como interpretó con `apply_immediately`). Es atributo del schema que persiste el valor en state y que un `apply` sí modificaría en AWS. Regla derivada: **el símbolo `~` significa mutación real, sin trampas ni interpretaciones sofisticadas**.

Aplicación 7ª ⭐⭐⭐ #S12E-1. 2ª predicción incorrecta consecutiva sobre `skip_final_snapshot`.

**Decisión operativa 2 — Opción X + ADR-A20 (Camino A ortodoxo)**: aplicación literal de la regla pactada S12-G (Camino A primero, Camino B con apply pactado después). Consistencia total con decisiones anteriores del roadmap (A17 root volume encrypted, A18 storage_type gp2). Eliminar `skip_final_snapshot = false` + `final_snapshot_identifier` del HCL, esperar que schema absorba realidad `true`. **Candidato ADR-A20 anotado**: `skip_final_snapshot = true` importado como realidad, incumple racional (a) compliance banca, resolución pactada en primer apply.

Alumno editó HCL eliminando las 2 líneas, aplicación limpia candidata #S12I-1 4ª vez, ejecutó `validate` + `plan`. Empírico: **`~ skip_final_snapshot = true -> false` SIGUE APARECIENDO** — omisión no reconcilió el drift.

**Iteración 3 — refutación empírica 2ª del análisis del profesor**: la eliminación del atributo del HCL NO produjo absorción esperada. Aplicación 8ª ⭐⭐⭐ #S12E-1. **3ª predicción incorrecta consecutiva sobre el mismo atributo**.

**Predicción correcta del alumno superando al profesor**: alumno articuló en su respuesta *"va a seguir saliendo 1 to add"* ANTES de ejecutar el `plan` post-eliminación. Su intuición empírica anticipó lo que el análisis teórico del profesor NO supo predecir. Anotable como **caso positivo consolidado** para narrativa entrevista + refutación empírica en tiempo real de la autonarrativa saboteadora del alumno ("no sé nada" refutada por la propia predicción correcta hace 5 minutos que el profesor no supo hacer). Aplicación 4ª candidata S12-J en la sesión.

**Regla derivada personal del profesor sin softening**: **cuando acumule 2+ predicciones incorrectas sobre el mismo objeto empírico, PARAR y verificar antes de proponer más**. Aplicación de la regla S12-C al lado del profesor. Anotable para aterrizaje meta del profesor en el roadmap.

**Verificación empírica del state con `terraform state show`**:

```bash
terraform state show aws_db_instance.task_manager_db | grep -i skip_final_snapshot
    skip_final_snapshot                   = true
```

State real: `skip_final_snapshot = true`. Aplicación limpia de la disciplina S12-C que el profesor violó 3 veces — verificación empírica antes de decisión con confianza refundada.

**Decisión operativa 3 — Opción α (declarar `skip_final_snapshot = true` en HCL)**: alineación explícita con realidad AWS. Declaración literal *"quiero mantener `true`, no reconciles"*. Predicción operativa: `plan` post-declaración `No changes` estricto sobre `skip_final_snapshot`. Confianza ajustada al ~75-90% (mantenía humildad por 3 refutaciones acumuladas).

Alumno editó HCL añadiendo `skip_final_snapshot = true`, aplicación limpia candidata #S12I-1 5ª vez, ejecutó `validate` + `plan`. Empírico: **`No changes. Your infrastructure matches the configuration`** ✓

Reconciliación completa. Escenario A confirmado.

**Aterrizaje empírico total**: al declarar `skip_final_snapshot = true` en HCL, tanto ese atributo como `apply_immediately` desaparecen del `plan`. **`apply_immediately` NO era schema-only no-op** — se comportaba consistentemente con `skip_final_snapshot` en la lógica del schema del provider. Aplicación 8ª ⭐⭐⭐ #S12E-1 consolidada empíricamente. Comprensión del comportamiento del schema `aws_db_instance` para atributos de control operativo (`skip_final_snapshot`, `apply_immediately`) requiere declaración explícita post-import para eliminar drift residual.

**Regla candidata #S12K-3 formulada empíricamente**: *"algunos atributos del schema `aws_db_instance` (`skip_final_snapshot`, `apply_immediately`) tienen comportamiento anómalo post-import — requieren declaración explícita en HCL para reconciliar drift residual, no basta con omisión ni con verificación del state"*. 1 aplicación empírica hoy. Falta 1-2 aplicaciones más para promoción a locked. Anotable para verificación en apply S12-L.

Verificación estado post-reconciliación: `terraform state list | wc -l` = **32**, serial = **35**. ✓

**Predicción incorrecta del profesor sobre el serial**: predijo `36` (asumiendo pre-EC2 = 34, incorrecto — el pre-EC2 era 33, verificado empíricamente en Bloque 0). Aplicación 9ª ⭐⭐⭐ #S12E-1. Corrección de método: reconstrucción de historia por el profesor sin verificar contra empírico documentado en la propia sesión. Anotable como aprendizaje meta del profesor.

## Bloque 9 — Verificación intermedia (~2 min)

Ya cubierta implícitamente en el `plan` post-reconciliación del Bloque 4. Chequeo final de `git status` desde el repo: `ec2.tf` untracked + `rds.tf` modified, nada más. Coherente con la sesión.

## Bloque 10 — Commit + push (~15 min)

Ciclo git pactado completo aplicado sin desvíos operativos.

- `git status` inicial (paso saltado por el alumno, ejecutó directamente `git add` + `git status` post-add — anotable como 3ª aparición del patrón "optimizar velocidad de ejecución a costa de disciplina paso a paso" en la sesión, sin daño operativo).
- `git add infra/ec2.tf infra/rds.tf` (regla ⭐⭐⭐ nunca `git add .`).
- `git status` intermedio: `ec2.tf` new file + `rds.tf` modified, nada más. ✓
- `git diff --staged`: diff quirúrgicamente limpio. `ec2.tf` completo con `+` en 21 líneas, `rds.tf` con `+` solo en el bloque nuevo `aws_db_instance` (24 líneas), subnet group SIN líneas `-`/`+` — sin contaminación whitespace. Match letra por letra contra el HCL verificado hace ~30 min con `terraform plan = No changes`.
- **Redacción del mensaje bilingüe correcta al primer intento** — **aterrizaje S12-H mantenido 3ª sesión consecutiva** (S12-I, S12-J, S12-K con 0 amend en las 3). Subject `feat(infra): import EC2 instance and RDS instance`, cuerpo EN 5 frases densas con qué + verificación + deuda + aterrizaje pedagógico + preparación siguiente, separador `---`, cuerpo ES 5 frases sin acentos ni ñ (`verificacion`, `reconciliacion`, `tecnica`, `sesion`, `matizacion`, `categoria`, `empiricamente`).
- `git commit` sin `-m` → `d6880b1`, 2 ficheros, 45 inserciones.
- `git log -1 --format=full`: cuerpo íntegro verificado letra por letra por el profesor. 0 corrupciones del editor. Acentos y ñ ausentes en ES. Identidad autor correcta (`Tole <manutol@gmail.com>`). HEAD -> main local, no pusheado.
- **Triple confirmación conjunta explícita (regla ⭐⭐⭐ #31, aplicación 8ª consecutiva)**: `Tole confirma SÍ / Claude confirma SÍ / Claude autoriza push SÍ`. **3ª aplicación consecutiva sin amend desde S12-G**, aterrizaje S12-H internalizado mantenido.
- `git push` → `7a13d48..d6880b1 main -> main`, limpio. SSH auth con passphrase `id_ed25519` sin fricción.

Formulación memorable de S12-I reforzada 3ª vez: **"la mejor triple confirmación es la que no tiene que cazar nada"** y su análogo derivado en la sesión: **"la mejor redacción bilingüe es la que no requiere amend"**.

Bloque 10 real ~15 min, dentro de estimación.

## Preparación de S12-L (primer apply del roadmap — milestone AWS brownfield)

Estado listo al cierre S12-K:

- **32/32 recursos gestionados** — módulo AWS brownfield técnicamente cerrado en import.
- **8 candidatos ADR abiertos** con priorización pendiente.
- `terraform plan` = `No changes` en cierre.
- Todos los recursos principales importados: red + seguridad + VPC Endpoint + IAM + S3 + DB Subnet Group + EC2 + RDS.

### Scope pendiente para S12-L

S12-L es el **primer `terraform apply` del roadmap** — milestone emocional + técnico. Objetivo pactado: consolidar Camino B (refactor post-import) con disciplina S12-C máxima.

Actividades esperadas:

1. **Priorización explícita de los 8 candidatos ADR**: cuáles se resuelven en primer apply, cuáles se difieren a S12-M+. Ejercicio de decisiones arquitectónicas.
2. **Redacción de ADRs formales** en `decisions/` en formato Michael Nygard para los priorizados.
3. **Ejecución de primer `terraform apply`** con protocolo pactado explícito (predicción escrita + verificación conjunta pre-apply + triple confirmación conjunta pre-apply + verificación post-apply).
4. **Consolidación empírica** de las 3 reglas candidatas (#S12K-1, #S12K-2, #S12K-3) + matización S12-K de #S12H-8 + candidata "vamos despacio" (aterrizaje 3ª aplicación) + candidata autonarrativa saboteadora (aterrizaje 4ª aplicación).

### Estimación honesta S12-L

2-3h honestas dependiendo de cuántos ADR se prioricen y cuál sea el scope de refactor del primer apply. Sesión con **densidad emocional alta** — primer apply del roadmap, cierre del módulo AWS brownfield en modo activo. Anotable como sesión distinguible en el diario.

### Verificaciones empíricas esperadas en S12-L

- Aplicación de la matización S12-K de #S12H-8 en referencias RDS futuras si aplican.
- Verificación empírica de la regla candidata #S12K-3 sobre atributos anómalos post-import (`skip_final_snapshot`, `apply_immediately`) en el `apply` real.
- Consolidación empírica del mapping Cat 1/2/3/4 en refactor de ADRs.
- Aplicación 4ª candidata "vamos despacio" (posible promoción a locked).
- Aplicación 5ª candidata autonarrativa saboteadora (posible promoción a locked ⭐⭐⭐).

### Reglas operativas OBLIGATORIAS para S12-L

- **Al arrancar**: Bloque 0 completo. Esperado: serial 35, `state list = 32`, RDS estado dependiente del reloj (verificar y parar si `available`), IP casa (verificar si aplica rotación).
- **Bitácora S12-K releída** antes del warmup — regla operativa 48-72h, aplicable incluso a hueco de <12h por seguridad operativa.
- **Warmup MÁXIMO 2 preguntas**, 5 min techo (locked ⭐⭐⭐ #S12H-1). Preguntas candidatas: (a) predicción sobre orden de resolución de ADRs con racional priorización, (b) recordatorio de la matización S12-K de #S12H-8 aplicada a la RDS si toca referenciarla.
- **Aterrizaje explícito #S12I-2**: recordar plan de bloques al inicio, antes del warmup (4ª aplicación consecutiva).
- **Aterrizaje explícito #S12I-1**: al final de cada edición HCL en refactor, decir "pásamelo ANTES de `validate`". Recuperación de disciplina consolidada de S12-K (5 aplicaciones limpias post-corrección).
- **Aterrizaje explícito #S12J-1**: al escribir HCL de refactor, releer específicamente el output del recurso concreto, no anidados.
- **Aterrizaje explícito ⭐⭐⭐ #24**: predicción escrita antes de cada `plan` y antes de cada `apply` sin excepciones. Recuperación de disciplina consolidada de S12-K.
- Ciclo pactado obligatorio con predicción escrita en cada paso.
- Verificación conjunta línea por línea del HCL antes de validate (locked ⭐⭐⭐ #S12F-10).
- Referencias HCL con matización S12-K ampliada de #S12H-8: si `id` es alias legible → atributo real; si `id` es identificador propio opaco → `.id`; si `id` es opaco distinto del alias legible → verificar con `terraform state show`.
- **Triple confirmación conjunta obligatoria antes de cada git push Y antes de cada `terraform apply`** (locked ⭐⭐⭐ #31, objetivo 9ª aplicación consecutiva en git + 1ª aplicación de la extensión a `apply`).
- Aplicación del mapping Cat 1/2/3/4 en cada decisión de refactor.

### Cosas que NO hacer en S12-L

- NO ejecutar `terraform apply` sin predicción escrita explícita, verificación conjunta pre-apply, y triple confirmación conjunta pre-apply.
- NO resolver los 8 ADRs en el mismo apply — priorizar 2-4 máximo por sesión.
- NO tocar deuda no priorizada (dejar diferida a S12-M+ con racional explícito).
- NO importar recursos nuevos en S12-L (import brownfield técnicamente cerrado).
- NO usar `terraform destroy` bajo ninguna circunstancia.
- NO forzar cierre de todos los ADRs si el alumno da señal "vamos despacio" o "me explota la cabeza" — recortar y diferir sin defensa del plan.
- NO saltarse la verificación empírica antes de proponer decisiones sobre atributos con historial de refutaciones (aplicación de la regla derivada personal del profesor).
- NO usar analogías a Kubernetes o tecnologías del roadmap futuro.
- NO dumpear traducciones completas si aparecen (candidata #S12H-6).
- NO usar vocabulario técnico nuevo sin introducción explícita (regla S12-D — aplicable especialmente al profesor tras 2 correcciones en S12-K: "opaco" + "Optional Force").
- NO hacer git commit --amend sobre commits ya pusheados a origin/main.

## Meta-observaciones de método

1. **Densidad pedagógica muy alta en sesión larga**: ~2h 45min con 2 imports densos + 3 reglas candidatas nuevas emergentes + 1 matización ampliada de regla locked + 1 candidato ADR nuevo + 4 correcciones a autonarrativa saboteadora + 3 saltos de método iniciales corregidos + 3 refutaciones consecutivas del profesor sobre `skip_final_snapshot` con corrección de método explícita. Densidad justificable por (a) introducción del mapping Cat 1/2/3/4 como vocabulario nuevo transversal, (b) drift real analizado con Camino A ortodoxo tras iteraciones fallidas, (c) matización S12-K de #S12H-8 emergente empíricamente por refutación del profesor.

2. **9 aplicaciones ⭐⭐⭐ #S12E-1 al profesor** — récord de la sesión, empujado por: (a) predicciones sobre defaults del provider (4 refutaciones acumuladas en la sesión), (b) predicción `id = identifier` para RDS refutada empíricamente por descubrimiento del `id = "db-CMRXOHT44O5AJNYKRNPJZMNZ5A"`, (c) 3 predicciones consecutivas sobre comportamiento de `skip_final_snapshot` refutadas empíricamente, (d) predicción de serial `36` refutada empíricamente (serial real 35). Confirma que **la predicción teórica del profesor sobre schema del provider AWS + state es sistemáticamente débil**, con lo cual la regla se refuerza más y más con cada sesión larga. Formulación reforzada: **"empírico siempre gana a predicción teórica, incluso cuando la predicción viene del profesor y es defendible a priori"**.

3. **Introducción del mapping Cat 1/2/3/4 en caliente como aterrizaje pedagógico mayor**: emergió por antipatrón "todos son optional, así que lo declaro" del alumno en Grupo 2 EC2. Regla mnemónica *"¿aparece 'default' en el texto de Argument Reference?"* aterrizada al 3er intento y aplicada consistentemente en 20+ decisiones declarar/omitir del HCL de EC2 + RDS. **Regla candidata #S12K-1** formulada. Falta 1-2 aplicaciones más en apply S12-L para promoción a locked.

4. **2 correcciones de método por vocabulario del profesor sin introducción explícita**: "opaco" al arranque del Bloque 3 (detectada por señal preventiva del alumno *"vamos despacio, paso a paso"*), "Optional Force" al arranque del Bloque 4 (detectada por *"cuando dices Optional Force, no veo que ponga eso"*). Regla S12-D violada 2 veces por el profesor. Regla candidata derivada consolidada: **cuando emerja vocabulario técnico nuevo por mi lado en caliente, introducirlo explícitamente antes de usarlo, sin abreviaturas ni contracciones**.

5. **3 refutaciones consecutivas del profesor sobre `skip_final_snapshot`**: (i) framing inicial en Grupo 5 como *"solo importa en destroy, no en import"* → refutado por drift real, (ii) análisis del drift 1 como *"realidad AWS tiene `true` implícito, declarar `= false` alinea con default"* → refutado por drift persistente post-declaración, (iii) análisis del drift 2 como *"eliminar del HCL → schema absorbe realidad `true`"* → refutado por drift persistente post-eliminación. Regla derivada personal del profesor consolidada: **cuando acumule 2+ predicciones incorrectas sobre el mismo objeto empírico, PARAR y verificar antes de proponer más**. Aplicación de S12-C al lado del profesor. Regla candidata **#S12K-3** formulada: *"algunos atributos del schema `aws_db_instance` tienen comportamiento anómalo post-import — requieren declaración explícita en HCL para reconciliar drift residual, no basta con omisión ni con verificación del state"*. 1 aplicación en la sesión. Verificable en apply S12-L.

6. **Matización S12-K ampliada de ⭐⭐⭐ #S12H-8**: descubierta empíricamente por refutación de la predicción sobre RDS. Nuevo caso — recursos donde el `id` de state es distinto tanto del alias legible como del identificador propio opaco esperado. `aws_db_instance` con `id = "db-<hex>"` opaco distinto del `identifier` legible (`task-manager-db`). Anotable para futuras referencias HCL a `aws_db_instance` en apply S12-L. Aplicable la regla: **verificar empíricamente con `terraform state show` antes de decidir entre `.id`, `.identifier`, `.arn`**.

7. **Regla candidata #S12K-2** consolidada empíricamente 2 aplicaciones en la sesión: *"la Argument Reference documenta la intención declarada del provider, no el schema real 100%. El `plan` pre-import expone el schema real. Cuando divergen, gana el `plan`"*. Aplicación 1ª: `instance_metadata_tags` en EC2 (docs Cat 2, empírico Cat 3). Aplicación 2ª: 4 defaults descubiertos en `plan` pre-import RDS no anticipados por docs. Falta 1-2 aplicaciones más para promoción a locked.

8. **Racional (a) documentar controles compliance en HCL aplicado consistentemente a 4 atributos en RDS**: `publicly_accessible = false` + `deletion_protection = true` + `ca_cert_identifier = "rds-ca-rsa2048-g1"`. Patrón coherente identificable en revisión de PR banca. Anotable como aterrizaje del meta-patrón "coherencia compliance del HCL" — un revisor senior en banca reconoce el patrón en un solo golpe de vista.

9. **Regla candidata "vamos despacio" 3ª aplicación consecutiva en el roadmap**: S12-J (recorte de scope pactado en caliente) + hoy en Bloque 3 (señal por "opaco") + hoy en Bloque 4 (recalibración del ask del profesor tras corrección de método por lista condensada). Aterrizaje consolidado. Falta 1 aplicación más para promoción a locked ⭐⭐⭐.

10. **Regla candidata autonarrativa saboteadora 4 aplicaciones consecutivas en la sesión**: (i) "vamos despacio... me resulta un poco lioso" en Bloque 3, (ii) "no sé distinguir esto ahora mismo" en Tanda 1 Grupo 1 RDS (autonarrativa contradicha por el propio racional articulado), (iii) "con mi ignorancia total" en Tanda 1 Grupo 1 RDS (refutada con evidencia empírica de la sesión), (iv) predicción correcta del alumno *"va a seguir saliendo 1 to add"* refutando análisis teórico del profesor sobre `skip_final_snapshot`. Aterrizaje operativo crítico: **la autonarrativa saboteadora aparece más frecuentemente cuando el alumno acaba de aplicar bien el método sin verse aplicándolo bien**. Regla candidata refinada. Especialmente relevante para narrativa entrevista banca. Falta 1 aplicación más para promoción a locked ⭐⭐⭐.

11. **Predicción correcta del alumno superando el análisis teórico del profesor**: caso positivo sobresaliente. Alumno articuló *"va a seguir saliendo 1 to add"* ANTES del `plan` post-eliminación de `skip_final_snapshot`, cuando el profesor había predicho `No changes`. Su intuición empírica (basada en las 2 iteraciones previas) anticipó lo que el análisis teórico del profesor NO supo predecir. Anotable como **evidencia empírica dura de aterrizaje del método científico por parte del alumno**. Aplicable directamente a narrativa entrevista: cuando entrevistador emite predicción y candidato tiene evidencia empírica contraria, articularla sin softening es exactamente lo que un senior espera del método científico.

12. **3 saltos de método iniciales en Bloque 3 + recuperación de disciplina consolidada en Bloque 4**: candidata #S12I-1 saltada 1 vez, ⭐⭐⭐ #24 saltada 1 vez, patrón "optimizar velocidad vs disciplina paso a paso" 1 vez detectable. **Recuperación tras corrección explícita**: 5 aplicaciones limpias consecutivas de #S12I-1 en Bloque 4, 2 aplicaciones limpias consecutivas de ⭐⭐⭐ #24 en Bloque 4, 4 aplicaciones limpias consecutivas de #S12I-2 (aterrizaje). Consolidación de la disciplina en la segunda mitad de la sesión. Anotable: los saltos aparecen más al final del Bloque 3 (~1h de sesión) que al arranque — patrón "fatiga cognitiva empuja al atajo".

13. **Sesión larga (~2h 45min vs estimación 1h 30min - 2h)** con desviación honesta declarada por el alumno explícitamente (*"no te preocupes por el tiempo puedo estar más tiempo"*) — permite mantener disciplina de método sin recorte. Aplicación 5ª ⭐⭐⭐ #S12E-1 al profesor: la lectura del profesor de "sobrecarga por saltos de método" era interpretativa; el autoconocimiento operativo del alumno es la fuente de verdad. **Aprendizaje operativo**: estimación futura para sesiones tipo "2 imports densos con drift real analizado y vocabulario nuevo introducido en caliente" puede ser 2h 30min - 3h honestas. La estimación previa de 1h 30min - 2h del prompt de continuación S12-K asumía descubrimiento previo hecho (correcto), pero no anticipó el drift real ni la introducción del mapping.

14. **Ausencia de fallos empíricos catastróficos en el ciclo pactado**: 0 amend, 0 destroy accidental, 0 drift oculto no analizado, 0 recursos con configuración incorrecta commiteada. Los múltiples errores detectados (2 mecánicos en Grupo 1 EC2 + 2 antipatrones declarar/omitir + 2 clasificaciones incorrectas Cat 2 vs 3 + drift `skip_final_snapshot` con 3 iteraciones + 3 refutaciones del profesor + 1 predicción incorrecta del serial) fueron interceptados por el ciclo pactado (verificación conjunta línea por línea + ⭐⭐⭐ #S12F-10 + regla S12-C + verificación empírica antes de decisión). Confirmación 2ª sesión consecutiva de que **el ciclo pactado protege frente a errores del alumno bajo sobrecarga + errores del profesor bajo predicción teórica débil**. Aterrizaje: **el ciclo pactado no solo protege el estado real de AWS, protege también la calidad de la reflexión pedagógica de ambos participantes bajo densidad conceptual alta**.

15. **Bitácora escrita por el profesor en modo "notas borrador"** a petición del alumno tras el push. **Este documento requiere revisión y adaptación por el alumno antes de commitear**. No es producto final — es andamiaje para acelerar el paso "en frío" sin sacrificar la reflexión personal. Aplicable el mismo racional que S12-J.
