# ADR-022: Import Key Pair as Terraform-Managed Resource

## Status

Accepted

## Context

The EC2 key pair `task-manager-key` existed in AWS but was referenced in `aws_instance.task_manager_ec2` as a hardcoded string literal (`key_name = "task-manager-key"`), not as a Terraform-managed resource. This meant Terraform had no visibility into the key pair's existence or state — if it were modified or deleted outside Terraform, no drift would ever be detected.

## Decision

Create `aws_key_pair.task_manager_key` as a Terraform-managed resource and import the existing AWS key pair into it, then update `aws_instance.task_manager_ec2` to reference it via `aws_key_pair.task_manager_key.key_name` instead of the string literal.

## Consequences

Positive: the key pair is now fully visible to Terraform, drift-detectable, and referenced semantically rather than by a duplicated string.

Negative / important finding: declaring `public_key` on an imported key pair forced a `destroy and then create replacement`, not an in-place change as initially expected. This happens because the AWS API never returns the public key material for an existing key pair — `terraform import` populates the state with every other attribute but leaves `public_key` empty, so declaring it in HCL is seen as a new value that triggers recreation. The public key was recovered locally from the existing `.pem` private key file via `ssh-keygen -y`. Verified empirically post-apply that the running EC2 instance retained its association with the key pair name after the underlying AWS key pair object was recreated — no impact on the instance's configured access. This is a general limitation to expect whenever importing any pre-existing AWS key pair into Terraform.
