# ADR-026: Defer EC2 Interactive Access Implementation

## Status

Accepted

## Context

The `aws_instance.task_manager_ec2` resource is deployed in a public subnet, but the subnet has `map_public_ip_on_launch = false` and the instance configuration does not set `associate_public_ip_address = true`. As a result, the EC2 instance does not receive a public IP address at launch. The security group attached to the instance exposes ingress rules for SSH (22) and HTTP (8080) from the operator's home IP, yet without a public IP these rules are not reachable from the internet. The IAM role `task-manager-ec2-role` only includes the custom policy `task-manager-s3-uploads-rw` and does not have `AmazonSSMManagedInstanceCore` attached, which prevents the use of SSM Session Manager as an access path. The combined effect is that the EC2 instance is currently in a state where no interactive access method -- neither SSH nor SSM -- is available under the present design.

Several alternatives were evaluated: SSM via VPC endpoints (~21 USD/month), SSM via NAT Gateway (~32 USD/month), assigning a public IP for SSH access, or enabling SSM over a public IP. Each option introduces cost, architectural implications, or security considerations that are not justified at this stage of the roadmap.

## Decision

We accept the current state as documented technical debt. No interactive access mechanism will be implemented for the EC2 instance within this module of the roadmap. The decision regarding the eventual access method -- SSM via VPC endpoints, SSM via NAT Gateway, or SSH via public IP -- will be deferred to a future networking module, once the functional use of the EC2 instance warrants the operational cost. No changes will be made to the EC2 HCL, its security group, or the IAM role as part of this decision.

## Consequences

The EC2 instance remains a Terraform-managed resource without any interactive access path in the current infrastructure state. The security group rules `ec2_ssh_home` and `ec2_http_home` persist as preparatory elements for future use; keeping their home-IP CIDR up to date as part of ongoing operational maintenance continues to make sense for the moment when interactive access is eventually enabled. The present cost profile remains optimized, as no VPC endpoints, NAT Gateway, or public IP traffic are introduced. Reversing this decision does not require resource replacement: attaching the SSM policy to the IAM role or enabling a public IP on the EC2 instance will be sufficient once the chosen access method is defined.
