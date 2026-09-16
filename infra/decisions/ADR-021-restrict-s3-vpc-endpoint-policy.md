# ADR-021: Restrict S3 VPC Endpoint Policy

## Status

Accepted

## Context

The default policy on the S3 VPC Endpoint allowed access from any principal, to any S3 resource, for any action (`Principal = "*"`, `Action = "*"`, `Resource = "*"`). This was detected empirically during a `terraform state show` review and represented an unnecessary attack surface for a banking-oriented infrastructure.

## Decision

Replace the default policy with a scoped policy restricting access to the `task-manager-ec2-role` principal only, limited to the specific S3 actions it actually needs (`s3:ListAllMyBuckets`, `s3:ListBucket`, `s3:PutObject`, `s3:GetObject`), scoped to the `toleflaco-task-manager-uploads-2026` bucket and its objects.

## Consequences

Positive: reduced attack surface at the VPC Endpoint level, adding a second layer of access control independent of the IAM role policy, aligned with compliance practices expected in banking environments.

Negative: any future change to the EC2 role's required S3 permissions (e.g. adding delete access) will require updating this endpoint policy as well as the IAM role policy — an additional dependency to track.

