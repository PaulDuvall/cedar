// S3 Bucket Server-Side Encryption Enforcement Policy
// Implements AWS Config Rule: s3-bucket-server-side-encryption-enabled
// Supports both shift-left (CloudFormation template validation) and shift-right (runtime compliance)
// Last updated: June 2025

// =============================================================================
// SHIFT-LEFT: CloudFormation Template Validation Policies
// =============================================================================

// ALLOW: CloudFormation templates with properly encrypted S3 buckets
permit(
  principal,
  action == Action::"cloudformation:ValidateTemplate",
  resource
)
when {
  resource is CloudFormationTemplate &&
  ["development", "staging", "production"].contains(resource.environment)
};

// =============================================================================
// SHIFT-RIGHT: Runtime S3 Bucket Compliance Policies
// =============================================================================

// ALLOW: Config Rule evaluation for compliant S3 buckets
permit(
  principal == ConfigEvaluation::"s3-bucket-server-side-encryption-enabled",
  action == Action::"config:EvaluateCompliance",
  resource
)
when {
  resource is S3Resource &&
  // Condition 1: Default encryption is enabled with valid algorithm
  (resource.encryption_enabled == true &&
   resource has encryption_algorithm &&
   ["AES256", "aws:kms", "aws:kms:dsse"].contains(resource.encryption_algorithm)) ||
  
  // Condition 2: Bucket policy enforces encryption (alternative compliance method)
  (resource has bucket_policy_enforces_encryption &&
   resource.bucket_policy_enforces_encryption == true)
};

// DENY: Config Rule evaluation for non-compliant S3 buckets
forbid(
  principal == ConfigEvaluation::"s3-bucket-server-side-encryption-enabled",
  action == Action::"config:EvaluateCompliance",
  resource
)
when {
  resource is S3Resource &&
  // Non-compliant conditions
  (resource.encryption_enabled == false ||
   (resource.encryption_enabled == true && 
    !(resource has encryption_algorithm)) ||
   (resource.encryption_enabled == true && 
    resource has encryption_algorithm && 
    !["AES256", "aws:kms", "aws:kms:dsse"].contains(resource.encryption_algorithm))) &&
  
  // AND bucket policy doesn't enforce encryption either
  (!(resource has bucket_policy_enforces_encryption) ||
   (resource has bucket_policy_enforces_encryption && 
    resource.bucket_policy_enforces_encryption == false))
};

// =============================================================================
// SHARED: S3 Bucket Creation and Access Policies
// =============================================================================

// ALLOW: S3 bucket creation only if encryption is properly configured
permit(
  principal,
  action == Action::"s3:CreateBucket",
  resource
)
when {
  resource is S3Resource &&
  resource.encryption_enabled == true &&
  resource has encryption_algorithm &&
  ["AES256", "aws:kms", "aws:kms:dsse"].contains(resource.encryption_algorithm) &&
  // KMS encryption requires key ID
  (resource.encryption_algorithm == "AES256" ||
   (["aws:kms", "aws:kms:dsse"].contains(resource.encryption_algorithm) &&
    resource has kms_key_id))
};

// DENY: S3 bucket creation without proper encryption
forbid(
  principal,
  action == Action::"s3:CreateBucket",
  resource
)
when {
  resource is S3Resource &&
  (resource.encryption_enabled == false ||
   !(resource has encryption_algorithm) ||
   (resource has encryption_algorithm && 
    !["AES256", "aws:kms", "aws:kms:dsse"].contains(resource.encryption_algorithm)) ||
   // KMS encryption without key ID
   (resource has encryption_algorithm && 
    ["aws:kms", "aws:kms:dsse"].contains(resource.encryption_algorithm) &&
    !(resource has kms_key_id)))
};

// ALLOW: Operations team access to encrypted buckets (preserving existing policy logic)
permit(
  principal,
  action == Action::"s3:PutObject",
  resource
)
when {
  principal is User &&
  principal.department == "operations" &&
  resource is Bucket &&
  resource == Bucket::"project-artifacts"
};

// DENY: S3 operations on unencrypted buckets (enhanced security)
forbid(
  principal,
  action in [Action::"s3:PutObject", Action::"s3:GetObject"],
  resource
)
when {
  resource is S3Resource &&
  resource.encryption_enabled == false &&
  resource.environment == "production"
};

// =============================================================================
// PRODUCTION ENVIRONMENT: Enhanced Security for Critical Resources
// =============================================================================

// DENY: Production buckets require KMS encryption (stricter than development/staging)
forbid(
  principal,
  action in [Action::"s3:CreateBucket", Action::"config:EvaluateCompliance"],
  resource
)
when {
  resource is S3Resource &&
  resource.environment == "production" &&
  (resource.encryption_enabled == false ||
   !(resource has encryption_algorithm) ||
   (resource has encryption_algorithm && 
    resource.encryption_algorithm == "AES256")) // Production requires KMS, not just AES256
};

// ALLOW: Production buckets with KMS encryption
permit(
  principal,
  action in [Action::"s3:CreateBucket", Action::"config:EvaluateCompliance"],
  resource
)
when {
  resource is S3Resource &&
  resource.environment == "production" &&
  resource.encryption_enabled == true &&
  resource has encryption_algorithm &&
  ["aws:kms", "aws:kms:dsse"].contains(resource.encryption_algorithm) &&
  resource has kms_key_id
};