# ADR-013: Remove public route table association from S3 VPC Endpoint

## Status

Accepted

## Context

During the brownfield discovery and import of the S3 VPC Endpoint `vpce-0122ecf0ee7226fb9`, we found that it was associated with three route tables: `public`, `private_1a`, and `private_1b`. A Gateway-type VPC Endpoint for S3 is intended to provide internal routing to S3 for subnets that do not have access to the Internet Gateway. Because resources in the public subnet already reach S3 through the IGW, the association to the public route table is operationally meaningless. This surfaced as a configuration inconsistency that required an explicit decision on how the endpoint's route table associations should be managed.

## Decision

We remove the association between the S3 VPC Endpoint and the public route table, keeping only the associations to `private_1a` and `private_1b`. In Terraform, we delete the `aws_route_table.public.id` entry from the `route_table_ids` list of the `aws_vpc_endpoint.s3` resource. This leaves the endpoint scoped exclusively to the private subnets.

## Consequences

Removing the public route table association aligns the endpoint with its intended design, serving only subnets that lack Internet Gateway access. It also improves operational hygiene by eliminating a meaningless association that future maintainers might misinterpret as intentional. From a compliance and audit perspective, the configuration becomes cleaner and easier to justify, since the endpoint now reflects a coherent routing model. The main downside is that if future workloads in the public subnet ever require private-path access to S3, the association would need to be restored, though this scenario is unlikely. Runtime behavior for public-subnet resources remains unchanged, as they continue reaching S3 through the IGW without any operational impact.
