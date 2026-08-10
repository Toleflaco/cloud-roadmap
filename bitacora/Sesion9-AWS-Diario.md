# Sesión 9 — Terraform Bootstrap conceptual (parte 1 de la Sesión 5 oficial del roadmap)

**Fecha:** 10 agosto 2026
**Duración:** ~2h (bloque único de mañana, 13:15 – 15:15)
**Estado:** Completada. Sesión 100% conceptual, cero código escrito, cero infra tocada. Objetivo pedagógico cumplido: mapa mental completo de Terraform (por qué existe, arquitectura, state file, workflow) preparado para escritura empírica de HCL en Sesión 10.

## Objetivo pedagógico

Construir el andamiaje mental para poder escribir HCL con comprensión, no por imitación. Cubrir cinco bloques conceptuales en secuencia:

1. El "por qué" de IaC — el problema que resuelve.
2. Terraform vs alternativas — CloudFormation, CDK, Pulumi, y qué NO es IaC (Ansible, Kubernetes, Docker).
3. Arquitectura de Terraform — provider, resource, data source, module + declarativo vs imperativo.
4. El state file — el bloque más importante de la sesión.
5. Workflow completo — init, plan, apply, destroy, import.

Sesión de "pizarra pura" antes de tocar cualquier código, siguiendo el marco pactado en Sesión 8 ("todo concepto se explica antes de usarse").

## Bloque 1 — El "por qué" de IaC

### Diagnóstico inicial vía tres preguntas socráticas

Antes de cualquier explicación, tres preguntas sobre la infraestructura actual del proyecto (creada por consola en las Sesiones 1-8):

1. Si tuvieras que replicar toda tu infra AWS en la región us-east-1 mañana, ¿cómo lo harías?
2. Si un compañero nuevo entra al equipo, ¿cómo le enseñas exactamente qué infraestructura tienes desplegada?
3. Si borras por accidente la VPC entera, ¿cuánto tardarías en recrearla idénticamente?

**Respuestas dadas**:
1. Sin IaC, "todo a mano" recreando cada wizard.
2. "Menú por menú enseñándole las configuraciones".
3. "En un porcentaje alto sí, tendré que tenerlo apuntado o sabérmelo de memoria. Se tardaría un rato".

**Diagnóstico**: las tres respuestas describen la enfermedad, no la solución. Estas son exactamente las tres carencias que IaC ataca.

### Los cuatro pilares del "por qué IaC"

De las tres respuestas se extraen los cuatro problemas concretos:

1. **Reproducibilidad**: infra idéntica en múltiples regiones/entornos, sin errores humanos al replicar.
2. **Documentación viva**: el código ES la documentación autoritativa. Nunca desactualizada porque cambios en código = cambios en realidad.
3. **Auditabilidad**: versionado Git + code review + rollback. **En banca/fintech vale oro** por compliance (PCI DSS, SOC 2, ISO 27001).
4. **Automatización**: pipelines que crean/destruyen infra sin intervención manual.

### Trade-offs honestos

Reconocidos y aceptados durante la sesión (respuesta socrática "matar moscas a cañonazos" identificó el más importante):

1. **Curva de aprendizaje inicial real**: HCL nuevo, concepto de state sutil, mensajes de error crípticos al principio. Estimación honesta: 20-30 horas de práctica hasta nivel productivo.
2. **Convivencia con infra preexistente**: `terraform import` recurso por recurso, y drift potencial mientras la adopción no está completa.
3. **Operaciones no declarativas**: restaurar backups, rotar claves, migraciones de datos. Terraform no orquesta procesos operacionales; sigue haciendo falta scripts, runbooks o herramientas complementarias (Ansible).

**Frase para entrevista ⭐⭐⭐**: *"IaC no es siempre la respuesta correcta. Para infraestructuras muy pequeñas, muy estables, o cuando el equipo no domina la herramienta, la sobrecarga puede superar los beneficios. Regla razonable: si vas a mantener la infra más de 3 meses, si vas a replicarla en algún momento, o si hay más de una persona tocándola — IaC gana."*

### Priorización personal

Auditabilidad identificada como pilar diferenciador para el mercado objetivo (banca, fintech, consultoras grandes). La documentación viva como la más difícil de "sentir" hasta que el proyecto crece a cientos de líneas de HCL. Regla operativa derivada: **añadir comentarios de intención (no de qué hace) en el HCL desde el primer fichero**.

## Bloque 2 — Terraform vs alternativas

### El panorama de herramientas IaC

- **Terraform (HashiCorp, 2014)**: multi-cloud, HCL, ecosistema más grande, ~85% de las ofertas de trabajo con IaC en España.
- **CloudFormation (AWS, 2011)**: AWS-only, YAML/JSON, gratuito, integrado nativo.
- **AWS CDK**: AWS-only, lenguajes de programación reales (TypeScript, Python, Java...), sintetiza CloudFormation por debajo.
- **Pulumi**: multi-cloud, lenguajes de programación reales. Ecosistema menor que Terraform.

### Herramientas que NO son IaC (aclaración importante durante la sesión)

Vocabulario ordenado tras confusión inicial sobre si "Ansible ≈ Kubernetes":

- **Ansible, Chef, Puppet**: **Configuration Management**. Configuran software dentro de máquinas que ya existen. Otra capa que IaC.
- **Kubernetes**: orquestador de contenedores. Vive dentro de infraestructura que ya existe. Dos capas por encima de IaC.
- **Docker**: runtime de contenedores. Empaqueta aplicaciones.

**Analogía de construcción interiorizada**: Terraform = arquitecto (qué edificios y parcelas existen). Ansible = interiorista (amueblar los edificios). Docker = mudanza empaquetada. Kubernetes = coordinador logístico de mudanzas.

### Elección de Terraform justificada

Cinco motivos ordenados:

1. **Multi-cloud**: mismo HCL, mismo workflow para AWS, Azure, GCP, GitHub, MongoDB Atlas, etc. Portabilidad de conocimiento y proceso.
2. **Comunidad y ecosistema**: Terraform Registry con decenas de miles de módulos publicados.
3. **Herramientas maduras alrededor**: Terragrunt, tflint, terraform-docs, Checkov, tfsec, Atlantis, Terraform Cloud. **Deuda formativa anotada**: aprender estas cuando la herramienta base esté dominada, no ahora.
4. **Mercado laboral**: penetración del ~85% en ofertas con IaC en España vs ~25% de CloudFormation.
5. **CloudFormation tiene rarezas históricas**: errores crípticos, rollback automático problemático, tiempo de respuesta lento.

### Precisión sobre multi-cloud

Corrección de malentendido: multi-cloud NO significa "los mismos ficheros funcionan en Azure y AWS". Los tipos de recursos son específicos de cada provider (`aws_s3_bucket` vs `azurerm_storage_account`). **La portabilidad es de lenguaje HCL y workflow**, no de código directamente reutilizable. Aun así, la portabilidad de conocimiento tiene enorme valor: no vuelves a empezar de cero, reaprovechas todo el modelo mental.

**Frase para entrevista ⭐⭐⭐**: *"Terraform es multi-cloud en el sentido de que usas el mismo lenguaje HCL y el mismo workflow para todos los providers, pero los recursos son específicos de cada uno. La portabilidad real es de conocimiento y proceso, no de código directamente reutilizable. Pero ese conocimiento reaprovechado vale mucho: no empiezas de cero al cambiar de cloud."*

## Bloque 3 — Arquitectura de Terraform

### Los cuatro conceptos clave

1. **Provider**: traductor entre Terraform y una API externa concreta. Análogo a dependencia Maven en un `pom.xml`. Cada provider define sus propios tipos de recursos.

2. **Resource**: objeto de infraestructura gestionado por Terraform (crea, modifica, destruye). La unidad básica de trabajo. Sintaxis: `resource "aws_s3_bucket" "uploads" { ... }` — tipo definido por provider, nombre local elegido por el usuario.

3. **Data source**: consulta solo-lectura. Sintaxis: `data "aws_vpc" "existing" { ... }`. Terraform pregunta a AWS por información sobre un recurso que ya existe, sin ser dueño de él. **Duda pendiente para consolidar en Sesión 10 con ejemplos empíricos**.

4. **Module**: grupo de resources empaquetados juntos y reutilizables. Análogo a una clase o función reutilizable. **Concepto avanzado, no aparece hasta Sesión 15 oficial**. Sesiones 10-14 se escriben con resources puros para interiorizar la unidad básica.

### Cambio de paradigma: declarativo vs imperativo

El punto conceptual más importante del bloque, y de la sesión entera:

- **Imperativo (Java, Python)**: describes cómo llegar al resultado, paso a paso. El orden importa. Verbos explícitos ("create", "new", "delete"). Tienes que gestionar edge cases.
- **Declarativo (HCL, SQL, HTML)**: describes el resultado deseado. El orden textual no importa. Sin verbos — solo estado. Los edge cases los gestiona la herramienta.

Momento clave de comprensión (pregunta espontánea del alumno): *"¿en qué instrucción se le dice a Terraform que cree el recurso?"*. Respuesta: **en ninguna. HCL declara estado, Terraform deduce la acción (crear/modificar/no tocar/destruir) según lo que ya haya en el mundo real**.

**Frase para entrevista ⭐⭐⭐**: *"En código imperativo especificas el verbo y la herramienta lo ejecuta. En Terraform declaras el sustantivo (lo que debe existir) y Terraform deduce el verbo apropiado comparando estado deseado con estado real. La misma declaración de recurso puede resultar en crear, modificar, no tocar o destruir según el contexto."*

### Grafo de dependencias automático

Terraform infiere el orden de creación analizando referencias entre resources. Si el resource A referencia `resource.B.id`, B se crea antes que A. El desarrollador nunca declara orden explícitamente. Recursos independientes se crean en paralelo (hasta 10 por defecto).

**Predicción socrática exitosa a la primera** por parte del alumno: *"Terraform sabe cuál crear antes, no hace falta que le indiquemos el orden"*. Modelo mental interiorizado.

## Bloque 4 — El state file

### La necesidad del state file razonada socráticamente

Tres preguntas guía llevaron al descubrimiento del concepto:

1. Si haces `terraform apply` dos veces sin cambios en HCL, ¿qué debe hacer? → **Respuesta correcta**: nada (idempotencia).
2. Para saber que no debe crear duplicados, ¿cómo averigua qué existe ya? → Intento inicial "con un data source". **Falso positivo formativo**: los data sources sirven para consultas que TÚ programas explícitamente, no como mecanismo interno de memoria.
3. Con 50 recursos, ¿cuántas veces pregunta a AWS? → Intuición correcta: *"tiene que haber algo que le diga el estado"*. Llegada al concepto por eliminación.

### Definición y contenido

**State file (`terraform.tfstate`)**: fichero JSON con toda la memoria persistente de Terraform. Contiene cada recurso gestionado con todos sus atributos, incluidos los generados por AWS (IDs, ARNs, passwords, tokens).

### Las cuatro reglas críticas del state

1. **El state es la memoria de pertenencia de Terraform**. Recursos ausentes del state son invisibles para Terraform, aunque existan en AWS.

2. **El state contiene secretos en claro** (passwords RDS, credenciales generadas, valores sensibles). **Nunca se commitea a Git**. El `.gitignore` del proyecto ya tiene `*.tfstate*` protegido desde Sesión 8.

3. **Un solo apply a la vez**. Dos apply concurrentes corrompen el state. Solución: **state locking**.

4. **En equipo, state remoto**. Backend estándar en AWS = **S3 + DynamoDB**:
   - S3: almacena el state, versioning + encryption at rest + durabilidad 11 nueves.
   - DynamoDB: coordina locking distribuido, consistencia fuerte, coste céntimos/mes.

### Confusión clave resuelta: state ≠ fuente de verdad de configuración

Momento pedagógico importante — pregunta espontánea del alumno: *"pero dijiste que el state era la fuente de verdad, ¿en qué quedamos?"*. La aclaración final:

- **State**: fuente de verdad de **pertenencia** ("qué recursos son míos").
- **HCL**: fuente de verdad de **configuración** ("cómo deben ser").
- **AWS**: la **realidad**.

**HCL manda siempre**. Si HCL y state discrepan (state corrupto), Terraform actualiza el state para reflejar HCL. Si HCL y AWS discrepan (drift), Terraform modifica AWS para converger al HCL.

**Frase para entrevista ⭐⭐⭐**: *"En Terraform hay dos fuentes de verdad complementarias: el state file define el conjunto de recursos gestionados ('quiénes son míos'), y el HCL define la configuración deseada ('cómo deben ser'). El HCL siempre manda: si state y HCL discrepan, Terraform ajusta el state; si AWS y HCL discrepan, Terraform ajusta AWS. Los recursos existentes en AWS pero ausentes del state son invisibles para Terraform y requieren `terraform import` explícito."*

### Consecuencias operativas

- **Perder el state no destruye infra, pero deja a Terraform ciego**. Recuperación con `terraform import` recurso por recurso. Por eso remote backend con versioning es baseline.
- **Drift**: discrepancia entre state y realidad, generada por cambios fuera de Terraform. Terraform lo detecta en el siguiente plan y propone acciones para converger al HCL.
- **Cambio manual en consola AWS**: Terraform lo revierte en el siguiente apply, porque HCL manda. Castiga hotfixes fuera del pipeline.

## Bloque 5 — El workflow

### Los cinco comandos principales

1. **`terraform init`**: descarga providers y modules, inicializa backend. Se ejecuta una vez al empezar y cuando cambian dependencias estructurales. Análogo a `mvn dependency:resolve`.

2. **`terraform plan`**: calcula el diff entre HCL, state y AWS. NO aplica nada. **Barrera de seguridad obligatoria** antes de apply. Símbolos: `+` crear, `~` modificar, `-` destruir, `-/+` destruir y recrear.

3. **`terraform apply`**: ejecuta el plan. Pregunta confirmación interactiva por defecto (`-auto-approve` solo en pipelines). **Apply transaccionalmente parcial**: si falla el nº 15 de 20 recursos, los primeros 14 quedan creados y en el state. Se puede rearrancar tras arreglar la causa.

4. **`terraform destroy`**: destruye toda la infraestructura del state. Irreversible. **Protecciones en producción**: `lifecycle { prevent_destroy = true }` en críticos, backups explícitos previos, aislamiento estricto de credenciales entre entornos.

5. **`terraform import`**: adopta un recurso existente en el state sin modificarlo. **Requiere el bloque `resource` ya declarado en HCL previamente**. Flujo típico: escribir HCL aproximado → import → plan → ajustar HCL a la realidad → plan sin cambios. **Duda pendiente para consolidar en Sesión 10 con ejemplo empírico**.

### Aplicado al proyecto real (anticipando Sesión 12)

Adopción brownfield pendiente en Sesión 12: 1 VPC + 4 subnets + 1 IGW + 5 Route Tables + 1 EC2 + 1 RDS + 1 DB Subnet Group + 3 SGs + 1 S3 + IAM Role/Policy/Instance Profile + 1 VPC Endpoint. Estimación honesta: 3-5 sesiones para adoptar todo bien.

### Ciclo natural de desarrollo

```
1. Editas HCL
2. terraform plan       → previsualiza
3. Revisas el diff línea a línea
4. terraform apply      → ejecuta
5. Confirmas con 'yes'
6. Terraform actualiza state
7. Commit del HCL a Git (state nunca)
8. Push, PR, code review, merge
```

## Frases ⭐⭐⭐ consolidadas hoy

1. **Sobre trade-offs de IaC**: *"IaC no es siempre la respuesta correcta. Para infraestructuras muy pequeñas, muy estables, o cuando el equipo no domina la herramienta, la sobrecarga puede superar los beneficios."*

2. **Sobre auditabilidad para banca**: *"En banca y fintech, el valor principal de IaC no es solo técnico sino de compliance: cada cambio de infraestructura pasa por un pull request revisado, dejando trazabilidad automática que satisface requisitos PCI DSS, SOC 2 e ISO 27001 sin procesos manuales adicionales."*

3. **Sobre multi-cloud de Terraform**: *"Terraform es multi-cloud en el sentido de que usas el mismo lenguaje HCL y el mismo workflow para todos los providers, pero los recursos son específicos de cada uno. La portabilidad real es de conocimiento y proceso, no de código directamente reutilizable."*

4. **Sobre declarativo vs imperativo**: *"En código imperativo especificas el verbo y la herramienta lo ejecuta. En Terraform declaras el sustantivo (lo que debe existir) y Terraform deduce el verbo apropiado comparando estado deseado con estado real."*

5. **Sobre grafo de dependencias**: *"HCL es un lenguaje declarativo: describes el estado deseado, no el procedimiento. Terraform construye un grafo de dependencias analizando referencias entre recursos, y decide el orden de operaciones. El orden textual en el fichero es irrelevante."*

6. **Sobre resource vs data source**: *"En Terraform, `resource` es escritura y `data` es lectura. Un `resource` es un recurso gestionado por Terraform del que este es dueño; un `data source` es una consulta a la API del proveedor para referenciar recursos que existen pero cuya vida útil no depende de Terraform."*

7. **Sobre idempotencia**: *"Los sistemas declarativos son idempotentes por diseño: aplicar la misma configuración N veces produce el mismo resultado que aplicarla una sola vez. Esa propiedad hace fiable a Terraform frente a fallos de red o reintentos parciales — no hay riesgo de crear duplicados por reejecutar."*

8. **Sobre el state file y la memoria de pertenencia**: *"Terraform no descubre infraestructura existente automáticamente. Si un recurso existe en AWS pero no está en el state, Terraform lo ignora completamente — no lo gestiona, no lo detecta, no lo importa. La adopción requiere `terraform import` explícito."*

9. **Sobre las dos fuentes de verdad complementarias**: *"En Terraform, el state file define el conjunto de recursos gestionados y el HCL define la configuración deseada. El HCL siempre manda: si state y HCL discrepan, Terraform ajusta el state; si AWS y HCL discrepan, Terraform ajusta AWS."*

10. **Sobre seguridad del state**: *"El state file contiene secretos en claro incluidos en respuestas de las APIs de los providers, como passwords de RDS y credenciales generadas. Nunca debe versionarse en Git. La protección estándar es un patrón en `.gitignore` y un backend remoto con encriptación en reposo."*

11. **Sobre backend S3 + DynamoDB**: *"El backend estándar de Terraform en AWS es S3 + DynamoDB: S3 almacena el state con versioning y encryption, DynamoDB proporciona locking distribuido. Cuesta céntimos al mes y proporciona durabilidad 11 nueves, recuperación de versiones anteriores, y coordinación de equipo."*

12. **Sobre convergencia al HCL**: *"Ante drift entre HCL y realidad, Terraform siempre converge a lo declarado en el HCL. Si un desarrollador cambia infra directamente en la consola AWS sin actualizar el código, el próximo apply revertirá el cambio."*

13. **Sobre perder el state**: *"Perder el state file no destruye la infraestructura pero deja a Terraform ciego. Recuperar el control requiere `terraform import` de cada recurso uno por uno con sus IDs AWS específicos. Por eso el state remoto con versioning es baseline en cualquier proyecto real."*

14. **Sobre plan como red de seguridad**: *"El comando `terraform plan` calcula el diff sin aplicar cambios. Es la barrera de seguridad estándar antes de cualquier apply: en pipelines serios, el output del plan se sube al pull request como artefacto para code review, y solo se ejecuta apply tras aprobación."*

15. **Sobre destroy y protecciones en producción**: *"`terraform destroy` destruye toda la infraestructura del state. En producción se protege con `lifecycle { prevent_destroy = true }` en recursos críticos, backups explícitos previos, y aislamiento estricto de credenciales entre entornos."*

16. **Sobre import y adopción brownfield**: *"`terraform import` adopta un recurso existente en el state sin modificarlo. Requiere que el resource esté declarado en el HCL previamente. El flujo típico es: escribir HCL aproximado, importar, hacer plan, ajustar HCL a la realidad hasta que plan diga 'no changes'."*

## Estado de recursos AWS

**Sin cambios durante la sesión**. Ni EC2 ni RDS arrancados. Cero coste incurrido más allá del storage EBS parado permanente.

## Cambios en el repo

**Ninguno directo hoy** — sesión 100% conceptual, cero código escrito. Se pushea únicamente el diario `bitacora/Sesion9-AWS-Diario.md`.

## Lecciones operativas nuevas

1. **En bloques densos, el ejemplo técnico directo aterriza mejor que la analogía cotidiana**. Feedback del alumno: "con la analogía del profesor no me quedó claro, con el ejemplo del bucket sí". Regla aprendida: para conceptos abstractos, usar ejemplos técnicos con vocabulario conocido antes que analogías del mundo real. Las analogías funcionan como refuerzo, no como explicación primaria.

2. **La densidad conceptual sostenible es ~2h por sesión con pausas naturales de comprensión entre bloques**. La cadencia "pregunta socrática → intento del alumno → validación + refinamiento" evita saturación mejor que exposición larga de teoría seguida de preguntas.

3. **Momentos "buffff" del alumno son señal fiable de saturación en un tema concreto**. Aparecieron en el ecosistema Terraform (Terragrunt, tflint, etc.) y en la separación state/HCL. Regla operativa confirmada: parar y aclarar antes de avanzar, nunca empujar. "Saturación no consolida".

4. **Las preguntas espontáneas del alumno son mejores diagnósticos que las preguntas del profesor**. Dos ejemplos clave hoy: "¿en qué línea se le dice que cree?" (abrió el concepto declarativo con precisión) y "pero dijiste que el state era la fuente de verdad" (forzó la separación clean entre pertenencia y configuración). Regla anotada: **cuando el alumno pregunta espontáneamente, la respuesta consolida más que cualquier explicación planificada**.

5. **El vocabulario "sub-verdad" resulta más útil que "fuente de verdad única"**. En Terraform coexisten dos verdades complementarias (pertenencia en state, configuración en HCL) y forzar una explicación de "cuál es la fuente de verdad única" confunde en lugar de aclarar. Regla derivada: **cuando dos piezas del sistema tienen responsabilidades ortogonales, nombrarlas explícitamente en lugar de forzar una jerarquía única**.

6. **Los data sources y `terraform import` no se entienden bien en abstracto**. Ambos requieren ver el `plan` real para hacer click. Anotados como conceptos a consolidar empíricamente en Sesión 10.

## Deuda arrastrada actualizada

### Deuda nueva (Sesión 9)

- **Data sources**: comprensión conceptual clara, pero necesita ejemplo empírico en Sesión 10 para consolidar.
- **`terraform import`**: comprensión conceptual clara, pero el flujo real (write HCL aproximado → import → plan → adjust) necesita verse ejecutado para asentarse.
- **Ecosistema Terraform (Terragrunt, tflint, terraform-docs, Checkov, tfsec, Atlantis, Terraform Cloud)**: se aprenden cuando la herramienta base esté dominada. Meses vista.

### Deuda arrastrada de sesiones anteriores (siguen abiertas)

- **README de portfolio pendiente actualizar** con S3 integration + presigned URLs + VPC Endpoint. Acumulada desde S6-S8.
- **MongoDB Atlas IP allow list acoplada a IP pública de EC2**. Elastic IP fija o Atlas VPC Peering.
- **`POST /files` devuelve 200 con JSON pelado, no 201 Created + Location**. Deuda REST menor.
- **`postgresql-client` en EC2 en v16 vs server v18**.
- **Billing access para IAM user `tole`** — activar desde root.
- **Verificación empírica del tráfico por VPC Endpoint** — postpuesta al módulo Observabilidad.

### Deudas cerradas hoy

- **Marco mental completo de Terraform** — preparado para Sesión 10 empírica.

## Para retomar en Sesión 10

**Warmup (~10 min)**: revisar los conceptos clave de hoy con predicciones cortas del alumno. Sin abrir el diario. Los que fallen, se refuerzan brevemente.

**Sesión 10 (empírica, primera con manos en teclado)**:
1. Instalar Terraform en WSL (`snap install terraform --classic` o binario directo).
2. Crear directorio `infra/` dentro del repo `cloud-roadmap` (o repo nuevo `task-manager-infra` — decidir al arrancar).
3. Escribir el primer `main.tf` con provider AWS + un resource trivial (bucket S3 nuevo de prueba, `terraform-test-toleflaco-2026`).
4. `terraform init` empírico — inspección de `.terraform/` y de `.terraform.lock.hcl`.
5. `terraform plan` empírico — leer y entender el output.
6. `terraform apply` empírico — confirmación interactiva, ver el bucket creado.
7. Inspección del `terraform.tfstate` local — ver el JSON generado, entender qué guarda.
8. `terraform destroy` empírico — cerrar el ciclo.
9. Consolidación con ejemplo de data source (buscar información de la VPC existente).
10. Anticipación de `terraform import` (sin ejecutar todavía, ver en Sesión 11 o 12).

Duración estimada: 1h30-2h con predicciones socráticas y explicaciones intermedias.

**Alternativa vespertina ligera**: repaso guiado de los conceptos de Sesión 9 sin material nuevo, solo consolidación con preguntas socráticas.

## Meta-observaciones de método

- **Sesión 9 completó los cinco bloques planificados en 2h justas**, tiempo previsto acertado. Densidad alta pero sostenible con pausas de comprensión entre bloques.
- **Cuatro predicciones socráticas exitosas a la primera** por parte del alumno: idempotencia, grafo de dependencias, `data` vs `resource` para infra existente, y state como memoria persistente derivado por eliminación. Ratio de comprensión activa muy alto.
- **Dos preguntas espontáneas del alumno resultaron catalizadoras clave** para explicaciones más precisas: "¿en qué instrucción se crea?" (concepto declarativo) y "el state era la fuente de verdad, ¿en qué quedamos?" (separación state ≠ HCL). **Ambas mejoraron la explicación original**.
- **Regla operativa nueva confirmada**: no forzar analogías cotidianas cuando el alumno tiene vocabulario técnico previo. El ejemplo con Terraform aterrizó mejor que la analogía del profesor.
- **Deuda nueva hoy: 2 menores** (data sources + import a consolidar empíricamente). Ratio deuda/entregado sanísima.
- **Aviso proactivo de saturación de contexto emitido**: estimación de ~55-60% del chat consumido. Generación de prompt de continuación programada al cierre de esta sesión para arrancar Sesión 10 en chat nuevo.
