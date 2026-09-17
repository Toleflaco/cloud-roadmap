# ADR-024: Enable RDS Final Snapshot on Deletion

## Status

Accepted

## Context

The RDS instance `task-manager-db` was configured with `skip_final_snapshot = true`, imported as-is from AWS in the original brownfield import phase. With this value, a `terraform destroy` (or any equivalent deletion path) would delete the instance immediately with no backup — the data would be irrecoverable. This is unacceptable in a banking-oriented environment where a recovery point after destruction is required for compliance and business continuity, even in the case of intentional infrastructure teardown.

Note that `deletion_protection = true` is already set on this instance, which blocks accidental destruction outright. This ADR addresses a different, complementary layer: what happens to the data if a destroy does end up being executed intentionally.

## Decision

Set `skip_final_snapshot = false` and declare `final_snapshot_identifier = "task-manager-db-final-snapshot"` on `aws_db_instance.task_manager_db`. From now on, any successful destroy of this instance will first produce a named snapshot, preserving the data for restore.

## Consequences

Positive: guaranteed recovery point on deletion, satisfying banking-oriented data preservation and audit expectations; two independent protection layers now cover destruction — `deletion_protection` blocks the destroy itself, and `skip_final_snapshot = false` protects the data if a destroy does happen.

Empirical finding: this apply completed in 0 seconds, in stark contrast to the ~3 minutes required for the `storage_type` change in ADR-023. Both attributes are declared on the same resource and apply in-place, but their nature is different — `storage_type` triggers a real physical migration of the underlying storage on the DB instance, while `skip_final_snapshot` and `final_snapshot_identifier` only alter metadata governing future deletion behavior, with no immediate work on AWS's side. Takeaway: apply duration on RDS reflects the physical operation involved, not just the fact that the resource is being modified.
