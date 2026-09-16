# ADR-015: Enable versioning on toleflaco-task-manager-uploads-2026 S3 bucket

## Status

Accepted

## Context

During the brownfield import of the S3 bucket `toleflaco-task-manager-uploads-2026` in S12-I, we verified that the bucket had versioning disabled. Because the bucket stores user-uploaded data, the absence of versioning represents a compliance and auditability gap for environments subject to GDPR, PCI DSS, or similar controls. This situation surfaced as a technical debt item during the import review, requiring an explicit decision on how to handle versioning for this bucket going forward.

## Decision

We enable versioning on the `toleflaco-task-manager-uploads-2026` S3 bucket by managing a dedicated `aws_s3_bucket_versioning` resource with status set to "Enabled". This configuration becomes part of the Terraform-managed scope for the bucket. The change follows the same split-resource pattern already used for encryption and public-access-block settings, maintaining architectural consistency across bucket concerns.

## Consequences

Enabling versioning brings the bucket into alignment with GDPR and PCI DSS expectations for user-uploaded data, improving auditability and compliance posture. It also provides stronger recovery guarantees, since overwritten or deleted objects can be restored, protecting against human error and malicious deletion in the event of credential compromise. The decision maintains architectural consistency by following the same split-resource pattern used for encryption and public-access-block, making the bucket's configuration easier for future maintainers to understand. On the downside, each object version consumes billable S3 storage, which is negligible today but may require lifecycle policies if usage grows. Versioning cannot be reverted to Disabled once enabled, only suspended, making this a practically irreversible choice. The client application remains unaffected, as S3's PutObject and GetObject semantics do not change.
