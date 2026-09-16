# ADR-014: Exclude AWSRevokeOlderSessions inline policy from Terraform scope

## Status

Accepted

## Context

During the brownfield import of the IAM Role task-manager-ec2-role in S12-H, we discovered an unexpected inline policy named AWSRevokeOlderSessions attached to the role. This policy had not been created or managed by our infrastructure code. Further inspection showed that it was an auto-generated AWS policy produced by a prior console-triggered "Revoke sessions" action.

## Decision

We exclude the AWSRevokeOlderSessions inline policy from Terraform management and do not import it into the Terraform state. Terraform intentionally leaves this policy unmanaged, allowing AWS or human operators to regenerate or modify it without interference.

## Consequences

Excluding the AWSRevokeOlderSessions policy from Terraform keeps plans clean, as any future regeneration triggered by AWS or by a console-level "Revoke sessions" action produces no drift. It also avoids coupling ephemeral IAM session-revocation mechanics to Terraform's lifecycle, which is not designed to manage short-lived credential invalidation. However, this policy becomes invisible from the HCL perspective, requiring maintainers to consult AWS IAM directly and rely on this ADR to understand its presence. The policy never appears in `terraform state` or in `terraform plan`, remaining entirely outside Terraform's scope.
