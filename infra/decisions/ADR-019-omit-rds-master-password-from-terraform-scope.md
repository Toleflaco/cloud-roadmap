# ADR-019: Omit RDS master password from Terraform scope

## Status

Accepted

## Context

During the brownfield import of the RDS instance in S12-K, we identified that the `password` attribute required an explicit handling strategy because Terraform does not retrieve or manage the actual database password during import. Several approaches were evaluated, including importing the real password into the Terraform state, referencing it through a sensitive variable, or omitting the attribute entirely. Each option carried different implications for security exposure, state management, and operational workflow. This forced a decision on how the project should treat the RDS master password going forward.

## Decision

We omit the `password` attribute entirely from the `aws_db_instance.task_manager_db` HCL definition and leave it unmanaged by Terraform. The RDS master password is set and updated manually through the AWS RDS console. Bitwarden serves as the authoritative source of truth for storing and retrieving this credential.

## Consequences

Omitting the RDS password from both HCL and Terraform state eliminates two major exposure surfaces, since the credential never appears in version-controlled configuration nor in the remote state stored in S3. Operationally, password rotation becomes fully decoupled from Terraform, allowing operators to update the credential directly in the AWS RDS console without coordinating infrastructure changes. However, the password becomes invisible from the Terraform configuration, requiring maintainers to rely on this ADR and Bitwarden to understand how it is managed. This introduces a critical dependency on Bitwarden as the single source of truth; losing access to the vault would require an AWS-level master password reset, which demands appropriate IAM permissions and causes brief downtime. Terraform never reports drift for this attribute, as it is not declared or tracked in the state.
