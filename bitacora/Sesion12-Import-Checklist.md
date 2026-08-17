# Checklist import brownfield task-manager

Recursos AWS creados manualmente en S1-S8 pendientes de importar al state de Terraform. Fichero de proceso — al cerrar el ciclo brownfield se archiva.

## S12-A (cerrado 17 ago 2026 mañana)

- [x] VPC `vpc-0d36eccf71cddeda7` → `aws_vpc.main`

## S12-B (objetivo hoy 17 ago 2026 tarde, ventana 17:00-19:00)

- [x] Subnet `subnet-00571f5c84fc414d3` (priv 1a) → `aws_subnet.private_1a`
- [x] Subnet `subnet-0af15e9e05f81098f` (priv 1b) → `aws_subnet.private_1b`
- [ ] Subnet `subnet-0af881e02d4a9322b` (pub 1a) → `aws_subnet.public_1a`
- [ ] Subnet `subnet-066074bd45c1a46f6` (pub 1b) → `aws_subnet.public_1b`
- [ ] IGW `igw-0ab423637224cab0c` → `aws_internet_gateway.main`

## Pendiente S12-C y posteriores

- Main Route Table (decisión pendiente: importar o ignorar)
- 3 Route Tables explícitas + routes + associations
- 2 Security Groups + reglas
- S3 bucket uploads + sub-recursos
- IAM Role + Instance Profile
- EC2, RDS, VPC Endpoint

## Reglas

- HCL primero, import después, plan para verificar (`No changes`).
- Un import → un plan. No acumular imports sin verificar.
- No importar bootstrap (bucket state, usuario IAM tole, MongoDB Atlas).
