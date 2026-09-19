# Cloud Roadmap

Self-directed learning journal for cloud infrastructure on a Java backend stack, targeted at technical screening filters used by banks, consulting firms, and large enterprises in Spain. Documents the complete process—decisions, mistakes, and learnings—session by session.

Complements my other repository, [`ai-engineer-roadmap-java`](https://github.com/Toleflaco/ai-engineer-roadmap-java), focused on AI Engineering specialization. This one focuses on the platform layer: cloud, containers, identity, and observability.

## Objective

Move from the "Java + Spring Boot" profile to "Java + Spring Boot + AWS + Kubernetes + OAuth2 + Observability + IaC (Terraform)"—the dominant pattern in target job market offerings.

## Quick Start: How to Navigate

1. **Current progress:** Check [Estado actual](#estado-actual) for the latest completed module
2. **Roadmap structure:** See the [Modules](#módulos) table to understand what comes next
3. **Session logs:** Open `bitacora/` to read detailed learnings from each session (newest first)
4. **Decisions:** Open `decisions/` to understand architectural trade-offs (ADRs, Michael Nygard format)
5. **Infrastructure code:** Open `infra/` to see Terraform, Kubernetes manifests, and Helm charts

## Tech Stack by Module

| Module | Technologies | Focus |
|--------|---------------|-------|
| **1 · AWS + Terraform** | IAM, VPC, EC2, RDS, S3, ECS Fargate, Secrets Manager, CI/CD | Infrastructure as Code, cost discipline |
| **2 · Kubernetes** | Pods, Deployments, StatefulSets, RBAC, Services, Ingress, HPA, Helm, EKS | Container orchestration, scaling |
| **3 · OAuth2 / OIDC** | Keycloak, PKCE, resource servers, AD federation (LDAP/SAML) | Identity, authorization, enterprise SSO |
| **4 · Observability** | Micrometer, Prometheus, Grafana, Loki, Tempo, SLI/SLO | Metrics, logs, traces, alerting |

## Modules

Each module is self-contained and uses a real project as its vehicle: `task-manager-api` (monolith) or `task-manager-microservices` (distributed).

| Module | Content | Sessions | Status | Link |
|--------|---------|----------|--------|------|
| 1 · AWS + Terraform | IAM, VPC, EC2/RDS, S3, ECS Fargate, Secrets Manager, CI/CD, IaC | 9 | 🔄 In progress | [bitacora/](bitacora/) |
| 2 · Kubernetes | Pods, Deployments, RBAC, Services, Ingress, HPA, Helm, EKS | 10 | ⏳ Planned | — |
| 3 · OAuth2 / OIDC | Keycloak, PKCE, resource server, AD federation (LDAP/SAML) | 10 | ⏳ Planned | — |
| 4 · Observability | Micrometer, Prometheus, Grafana, Loki, Tempo, SLI/SLO | 10 | ⏳ Planned | — |

## Current Progress

**Module 1 (AWS), Session 1 completed:**
- AWS account configured with MFA
- IAM user with group-based permissions
- Spend budget alert configured
- AWS CLI operational in WSL
- Shared responsibility model understood

**Next:** Deploy `task-manager-api` monolith to EC2 + RDS (Session 2+)

## Repository Structure

```
cloud-roadmap/
├── README.md              This file
├── .gitignore             Excludes secrets, Terraform state, credentials
├── bitacora/              Session journal (one file per session)
│   └── Sesion01-AWS-Intro.md
├── decisions/             ADRs (Michael Nygard format)
│   ├── A001-IAM-Strategy.md
│   ├── A002-Cost-Discipline.md
│   └── ...
└── infra/                 Infrastructure code
    ├── terraform/         Terraform IaC (modules, vars, state)
    │   └── task-manager-api/
    ├── k8s/               Kubernetes manifests
    └── helm/              Helm charts
```

Folders `decisions/` and `infra/` are created as content appears.

## Conventions

- **Language:** English for code and comments; Spanish for personal notes and session logs
- **Dates:** ISO 8601 format (YYYY-MM-DD)
- **Session logs:** One file per session, pattern `SesionNN-MODULE-Date.md` (newest first in index)
- **ADRs:** Michael Nygard format, numbered by module prefix (`A001..A010`, `K001..K010`, `O001..O010`, `Ob001..Ob010`)
- **Cost discipline:** Destroy all non-free-tier resources at end of each session. Monthly bill target: < 5 USD
- **Secrets:** Zero secrets in this repo. All AWS credentials, API keys, and state files live outside version control.

## Security Notes

This repository contains:
- ❌ No AWS credentials, access keys, or secret tokens
- ❌ No Terraform state files (`.tfstate`)
- ❌ No API keys or passwords
- ✅ Infrastructure patterns and learnings (shareable, reusable, no PII)

All secrets and credentials are managed via environment variables, `.env` files (excluded by `.gitignore`), or AWS Secrets Manager.

## Related Repositories

- **[task-manager-api](https://github.com/Toleflaco/task-manager-api)** — Spring Boot monolith (deployment target for this roadmap)
- **[task-manager-microservices](https://github.com/Toleflaco/task-manager-microservices)** — Distributed system (deployment target for Kubernetes module)
- **[ai-engineer-roadmap-java](https://github.com/Toleflaco/ai-engineer-roadmap-java)** — AI/LLM specialization (parallel track)

## Reading Guide for Recruiters

If you're evaluating this as evidence of cloud infrastructure knowledge:

1. **Start here:** Read one session from `bitacora/` (pick Session 03 or later, not Session 01 which is admin setup)
2. **Check decisions:** Skim `decisions/A001-A003.md` to see reasoning process
3. **Verify implementation:** Browse `infra/terraform/` to see actual code
4. **Assess depth:** Look for cost trade-offs, security decisions, scaling patterns

This is a **learning journal in progress**, not a production deployment guide. The value is in the reasoning, not the perfection.

---

*Last updated: 2026-09-20*
