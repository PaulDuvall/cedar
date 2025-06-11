# ATDD Test for US-010: Shift-Left Security Validation
# 
# User Story:
# As a security engineer implementing policy-as-code
# I want the same policies to validate both development artifacts and runtime resources
# So that security controls are consistent across the entire SDLC

Feature: Shift-Left Security Validation with Cedar Policies
  
  Background:
    Given I have a Cedar policy for S3 encryption enforcement
    And the policy is located at "cedar_policies/s3-encryption-enforcement.cedar"
    And I have the Cedar schema at "schema.cedarschema"

  @shift-left @development
  Scenario: Validate CloudFormation template with encrypted S3 bucket during development
    Given I have a CloudFormation template with an encrypted S3 bucket
    When I run the shift-left validation using Cedar policies
    Then the CloudFormation template should be marked as COMPLIANT
    And the validation should complete in under 1 second
    And the reasoning should indicate "encryption_enabled == true"

  @shift-left @development  
  Scenario: Reject CloudFormation template with unencrypted S3 bucket during development
    Given I have a CloudFormation template with an unencrypted S3 bucket
    When I run the shift-left validation using Cedar policies
    Then the CloudFormation template should be marked as NON-COMPLIANT
    And the validation should complete in under 1 second
    And the reasoning should indicate "encryption_enabled == false"

  @shift-right @runtime
  Scenario: Validate live S3 bucket with encryption in production
    Given I have a live S3 bucket with AES256 encryption enabled
    When I run the shift-right validation using the same Cedar policies
    Then the S3 bucket should be marked as COMPLIANT
    And the validation should complete in under 100 milliseconds
    And the reasoning should match the development validation logic

  @shift-right @runtime
  Scenario: Detect non-compliant live S3 bucket in production
    Given I have a live S3 bucket without encryption
    When I run the shift-right validation using the same Cedar policies
    Then the S3 bucket should be marked as NON-COMPLIANT
    And the validation should complete in under 100 milliseconds
    And the reasoning should match the development validation logic

  @consistency @end-to-end
  Scenario: Identical policy logic across development and production contexts
    Given I have the same Cedar policy file for both contexts
    And I have equivalent S3 resource configurations (one as CloudFormation, one as live bucket)
    When I validate both the CloudFormation template and the live bucket
    Then both validations should return identical decisions (COMPLIANT/NON-COMPLIANT)
    And both validations should use identical reasoning logic
    And the policy statements should be byte-for-byte identical
    And there should be no gaps between shift-left and shift-right security

  @audit-trail @governance
  Scenario: Consistent audit trail across SDLC stages
    Given I validate resources in both development and production contexts
    When I review the authorization decision logs
    Then both development and runtime decisions should reference the same policy
    And the decision reasoning should be traceable across environments
    And the audit trail should show consistent policy enforcement
    And compliance officers should be able to verify policy consistency

  @environment-aware @production-hardening
  Scenario: Environment-specific security enforcement while maintaining policy consistency
    Given I have Cedar policies that differentiate between environments
    And I have resources tagged with environment attributes
    When I validate a production S3 bucket that only has AES256 encryption
    Then the production policy should mark it as NON-COMPLIANT (requires KMS)
    When I validate the same configuration in development environment
    Then the development policy should mark it as COMPLIANT (allows AES256)
    And both validations should use the same underlying policy file
    And the environment-specific logic should be clearly documented in the policy

  @performance @scale
  Scenario: Policy validation performance meets SDLC requirements
    Given I have multiple S3 resources to validate
    When I run shift-left validation on 10 CloudFormation templates
    Then all validations should complete in under 5 seconds total
    When I run shift-right validation on 10 live S3 buckets
    Then all validations should complete in under 1 second total
    And the same policy engine should handle both contexts efficiently

  @integration @ci-cd
  Scenario: Seamless integration in CI/CD pipeline
    Given I have a GitHub Actions workflow that uses Cedar policies
    When a developer pushes code with CloudFormation templates
    Then the CI pipeline should validate templates using Cedar policies
    And the same policies should be deployed to AWS Verified Permissions
    And runtime authorization should use the deployed policies
    And the entire flow should complete without manual intervention
    And there should be no policy drift between development and production

# Test Implementation Notes:
# 
# These scenarios should be implemented as executable tests that:
# 1. Use real Cedar policies from the policies/ directory
# 2. Test against actual CloudFormation templates from examples/
# 3. Validate against real S3 buckets (created and cleaned up in tests)
# 4. Measure and assert on performance requirements
# 5. Verify byte-for-byte policy consistency
# 6. Integrate with the existing test infrastructure (scripts/cedar_testrunner.sh)
#
# Expected test files structure:
# - tests/atdd/steps/shift_left_validation_steps.py (step definitions)
# - tests/atdd/fixtures/cloudformation_templates/ (test templates)
# - tests/atdd/fixtures/s3_bucket_configs/ (test bucket configurations)
# - tests/atdd/support/cedar_policy_runner.py (Cedar CLI wrapper)
# - tests/atdd/support/aws_resource_manager.py (S3 bucket management)
#
# Success Criteria:
# - All scenarios pass consistently
# - Performance requirements are met
# - Policy consistency is mathematically verified
# - Integration with existing CI/CD pipeline is seamless
# - Audit trail requirements are satisfied