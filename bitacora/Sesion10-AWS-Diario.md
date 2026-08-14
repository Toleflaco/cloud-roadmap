# Sesión 10 — Terraform empírico primer contacto (parte 2 de la Sesión 5 oficial del roadmap)

**Fechas:** 12 agosto 2026 (tramo 1) + 13 agosto 2026 (tramo 2)
**Duración total:** ~2h45 repartidas en dos tramos:
- Tramo 1: 12 ago, 20:00 – 20:45 (~45 min, vespertino corto, cerrado por saturación)
- Tramo 2: 13 ago, 17:35 – 19:35 (~2h, ventana ancha, cierre completo)
**Estado:** Completada. Primera sesión con manos en teclado sobre Terraform. Ciclo empírico `init → plan → apply → destroy` recorrido entero, con validación empírica de idempotencia y drift. Dos commits pusheados a `origin/main`. Recursos AWS al cierre: idénticos al inicio (bucket creado y destruido dentro de la sesión).

## Objetivo pedagógico

Recorrer el ciclo empírico completo de Terraform sobre un recurso trivial para asentar el andamiaje mental construido en Sesión 9. Cubrir nueve bloques en secuencia:

1. Instalación de Terraform en WSL vía repositorio oficial APT de HashiCorp.
2. Concepto de GPG keys aplicado a la verificación de paquetes.
3. Estructura del directorio Terraform (`versions.tf` vs `main.tf`) y decisión de ubicación.
4. Semantic Versioning + operador `~>` de constraint (concepto derivado como necesidad).
5. Anatomía de un `resource` block + cadena de precedencia de credenciales AWS.
6. `terraform init` empírico — descarga de provider, generación del lockfile.
7. `terraform plan` empírico — lectura del diff, símbolos, `known after apply`.
8. `terraform apply` empírico — confirmación interactiva, generación del state file.
9. Idempotencia + drift + `terraform destroy` — cierre del ciclo con validación empírica.

Sesión de "manos en teclado" pactada como continuación directa del bootstrap conceptual de Sesión 9, respetando "todo concepto se explica antes de usarse".

## Bloque 1 — Instalación de Terraform en WSL

### Decisión de método

Tres opciones consideradas:

1. **Snap** (`sudo snap install terraform --classic`): un comando pero historial de fricción con WSL2 y versiones desactualizadas.
2. **Binario manual** en `/usr/local/bin`: máximo control pero actualizaciones eternas a mano.
3. **Repositorio APT oficial de HashiCorp**: cuatro comandos de setup, `apt upgrade` gestiona actualizaciones futuras, estándar profesional.

**Elegida: Opción 3**. Cinco minutos de setup ahora frente a meses de "por qué mi snap está tres versiones atrás".

### Comandos ejecutados

1. `sudo apt update && sudo apt install -y gnupg software-properties-common curl` — dependencias.
2. `wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg` — GPG key al keyring del sistema.
3. `echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list` — repo firmado a sources.list.d.
4. `sudo apt update && sudo apt install terraform` — instalación.

**Resultado**: `terraform version` devuelve `Terraform v1.15.8` sobre `linux_amd64`.

5. `terraform -install-autocomplete` — autocompletado bash configurado en `~/.bashrc`.

### Plugin Terraform+HCL en IntelliJ

Instalado desde la sugerencia del propio IDE al abrir `versions.tf` por primera vez. Aporta coloreado sintáctico, autocompletado de atributos por provider, detección de errores en editor y format automático.

## Bloque 2 — GPG keys aplicadas a APT

Concepto solicitado explícitamente durante la sesión ("no sé qué son las GPG keys").

### Definición operativa

GPG (GNU Privacy Guard) es un sistema de criptografía asimétrica. Cada entidad tiene un par de claves: una privada (secreta) y una pública (compartible). Lo que la privada firma, cualquiera con la pública puede verificar.

### Aplicación al APT del paso 2

HashiCorp firma cada paquete `.deb` que publica con su clave privada. Al meter la clave pública en `/usr/share/keyrings/hashicorp-archive-keyring.gpg`, APT gana dos capacidades cada vez que descarga un paquete:

1. **Autenticidad**: verifica que el paquete viene realmente de HashiCorp.
2. **Integridad**: verifica que el paquete no ha sido alterado durante el tránsito.

Sin la GPG key, APT rechazaría instalar (`WARNING: The following packages cannot be authenticated!`) a menos que se le pase `--allow-unauthenticated`, práctica desaconsejada en cualquier entorno serio.

### Conexión con conceptos ya conocidos

El mismo mecanismo criptográfico está detrás de HTTPS/TLS, claves SSH para GitHub, y commits firmados de Git. **Analogía del sello de lacre medieval**: prueba autoría y detecta si alguien abrió la carta por el camino.

**Frase para entrevista ⭐⭐⭐**: *"La cadena de confianza de paquetes de HashiCorp se basa en GPG asimétrico: la clave pública instalada en el keyring del sistema verifica autenticidad e integridad de cada paquete descargado desde el repositorio APT. Es el mismo mecanismo criptográfico que HTTPS, SSH y commits firmados de Git."*

## Bloque 3 — Estructura del directorio y separación de responsabilidades

### Decisión de ubicación

Directorio `infra/` dentro del repo `cloud-roadmap`, no repo separado. Justificación: los ficheros HCL viven cerca de las bitácoras (`bitacora/`) y ADRs (`decisions/`) que los documentan.

### Separación de responsabilidades

Dos ficheros pactados para el primer ejercicio, con separación por tipo de contenido:

- **`versions.tf`**: metadatos del proyecto Terraform (versión mínima del CLI, providers requeridos con sus constraints). No crea nada. Análogo directo al `pom.xml` de Maven.
- **`main.tf`**: configuración del provider (cómo se conecta a AWS) + declaración de los recursos que deben existir. Aquí sí hay intención de crear cosas.

### `versions.tf` redactado

```hcl
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.58"
    }
  }
}
```

Con comentarios de intención al principio (regla operativa derivada de Sesión 9: comentar por qué, no qué).

## Bloque 4 — Semantic Versioning y operador `~>`

### Concepto derivado por necesidad

Al llegar a `version = "~> 6.58"` apareció la duda: "¿qué es MAJOR y MINOR?". Vocabulario nuevo introducido sin bandera previa — corrección explícita durante la sesión, se pauta la explicación completa.

### SemVer (Semantic Versioning)

Convención `MAJOR.MINOR.PATCH`:

- **PATCH**: bugfixes sin cambios de comportamiento. Ejemplo: `6.58.0 → 6.58.1`. Actualizar es seguro.
- **MINOR**: funcionalidad nueva **manteniendo compatibilidad hacia atrás**. Ejemplo: `6.57.0 → 6.58.0`. Actualizar es razonablemente seguro.
- **MAJOR**: **breaking changes**. Ejemplo: `5.x → 6.0`. Actualizar requiere leer guía de migración.

### Operadores de constraint en Terraform

Tres explicados:

- **`=`** (igualdad exacta): rígido, ni un patch más.
- **`>=`**: acepta la versión indicada y todo lo posterior (peligroso: incluye majors futuros).
- **`~>`** (pessimistic constraint, "twiddle-wakka"): comportamiento variable según cuántos números se dejen a la derecha.

### Regla mnemotécnica del `~>`

**Congela hasta el nivel del número dejado más a la derecha, deja subir lo que hay a partir de ahí**:

- `~> 6.58` (dos números) → congela MAJOR (6), deja subir MINOR y PATCH. Acepta `6.58.0`, `6.75.3`, `6.99.0`. Rechaza `7.0.0`.
- `~> 6.58.0` (tres números) → congela MAJOR y MINOR, deja subir solo PATCH. Acepta `6.58.5`. Rechaza `6.59.0`.

### Verificación empírica posterior

En `terraform init` del tramo 2, con `~> 6.58` en el HCL, Terraform resolvió a la versión concreta **`6.59.0`**. Validación empírica directa del concepto: MINOR subió libremente dentro del MAJOR permitido.

**Predicciones socráticas exitosas a la primera**: "Si sale la 6.60.2, ¿la acepta?" → sí. "¿Y la 7.0.0?" → no. Concepto asentado antes de ejecutar el `init`.

## Bloque 5 — Anatomía del `resource` y credenciales AWS

### `main.tf` redactado

Provider AWS declarado con región + un único resource S3 bucket:

```hcl
provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "test" {
  bucket = "terraform-test-toleflaco-2026"

  tags = {
    Purpose   = "Terraform learning exercise S10"
    ManagedBy = "Terraform"
  }
}
```

### Anatomía del `resource` block

Sintaxis general: `resource "TIPO_DEL_RECURSO" "NOMBRE_LOCAL" { atributos... }`.

Distinción crítica que confunde al principio:

- **`TIPO_DEL_RECURSO`** (`aws_s3_bucket`): cadena fija definida por el provider. Catálogo cerrado.
- **`NOMBRE_LOCAL`** (`test`): identificador que el desarrollador se inventa. **Vive solo dentro de Terraform**, nunca llega a AWS. Sirve para referenciar el recurso desde otras partes del HCL.
- **Atributo `bucket`** (`terraform-test-toleflaco-2026`): el nombre real en AWS. Global, único en el mundo.

Un mismo tipo puede tener múltiples instancias con distintos nombres locales pero distintos valores en `bucket`.

### Cadena de precedencia de credenciales AWS

Cinco fuentes por orden de precedencia (idénticas al AWS CLI y al SDK v2):

1. Configuración explícita en el bloque `provider`.
2. Variables de entorno (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
3. Fichero `~/.aws/credentials` con perfil `[default]` u otro especificado.
4. Instance Profile vía IMDSv2 (solo si Terraform corre en una EC2).
5. ECS Task Role, IAM Identity Center / SSO, etc.

**Verificación empírica**: `echo $AWS_ACCESS_KEY_ID` devolvió vacío, y `ls -la ~/.aws/` confirmó existencia de `credentials` y `config`. Confirmado: **opción 3** activa en WSL. Terraform reutiliza el perfil `[default]` ya configurado.

**Frase para entrevista ⭐⭐⭐**: *"Terraform no reinventa la rueda de autenticación AWS. Reutiliza exactamente la misma cadena de precedencia de credenciales que el AWS CLI y el SDK v2. Por eso el HCL nunca debe contener credenciales — meterlas en el fichero es un antipatrón grave, tanto por versionado accidental como porque rompe la portabilidad del proyecto entre entornos."*

### Sobre `tags` en AWS

Los tags no son cosmética. Tres funciones operativas concretas:

1. **Facturación (Cost Allocation Tags)**: AWS puede desglosar la factura por tag. En banca es requisito de chargeback entre departamentos.
2. **Búsqueda y filtrado**: consola y CLI permiten filtrar por tag ("todos los recursos con `ManagedBy=Terraform`").
3. **Automatización y policies**: IAM policies pueden condicionar acciones por tag ("solo puedes borrar recursos con tag `Owner=<tu-usuario>`").

El tag `ManagedBy=Terraform` es señal defensiva para el yo futuro y compañeros: "no tocar por consola, se sobrescribe en el próximo apply".

### Precedencia de región (paralelismo con credenciales)

1. Región en el `resource` (raro).
2. Región en el `provider` (**caso actual: `eu-west-1`**).
3. Variable de entorno `AWS_REGION` / `AWS_DEFAULT_REGION`.
4. Región en `~/.aws/config`.

Explícito siempre gana sobre implícito.

## Bloque 6 — `terraform init` empírico

### Predicciones socráticas falladas (pedagógicamente valiosas)

Tres predicciones sobre qué haría `init`:

1. "Crearía el state file" → **FALSA**. El state solo aparece tras el primer `apply` exitoso.
2. "Conectaría a AWS" → **FALSA**. Solo conecta al Terraform Registry (`registry.terraform.io`).
3. "Crearía el bucket" → **FALSA**. `init` no toca AWS en absoluto.

Momento pedagógico clave: el nombre "init" sugiere "inicializar todo" pero en realidad hace mucho menos. Las tres correcciones asentaron la regla mental de tres ámbitos de comandos:

- **`init`**: local. Prepara el directorio. Cero contacto con AWS.
- **`plan`**: local + read-only en AWS.
- **`apply`**: local + write en AWS.

### Ejecución y verificación empírica

`terraform init` produjo:

- Carpeta `.terraform/` con el binario del provider (`terraform-provider-aws_v6.59.0_x5`, **879 MB**). Compilado Go que contiene código para los ~1500 tipos de recursos AWS.
- Fichero `.terraform.lock.hcl` (1482 bytes) con:
  - `version = "6.59.0"` — versión concreta resuelta del rango.
  - `constraints = "~> 6.58"` — el rango original preservado.
  - 16 hashes criptográficos (`h1:`, `zh:`) cubriendo múltiples plataformas.

### Hallazgo empírico validando conceptos previos

Línea del output: `Installed hashicorp/aws v6.59.0 (signed by HashiCorp)`. **El `signed by HashiCorp` es la GPG key en acción** — Terraform verificó la firma del binario del provider antes de instalarlo. Mismo mecanismo que el APT del Bloque 1.

Otra línea clave: `Include this file in your version control repository`. Terraform recomienda explícitamente commitear el `.terraform.lock.hcl`. Nota para el Bloque 9: contradice el `.gitignore` actual del repo.

### Analogía directa

`terraform init` ≈ `npm install`. Descarga dependencias declaradas, las cachea localmente, genera lockfile para reproducibilidad. La carpeta `.terraform/` es el equivalente a `node_modules/`.

## Bloque 7 — `terraform plan` empírico

### Predicciones socráticas exitosas (4 de 4)

1. Acción propuesta: crear el bucket ✓
2. Recursos tocados: 1 ✓
3. Línea final: `Plan: 1 to add, 0 to change, 0 to destroy` ✓
4. Si se quitara un tag del HCL tras un apply, Terraform lo modificaría para converger al HCL ✓ (razonamiento espontáneo del ciclo HCL vs state vs AWS)

### Símbolos del plan interiorizados

Cuatro símbolos que Terraform usa en cualquier plan:

- `+` crear
- `-` destruir
- `~` modificar (in-place, sin destruir)
- `-/+` destruir y recrear (atributos inmutables obligan a recreación)

### Concepto `known after apply`

Atributos que AWS asigna al crear el recurso y que Terraform no puede predecir antes: `arn`, `id`, `hosted_zone_id`, `bucket_domain_name`, `bucket_regional_domain_name`. Aparecen con literal `(known after apply)` en el plan y se materializan en el state tras el apply.

### La nota final `-out`

```
Note: You didn't use the -out option to save this plan, so Terraform can't
guarantee to take exactly these actions if you run "terraform apply" now.
```

Traducción operativa: **el plan mostrado es efímero**. Sin `-out=fichero`, un `apply` posterior recalcula el plan desde cero. En dev es aceptable; en producción el patrón profesional es:

```bash
terraform plan -out=tfplan
# (code review del plan)
terraform apply tfplan
```

Esto garantiza que lo aprobado se ejecuta exactamente. En banca/CI-CD es obligatorio.

## Bloque 8 — `terraform apply` empírico

### Corrección propia durante la sesión

Anuncié "`yes` son cinco letras" — error mío evidente (son tres: Y-E-S). Corrección directa en el turno siguiente sin softening. **La palabra exacta es `yes`, minúsculas, tres letras**. Diseño deliberado de UX: obliga a teclear tres letras conscientemente en lugar de darle a Enter por reflejo.

### Ejecución y observación empírica

`terraform apply` con `yes` produjo:

- `aws_s3_bucket.test: Creating...`
- Tras 2 segundos: `aws_s3_bucket.test: Creation complete after 2s [id=terraform-test-toleflaco-2026]`
- Final: `Apply complete! Resources: 1 added, 0 changed, 0 destroyed.`

En paralelo, verificación visual en consola AWS → S3 → Buckets: aparece `terraform-test-toleflaco-2026` en la lista, junto al `toleflaco-task-manager-uploads-2026` creado manualmente en Sesión 4. **AWS no distingue entre buckets creados por consola y por Terraform**; la reproducibilidad vive en Git, no en AWS.

### Anatomía del `terraform.tfstate` generado

Primer state file real leído entero. Campos clave:

- `"version": 4` — versión del formato del state (interno).
- `"terraform_version": "1.15.8"` — versión del CLI que lo generó.
- `"serial": 1` — contador de modificaciones, incrementa en cada cambio.
- `"lineage": "6cbf80e6-43a8-03ec-bc73-e6eabacaf0c3"` — UUID único del árbol de state, anti-confusión entre states divergentes.
- `"resources": [...]` — array con cada recurso gestionado.

En el recurso:

- `"mode": "managed"` — materializa la distinción `resource` vs `data source` de Sesión 9 (`data` produciría `"mode": "data"`).
- Atributos que antes eran `known after apply` ahora tienen valor real: `arn`, `id`, `hosted_zone_id`, `bucket_domain_name`.
- `"server_side_encryption_configuration"` con `"sse_algorithm": "AES256"` — **AWS aplicó cifrado por defecto sin que se le pidiera** (política S3 desde 2023). Terraform detectó ese valor y lo guardó en el state.

**Nota crítica sobre secrets**: en este bucket no hay secrets porque está vacío, pero el equivalente en una RDS contendría el password del master user en claro. Confirma la regla "state nunca a Git" como prevención de fuga real.

## Bloque 9 — Idempotencia, drift y `terraform destroy`

### Idempotencia validada empíricamente

Segundo `terraform apply` sin cambios en HCL produjo:

```
aws_s3_bucket.test: Refreshing state... [id=terraform-test-toleflaco-2026]

No changes. Your infrastructure matches the configuration.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

**Terraform no pidió confirmación con `yes`**. Regla mental derivada: prompt solo cuando hay cambios. Plan vacío → ejecuta directamente. Diseño coherente: sería absurdo preguntar "¿confirmas que no quieres hacer nada?".

**Frase para entrevista ⭐⭐⭐**: *"Terraform apply es idempotente por diseño porque compara siempre el estado deseado (HCL) contra el estado actual (state + refresh a la realidad AWS), y solo actúa sobre el delta. Ejecutar apply N veces con el mismo HCL produce el mismo estado final que ejecutarlo una vez. Esta propiedad es la base del apply automático en pipelines CI/CD: si el código no cambia la infra, el pipeline no toca AWS."*

### Drift test

Introducción de drift manual: añadida tag `AddedManually=TrueDrift` desde la consola AWS al bucket gestionado por Terraform.

Predicciones socráticas exitosas (4 de 4):

1. Acción propuesta: modificar el recurso borrando la tag ✓
2. Símbolo: `~` ✓
3. Línea final: `Plan: 0 to add, 1 to change, 0 to destroy` ✓
4. Terraform borra la tag manual porque HCL manda ✓

Output del plan mostró la sintaxis `"AddedManually" = "TrueDrift" -> null` — nomenclatura `valor_actual -> valor_futuro` que aparece en todos los diffs de Terraform. También líneas `# (14 unchanged attributes hidden)` — Terraform oculta lo no cambiante para legibilidad.

`terraform apply` posterior con `yes` produjo `Modifying...` (verbo distinto a `Creating...`, otro detalle para leer plans rápido). Verificación en consola AWS: tag `AddedManually` desaparecida.

**Frase para entrevista ⭐⭐⭐**: *"Terraform detecta drift comparando el state con la realidad AWS en el refresh de cada plan, y siempre resuelve el drift a favor del HCL. La infraestructura converge al estado declarado, no al estado observado. Consecuencia cultural en equipos: adoptar Terraform obliga a renunciar a cambios manuales por consola en recursos gestionados por IaC, o a instaurar disciplina de 'primero HCL, luego PR, luego apply, luego se ve el cambio'. En banca esto se formaliza en change management."*

### `terraform destroy`

Predicciones socráticas exitosas (4 de 4):

1. Símbolo: `-` ✓
2. Línea final: `Plan: 0 to add, 0 to change, 1 to destroy` ✓
3. Pide confirmación porque hay cambios ✓
4. Tras destroy, `terraform.tfstate` queda vacío de recursos pero conserva metadatos ✓

Detalle observado: el prompt de destroy tiene lenguaje reforzado respecto al de apply:

- Apply: `Do you want to perform these actions? / Only 'yes' will be accepted to approve.`
- Destroy: `Do you really want to destroy all resources? / There is no undo. Only 'yes' will be accepted to confirm.`

Deliberado por HashiCorp — mismo mecanismo, distinta alarma. UX defensiva.

### Estado post-destroy

`terraform.tfstate` tras el destroy:

```json
{
  "version": 4,
  "terraform_version": "1.15.8",
  "serial": 3,
  "lineage": "6cbf80e6-43a8-03ec-bc73-e6eabacaf0c3",
  "outputs": {},
  "resources": [],
  "check_results": null
}
```

Observaciones:

- **`"serial": 3`**: el contador subió 1 (apply inicial) → 2 (apply del drift fix) → 3 (destroy). Es el mecanismo que usa el remote backend para detectar conflictos de concurrencia.
- **`"resources": []`**: array vacío. **El state no se borra**; conserva estructura. Coherente con el modelo: Terraform sigue vivo en el directorio, simplemente no gestiona nada ahora.
- **`terraform.tfstate.backup`** apareció (3191 bytes): copia del state previo al destroy, red de seguridad para recuperación.

**Frase para entrevista ⭐⭐⭐**: *"El state file post-destroy no se borra; queda con la estructura preservada (version, lineage, serial) pero con el array de resources vacío. Terraform sigue vivo en el directorio, simplemente no gestiona nada. Un apply posterior con el mismo HCL recrearía los recursos idénticamente. Además, terraform.tfstate.backup queda como copia del state previo al destroy — mecanismo local de recuperación ante errores humanos."*

## Bloque 10 — Bug del `.gitignore` y commits

### Bug descubierto por la regla operativa de Sesión 8

`git status` obligatorio entre `git add` y `git commit` (regla locked en Sesión 8) cazó el problema. Después de `git add infra/`, el status mostró **solo dos ficheros stageados** (`main.tf`, `versions.tf`) faltando `.terraform.lock.hcl`.

Diagnóstico vía `cat .gitignore | grep -i terraform`:

```
# TERRAFORM — el state guarda secretos en claro; nunca al repo
# Directorios de trabajo de Terraform
.terraform/
.terraform.lock.hcl
```

**Línea explícita ignorando `.terraform.lock.hcl`**. Origen: plantilla `.gitignore` copiada al crear el repo `cloud-roadmap`, basada en convenciones anteriores a Terraform 0.14 (año 2020), cuando el lockfile no existía. Post-0.14, HashiCorp doctrina oficial: **el lockfile SÍ se commitea**, para garantizar resolución reproducible de versiones entre máquinas y CI.

### Fix aplicado

Línea `.terraform.lock.hcl` eliminada del `.gitignore`. `.terraform/` mantenida (correcta: ignora el directorio con el binario de 879 MB).

Sin la regla de Sesión 8, este bug habría pasado desapercibido y el compañero clonando el repo mañana habría resuelto `~> 6.58` a cualquier versión disponible en ese momento (posiblemente `6.60.0`), rompiendo reproducibilidad sin ruido.

### Estrategia de commits

Dos commits separados en lugar de uno solo (escuela A — historia más limpia, cada commit hace una cosa):

**Commit 1** — Fix del `.gitignore` + lockfile ahora incluido:
```
fix(gitignore): stop ignoring .terraform.lock.hcl

Terraform's provider lockfile must be committed to guarantee reproducible
provider version resolution across machines and CI runs. The original
.gitignore was based on a pre-0.14 template when the lockfile did not exist.

HashiCorp explicitly recommends committing this file since Terraform 0.14.
```
Hash: `32775ad`. Cambios: 2 files changed, 26 insertions(+), 1 deletion(-).

**Commit 2** — Primer HCL empírico:
```
feat(infra): add first Terraform config with AWS provider and test S3 bucket

First hands-on Terraform exercise (S10). Declares the AWS provider pinned
to ~> 6.58 in versions.tf, and a trivial S3 bucket resource in main.tf to
exercise the full init/plan/apply/destroy lifecycle end-to-end.

Deliberately minimal: no variables, no modules, no remote backend, no
integration with existing infra. Region eu-west-1 to match the rest of
the task-manager AWS resources.
```
Hash: `330c2e1`. Cambios: 2 files changed, 28 insertions(+).

Ambos commits bilingües (EN + `---` + ES) siguiendo la convención Conventional Commits pactada.

Push exitoso: `f647ccf..330c2e1 main -> main`. Local sincronizado con `origin/main`.

## Frases ⭐⭐⭐ consolidadas hoy

1. **Sobre GPG keys y APT**: *"La cadena de confianza de paquetes de HashiCorp se basa en GPG asimétrico: la clave pública instalada en el keyring verifica autenticidad e integridad de cada paquete descargado. Es el mismo mecanismo criptográfico que HTTPS, SSH y commits firmados de Git."*

2. **Sobre credenciales AWS en Terraform**: *"Terraform no reinventa la rueda de autenticación AWS — reutiliza exactamente la misma cadena de precedencia que el AWS CLI y el SDK v2. Por eso el HCL nunca debe contener credenciales: es un antipatrón grave, tanto por versionado accidental como porque rompe la portabilidad entre entornos."*

3. **Sobre idempotencia**: *"Terraform apply es idempotente por diseño porque compara siempre el estado deseado (HCL) contra el estado actual (state + refresh a la realidad AWS), y solo actúa sobre el delta. Es la base del apply automático en pipelines CI/CD: si el código no cambia la infra, el pipeline no toca AWS."*

4. **Sobre drift**: *"Terraform detecta drift comparando el state con la realidad AWS en el refresh de cada plan, y siempre resuelve el drift a favor del HCL. La infraestructura converge al estado declarado, no al estado observado. Consecuencia cultural: adoptar IaC obliga a renunciar a cambios manuales en recursos gestionados, o a formalizar change management."*

5. **Sobre el state post-destroy**: *"El state file post-destroy no se borra; conserva estructura (version, lineage, serial) con el array de resources vacío. Terraform sigue vivo en el directorio, simplemente no gestiona nada. Un apply posterior recrearía la infra idénticamente."*

6. **Sobre el lockfile de providers**: *"Desde Terraform 0.14 (2020), el fichero `.terraform.lock.hcl` es doctrina oficial de HashiCorp para commitear. Cumple la misma función que `package-lock.json` en npm o `Cargo.lock` en Rust: garantiza que todo el equipo y los pipelines de CI resuelven exactamente la misma versión concreta del provider, incluso con constraints amplios como `~> 6.58` en el HCL."*

## Estado de recursos AWS

**Al inicio de la sesión (12 ago 20:00)**: idéntico al cierre de Sesión 9. Todo parado, cero coste corriendo.

**Durante la sesión**: creado `terraform-test-toleflaco-2026` (S3, eu-west-1) mediante `terraform apply`. Modificado una vez para revertir drift (tag `AddedManually` borrada). Destruido mediante `terraform destroy`.

**Al cierre (13 ago 19:35)**: idéntico al inicio. Bucket destruido, verificado visualmente en consola. EC2 y RDS siguen parados. Coste incurrido por el bucket durante ~1h: prácticamente cero (S3 vacío no cobra almacenamiento, apenas céntimos de fracción por requests API).

## Cambios en el repo

Dos commits pusheados a `origin/main`:

1. `32775ad` — `fix(gitignore): stop ignoring .terraform.lock.hcl`
2. `330c2e1` — `feat(infra): add first Terraform config with AWS provider and test S3 bucket`

Ficheros nuevos en `infra/`:
- `versions.tf`
- `main.tf`
- `.terraform.lock.hcl`

Ficheros locales (no commiteados, cubiertos por `.gitignore`): `.terraform/` (879 MB con binario del provider), `terraform.tfstate` (post-destroy queda vacío), `terraform.tfstate.backup`.

## Lecciones operativas nuevas

1. **Sesiones vespertinas de 1h son demasiado cortas para bloques nuevos densos**. El tramo 1 (12 ago) se cerró a los 45 min por saturación y fatiga vespertina. **Decisión correcta parar**: forzar el ciclo apply con prisa habría corrompido pedagogía. Regla derivada: para material nuevo, presupuesto mínimo 90 min efectivos; sesiones más cortas se reservan para consolidación de material conocido.

2. **Dumpear código completo viola el método socrático**. En el tramo 1 pegué el `main.tf` entero para copiar en lugar de guiar bloque a bloque. Corrección aplicada en el tramo 2 (revisión bloque a bloque como Opción Y compensatoria). Regla: los conceptos se dan, la sintaxis se pacta, el usuario teclea.

3. **Vocabulario técnico nuevo requiere introducción explícita, no de pasada**. "MAJOR", "MINOR", "delta" aparecieron sin bandera previa y provocaron interrupciones legítimas del alumno ("¿qué es eso, lo hemos visto?"). Regla: cuando se introduce un término técnico por primera vez, dedicar un bloque explícito a explicarlo antes de asumirlo conocido.

4. **La regla de Sesión 8 (`git status` obligatorio entre `add` y `commit`) validada empíricamente con impacto real**. Cazó un bug del `.gitignore` que habría roto reproducibilidad silenciosamente. Regla operativa reforzada, no basta con recordarla — funciona porque se ejecuta cada vez, sin excepciones.

5. **Corrección directa de errores propios sin softening mantiene la confianza en el método**. En el tramo 2 anuncié "`yes` son cinco letras" (error evidente, son tres). Corrección inmediata en el turno siguiente sin excusas ni disculpas superfluas. El alumno cazó el error y la relación pedagógica se refuerza en lugar de dañarse.

6. **Verificar empíricamente en consola AWS mientras Terraform trabaja hace click el concepto**. Abrir S3 → Buckets en paralelo al `terraform apply` permite ver aparecer el recurso en tiempo real. Regla: en sesiones empíricas de IaC, tener siempre la consola AWS abierta en otra pestaña como validador visual.

7. **Predicciones socráticas falladas son pedagógicamente más valiosas que las acertadas cuando descubren mitos conceptuales**. Las tres predicciones falladas del `init` (state, AWS, bucket) desmontaron el mito de "init hace mucho" y asentaron la separación de ámbitos `init` (local) / `plan` (read AWS) / `apply` (write AWS). Regla: cuando un comando tiene nombre que engaña, hacer predecir antes de ejecutar para exponer el modelo mental erróneo.

## Deuda arrastrada actualizada

### Deuda nueva (Sesión 10)

- **Bitácora Sesión 10 pendiente** (este fichero) — cerrada al escribirla.
- **Data sources sin ejemplo empírico todavía** (heredada de S9): no se hizo en S10 por decisión de simplicidad máxima. Programada para S12 (adopción brownfield con `terraform import` de la VPC existente).
- **`terraform import` sin ejecutar todavía** (heredada de S9): programada para S12.
- **Remote backend S3 + DynamoDB pendiente**: contenido principal de S11.
- **Concepto de `tags_all` y `default_tags` a nivel provider** anticipado pero no ejercitado: se verá en S12 o en el módulo de módulos Terraform.

### Deuda arrastrada de sesiones anteriores (siguen abiertas)

- **README de portfolio pendiente actualizar** con S3 integration + presigned URLs + VPC Endpoint. Acumulada desde S6-S8.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2**. Elastic IP fija o Atlas VPC Peering.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location**. Deuda REST menor.
- **`postgresql-client` en EC2 en v16 vs server v18**.
- **Billing access para IAM user `tole`** — activar desde root.
- **Verificación empírica del tráfico por VPC Endpoint** — postpuesta al módulo Observabilidad.

### Deudas cerradas hoy

- **Ciclo empírico `init/plan/apply/destroy`** — completo, validado con idempotencia + drift + destroy. Modelo mental de Terraform pasa de conceptual (S9) a operativo (S10).
- **Bug del `.gitignore` bloqueando `.terraform.lock.hcl`** — arreglado, lockfile ahora commiteable.
- **Vocabulario SemVer + operador `~>`** — asentado empíricamente (visto `~> 6.58` resolverse a `6.59.0` en el propio `init`).
- **Cadena de precedencia de credenciales AWS en Terraform** — verificada por observación directa (`echo $AWS_ACCESS_KEY_ID` vacío + `~/.aws/credentials` presente = opción 3).

## Para retomar en Sesión 11

**Warmup (~10 min)**: predicciones cortas sin abrir el diario:
1. Cuando ejecutas `terraform destroy`, ¿qué le pasa al `terraform.tfstate`?
2. Diferencia entre `~> 6.58` y `~> 6.58.0` en constraints.
3. Si añades una tag manualmente a un recurso gestionado por Terraform y ejecutas `plan`, ¿qué símbolo verás y qué acción propondrá?
4. ¿Por qué el `.terraform.lock.hcl` se commitea pero el `terraform.tfstate` no?
5. Terraform CLI vs Terraform Provider: ¿cuál se descarga en `init` y cuál se instala vía APT?

**Sesión 11 — Remote state en S3 + DynamoDB (parte 3 de la Sesión 5 oficial)**:

1. Concepto: por qué remote backend (colaboración en equipo, locking, versioning, encryption).
2. Creación del bucket S3 dedicado al state (nombre único, versioning + encryption + block public access).
3. Creación de la tabla DynamoDB para locking (partition key `LockID`, on-demand billing).
4. Configuración del bloque `backend "s3"` en `versions.tf`.
5. `terraform init -migrate-state` — migración del state local al remoto, primer contacto con este flujo.
6. Verificación empírica: `terraform.tfstate` local desaparece, aparece en S3.
7. Prueba de locking: intentar dos apply en paralelo desde dos terminales, ver el bloqueo.
8. Commit + bitácora `Sesion11-AWS-Diario.md`.

**Alternativa vespertina ligera**: repaso guiado de los conceptos de Sesión 10 sin material nuevo, solo consolidación con preguntas socráticas sobre el ciclo empírico.

## Meta-observaciones de método

- **Sesión partida en dos días — decisión correcta parar en el tramo 1**. Con 45 min residuales y fatiga vespertina, forzar el ciclo empírico habría corrompido pedagogía. Retomar en tramo 2 con warmup breve (3 preguntas, 3 aciertos) confirmó consolidación entre sesiones.
- **Ratio de predicciones acertadas altísimo en el tramo 2**: 4/4 en `plan`, 4/4 en drift test, 4/4 en `destroy`. El único bloque con predicciones falladas fue `init` (3/3 falladas), pedagógicamente muy valioso por desmontar el mito de "init hace mucho".
- **Dos preguntas espontáneas del alumno resultaron catalizadoras**: "¿qué son las GPG keys?" (abrió un bloque completo sobre criptografía asimétrica aplicada) y "¿qué era el delta?" (forzó explicación de vocabulario técnico dado por sentado). Confirma regla de S9: las preguntas espontáneas mejoran la explicación planificada.
- **Corrección propia sin softening del "yes son cinco letras" (son tres)**: aplicada la regla de método sin dilación. Efecto observado: refuerza confianza en el método, no la daña.
- **Estimación de contexto al cierre**: ~70% del chat consumido tras 2h de trabajo empírico + escritura de bitácora. Generación de prompt de continuación recomendada al arrancar Sesión 11.
- **Deuda nueva hoy: 3 conceptuales (data sources, import, remote backend) + 1 pedagógica (concepto `tags_all` mencionado sin ejercitar)**. Todas programadas para sesiones concretas próximas. Ratio deuda/entregado sano.
