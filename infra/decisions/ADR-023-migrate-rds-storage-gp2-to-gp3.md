# ADR-023: Migrate RDS Storage Type from gp2 to gp3

## Status

Accepted

## Context

The RDS instance `task-manager-db` was using `gp2` (General Purpose SSD) storage, implicitly defaulted by AWS since `storage_type` was never declared in Terraform. `gp3` offers the same baseline performance (3000 IOPS, 125 MiB/s throughput) at lower cost, with IOPS and throughput configurable independently of allocated storage — a better fit as a banking-oriented default.

## Decision

Declare `storage_type = "gp3"` explicitly on `aws_db_instance.task_manager_db`, without declaring `iops` or `storage_throughput`, letting AWS apply its gp3 defaults (3000 IOPS / 125 MiB/s) automatically. Apply the change immediately via `apply_immediately = true`, rather than waiting for the next maintenance window, since this is a learning environment with no production traffic to protect.

## Consequences

Positive: lower storage cost with equivalent baseline performance; explicit declaration of storage type removes reliance on an implicit AWS default.

Negative / important finding: a first `terraform apply` with `apply_immediately` left at its default (`false`) completed successfully but did not apply the storage change — AWS only queued it in `PendingModifiedValues`, pending the next maintenance window. `terraform plan` continued to show the change as pending afterward, which is expected AWS behavior, not drift. A second `apply` with `apply_immediately = true` applied the change for real (~3 minutes), confirmed empirically via `terraform plan` (`No changes`) and `aws rds describe-db-instances` (`StorageType: gp3`). Takeaway: on RDS, `Apply complete!` does not by itself guarantee a change is live — with `apply_immediately = false`, verify against `PendingModifiedValues` before treating the change as done. In a production environment with real traffic, waiting for the maintenance window would be the safer default instead of forcing immediate application.
