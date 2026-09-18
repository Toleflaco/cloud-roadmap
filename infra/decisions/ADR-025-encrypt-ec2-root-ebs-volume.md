# ADR-025: Encrypt EC2 Root EBS Volume

## Status

Accepted

## Context

The EC2 instance is currently provisioned with an unencrypted root EBS volume because encryption was not enabled at creation time. Keeping the root volume unencrypted exposes data at rest to unnecessary risk in case of snapshot leakage or underlying storage compromise, and leaves the module with an inconsistent security posture: the S3 uploads bucket already has server-side encryption enabled (see ADR-015 for the split-resource pattern), while the EC2 root storage does not.

Enabling encryption on the root EBS volume requires replacing the volume. Terraform's schema marks the `encrypted` attribute of `root_block_device` as ForceNew, so the change is applied via destroy-and-create replacement of the `aws_instance` resource, rather than an in-place update.

## Decision

The root EBS volume of `aws_instance.task_manager_ec2` will be encrypted by explicitly setting `encrypted = true` inside its `root_block_device` block. No `kms_key_id` will be specified, so the volume will use the AWS-managed key for EBS (`aws/ebs`). Because Terraform marks the `encrypted` attribute as ForceNew, the instance will be replaced through a destroy-and-create operation. A preventive snapshot of the current root volume (`snap-05adfec989a3bb3ec`) was taken before applying the change, serving as a safety fallback rather than a planned restore source.

## Consequences

Encrypting the root EBS volume closes the encryption gap on EC2 storage and brings the instance in line with the already-encrypted S3 uploads bucket (ADR-015). The replacement of `aws_instance.task_manager_ec2` results in a new instance identifier and the loss of any data previously stored on the old root volume, although no user-managed state was present on the volume. The new instance may receive a different private IP address within the VPC. Public IP assignment depends on the subnet's `map_public_ip_on_launch` setting, which is currently `false`, so no public IP is assigned automatically. The AMI is pinned by ID in the HCL, so the new instance boots from the same image as the previous one. The preventive snapshot taken before the change remains in the account until manually deleted, introducing a small ongoing storage cost. Reverting the decision would require another destroy-and-create cycle, as disabling encryption on the root volume is also a ForceNew change.
