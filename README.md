# Cloud Roadmap

Diario de aprendizaje autodirigido de infraestructura cloud sobre un stack Java backend, orientado a los filtros técnicos de banca, consultoras y grandes empresas en España. Documenta el proceso completo —decisiones, errores y aprendizajes— sesión a sesión.

Complementa mi otro repositorio, [`ai-engineer-roadmap-java`](https://github.com/Toleflaco/ai-engineer-roadmap-java), centrado en la especialización de AI Engineering. Este se centra en la parte de plataforma: cloud, contenedores, identidad y observabilidad.

## Objetivo

Pasar del perfil "Java + Spring Boot" al perfil "Java + Spring Boot + AWS + Kubernetes + OAuth2 + Observabilidad + IaC (Terraform)", que es el patrón dominante en las ofertas del mercado objetivo.

## Módulos

El roadmap se recorre en serie. Cada módulo usa como vehículo un proyecto real previo (`task-manager-api` monolito, `task-manager-microservices`).

| Módulo | Contenido | Sesiones | Estado |
|--------|-----------|----------|--------|
| 1 · AWS + Terraform | IAM, VPC, EC2/RDS, S3, ECS Fargate, Secrets Manager, CI/CD, IaC | 9 | 🔄 En curso |
| 2 · Kubernetes | Pods, Deployments, RBAC, Services, Ingress, HPA, Helm, EKS | 10 | ⏳ Pendiente |
| 3 · OAuth2 / OIDC | Keycloak, PKCE, resource server, federación AD (LDAP/SAML) | 10 | ⏳ Pendiente |
| 4 · Observabilidad | Micrometer, Prometheus, Grafana, Loki, Tempo, SLI/SLO | 10 | ⏳ Pendiente |

## Estado actual

Módulo 1 (AWS), Sesión 1 completada: cuenta configurada con MFA, usuario IAM con permisos por grupo, presupuesto de control de gasto y AWS CLI operativo en WSL. Modelo de responsabilidad compartida asentado.

## Estructura del repositorio

```
cloud-roadmap/
├── README.md         Esta portada
├── .gitignore        Exclusión de secretos, state de Terraform y credenciales
├── bitacora/         Diario de progreso, un fichero por sesión
├── decisions/        ADRs (formato Michael Nygard), a partir del Módulo 1
└── infra/            Código de infraestructura (Terraform, manifests K8s, Helm)
```

Las carpetas `decisions/` e `infra/` se crean cuando existan sus primeros contenidos.

## Convenciones

- Todo el contenido en español. Fechas en formato ISO 8601.
- Bitácoras: un fichero por sesión, patrón `SesionNN-MODULO-Diario.md`.
- ADRs: formato Michael Nygard, numerados por módulo con prefijo (`A1..A4`, `K1..K6`, `O1..O4`, `Ob1..Ob3`).
- Disciplina de coste: destruir recursos no free-tier al terminar cada sesión. Objetivo de factura mensual < 5 €.

## Nota de seguridad

Este repositorio no contiene credenciales, access keys, ficheros de estado de Terraform ni ningún secreto. Toda la gestión de secretos se hace fuera del control de versiones.
