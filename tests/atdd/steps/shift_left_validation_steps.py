#!/usr/bin/env python3
"""
Step definitions for ATDD Shift-Left Security Validation tests.

These step definitions implement the Gherkin scenarios defined in 
shift_left_security_validation.feature using the behave framework.
"""

import os
import time
import json
from pathlib import Path
from behave import given, when, then, step
from typing import Dict, Any

# Import our custom Cedar policy runner
import sys
sys.path.append(str(Path(__file__).parent.parent / "support"))
from cedar_policy_runner import CedarPolicyRunner

# Test fixtures directory
FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"


@given('I have a Cedar policy for S3 encryption enforcement')
def step_given_cedar_policy_exists(context):
    """Verify that the S3 encryption enforcement policy exists."""
    context.cedar_runner = CedarPolicyRunner()
    
    policy_exists = context.cedar_runner.validate_policy_exists('s3-encryption-enforcement')
    assert policy_exists, "S3 encryption enforcement policy not found"
    
    context.policy_content = context.cedar_runner.get_policy_content('s3-encryption-enforcement')
    assert context.policy_content, "Could not read policy content"


@given('the policy is located at "{policy_path}"')
def step_given_policy_location(context, policy_path):
    """Verify the policy is at the expected location."""
    # Use the root directory from environment variable
    root_dir = os.environ.get('CEDAR_ROOT_DIR', os.getcwd())
    full_path = Path(root_dir) / policy_path
    assert full_path.exists(), f"Policy file not found at {full_path}"
    context.policy_path = str(full_path)


@given('I have the Cedar schema at "{schema_path}"')
def step_given_cedar_schema(context, schema_path):
    """Verify that the Cedar schema exists."""
    schema_exists = context.cedar_runner.validate_schema_exists()
    assert schema_exists, f"Cedar schema not found at {schema_path}"


@given('I have a CloudFormation template with an encrypted S3 bucket')
def step_given_encrypted_cf_template(context):
    """Set up CloudFormation template with encrypted S3 bucket."""
    context.cf_template_path = FIXTURES_DIR / "cloudformation_templates" / "encrypted-s3-bucket.yaml"
    context.entities_file = FIXTURES_DIR / "s3_entities" / "encrypted_bucket_entity.json"
    
    assert context.cf_template_path.exists(), "Encrypted CloudFormation template not found"
    assert context.entities_file.exists(), "Encrypted bucket entities file not found"
    
    context.expected_compliance = True


@given('I have a CloudFormation template with an unencrypted S3 bucket')
def step_given_unencrypted_cf_template(context):
    """Set up CloudFormation template with unencrypted S3 bucket."""
    context.cf_template_path = FIXTURES_DIR / "cloudformation_templates" / "unencrypted-s3-bucket.yaml"
    context.entities_file = FIXTURES_DIR / "s3_entities" / "unencrypted_bucket_entity.json"
    
    assert context.cf_template_path.exists(), "Unencrypted CloudFormation template not found"
    assert context.entities_file.exists(), "Unencrypted bucket entities file not found"
    
    context.expected_compliance = False


@given('I have a live S3 bucket with AES256 encryption enabled')
def step_given_encrypted_s3_bucket(context):
    """Set up live S3 bucket reference with encryption."""
    context.bucket_name = "atdd-test-encrypted-bucket"
    context.entities_file = FIXTURES_DIR / "s3_entities" / "encrypted_bucket_entity.json"
    context.expected_compliance = True


@given('I have a live S3 bucket without encryption')
def step_given_unencrypted_s3_bucket(context):
    """Set up live S3 bucket reference without encryption."""
    context.bucket_name = "atdd-test-unencrypted-bucket"
    context.entities_file = FIXTURES_DIR / "s3_entities" / "unencrypted_bucket_entity.json"
    context.expected_compliance = False


@given('I have the same Cedar policy file for both contexts')
def step_given_same_policy_file(context):
    """Verify we're using the same policy for both shift-left and shift-right."""
    # Store original policy content for comparison
    context.original_policy_content = context.cedar_runner.get_policy_content('s3-encryption-enforcement')
    assert context.original_policy_content, "Could not read original policy content"


@given('I have equivalent S3 resource configurations (one as CloudFormation, one as live bucket)')
def step_given_equivalent_configurations(context):
    """Set up equivalent encrypted and unencrypted configurations."""
    # Set up both CloudFormation and live bucket configurations
    context.cf_encrypted_template = FIXTURES_DIR / "cloudformation_templates" / "encrypted-s3-bucket.yaml"
    context.cf_encrypted_entities = FIXTURES_DIR / "s3_entities" / "encrypted_bucket_entity.json"
    context.live_encrypted_bucket = "atdd-test-encrypted-bucket"
    
    context.cf_unencrypted_template = FIXTURES_DIR / "cloudformation_templates" / "unencrypted-s3-bucket.yaml"  
    context.cf_unencrypted_entities = FIXTURES_DIR / "s3_entities" / "unencrypted_bucket_entity.json"
    context.live_unencrypted_bucket = "atdd-test-unencrypted-bucket"


@when('I run the shift-left validation using Cedar policies')
def step_when_run_shift_left_validation(context):
    """Execute shift-left validation on CloudFormation template."""
    context.shift_left_start_time = time.time()
    
    context.cf_result = context.cedar_runner.validate_cloudformation_template(
        str(context.cf_template_path),
        str(context.entities_file)
    )
    
    context.shift_left_end_time = time.time()


@when('I run the shift-right validation using the same Cedar policies')
def step_when_run_shift_right_validation(context):
    """Execute shift-right validation on live S3 bucket."""
    context.shift_right_start_time = time.time()
    
    context.s3_result = context.cedar_runner.validate_s3_bucket(
        context.bucket_name,
        str(context.entities_file)
    )
    
    context.shift_right_end_time = time.time()


@when('I validate both the CloudFormation template and the live bucket')
def step_when_validate_both_contexts(context):
    """Execute validation in both shift-left and shift-right contexts."""
    # Validate encrypted configurations
    context.cf_encrypted_result = context.cedar_runner.validate_cloudformation_template(
        str(context.cf_encrypted_template),
        str(context.cf_encrypted_entities)
    )
    
    context.s3_encrypted_result = context.cedar_runner.validate_s3_bucket(
        context.live_encrypted_bucket,
        str(context.cf_encrypted_entities)
    )
    
    # Validate unencrypted configurations
    context.cf_unencrypted_result = context.cedar_runner.validate_cloudformation_template(
        str(context.cf_unencrypted_template),
        str(context.cf_unencrypted_entities)
    )
    
    context.s3_unencrypted_result = context.cedar_runner.validate_s3_bucket(
        context.live_unencrypted_bucket,
        str(context.cf_unencrypted_entities)
    )


@then('the CloudFormation template should be marked as COMPLIANT')
def step_then_cf_template_compliant(context):
    """Verify CloudFormation template is marked as compliant."""
    assert context.cf_result["compliant"] == True, \
        f"Expected COMPLIANT, got {context.cf_result['decision']}: {context.cf_result.get('stderr', '')}"


@then('the CloudFormation template should be marked as NON-COMPLIANT')
def step_then_cf_template_non_compliant(context):
    """Verify CloudFormation template is marked as non-compliant."""
    assert context.cf_result["compliant"] == False, \
        f"Expected NON-COMPLIANT, got {context.cf_result['decision']}: {context.cf_result.get('stdout', '')}"


@then('the S3 bucket should be marked as COMPLIANT')
def step_then_s3_bucket_compliant(context):
    """Verify S3 bucket is marked as compliant."""
    assert context.s3_result["compliant"] == True, \
        f"Expected COMPLIANT, got {context.s3_result['decision']}: {context.s3_result.get('stderr', '')}"


@then('the S3 bucket should be marked as NON-COMPLIANT')
def step_then_s3_bucket_non_compliant(context):
    """Verify S3 bucket is marked as non-compliant."""
    assert context.s3_result["compliant"] == False, \
        f"Expected NON-COMPLIANT, got {context.s3_result['decision']}: {context.s3_result.get('stdout', '')}"


@then('the validation should complete in under {max_seconds:d} second')
@then('the validation should complete in under {max_seconds:d} seconds')
def step_then_validation_time_under_seconds(context, max_seconds):
    """Verify validation completes within time limit."""
    execution_time = context.cf_result.get("execution_time_seconds", 0)
    assert execution_time < max_seconds, \
        f"Validation took {execution_time:.3f}s, expected < {max_seconds}s"


@then('the validation should complete in under {max_milliseconds:d} milliseconds')
def step_then_validation_time_under_milliseconds(context, max_milliseconds):
    """Verify validation completes within millisecond time limit."""
    execution_time = context.s3_result.get("execution_time_seconds", 0)
    max_seconds = max_milliseconds / 1000.0
    assert execution_time < max_seconds, \
        f"Validation took {execution_time*1000:.1f}ms, expected < {max_milliseconds}ms"


@then('the reasoning should indicate "{expected_reasoning}"')
def step_then_reasoning_contains(context, expected_reasoning):
    """Verify the reasoning contains expected text."""
    # Check both stdout and stderr for reasoning information
    output = context.cf_result.get("stdout", "") + context.cf_result.get("stderr", "")
    assert expected_reasoning in output, \
        f"Expected reasoning '{expected_reasoning}' not found in output: {output}"


@then('the reasoning should match the development validation logic')
def step_then_reasoning_matches_development(context):
    """Verify runtime reasoning matches development logic."""
    # Both should have the same decision and similar reasoning
    cf_decision = context.cf_result["decision"]
    s3_decision = context.s3_result["decision"]
    
    assert cf_decision == s3_decision, \
        f"Decisions don't match: CF={cf_decision}, S3={s3_decision}"


@then('both validations should return identical decisions (COMPLIANT/NON-COMPLIANT)')
def step_then_identical_decisions(context):
    """Verify both contexts return identical decisions."""
    # Check encrypted configurations
    encrypted_match = (context.cf_encrypted_result["decision"] == 
                      context.s3_encrypted_result["decision"])
    
    # Check unencrypted configurations  
    unencrypted_match = (context.cf_unencrypted_result["decision"] == 
                        context.s3_unencrypted_result["decision"])
    
    assert encrypted_match, \
        f"Encrypted decisions don't match: CF={context.cf_encrypted_result['decision']}, " \
        f"S3={context.s3_encrypted_result['decision']}"
    
    assert unencrypted_match, \
        f"Unencrypted decisions don't match: CF={context.cf_unencrypted_result['decision']}, " \
        f"S3={context.s3_unencrypted_result['decision']}"


@then('both validations should use identical reasoning logic')
def step_then_identical_reasoning(context):
    """Verify both contexts use identical reasoning logic."""
    # Since we're using the same policy file, the reasoning should be identical
    # This is verified by checking that decisions match for equivalent configurations
    consistency_encrypted = context.cedar_runner.compare_policy_consistency(
        context.cf_encrypted_result, 
        context.s3_encrypted_result
    )
    
    consistency_unencrypted = context.cedar_runner.compare_policy_consistency(
        context.cf_unencrypted_result,
        context.s3_unencrypted_result
    )
    
    assert consistency_encrypted["same_reasoning_logic"], \
        "Encrypted configurations show different reasoning logic"
    
    assert consistency_unencrypted["same_reasoning_logic"], \
        "Unencrypted configurations show different reasoning logic"


@then('the policy statements should be byte-for-byte identical')
def step_then_policy_statements_identical(context):
    """Verify policy content hasn't changed between validations."""
    current_policy_content = context.cedar_runner.get_policy_content('s3-encryption-enforcement')
    
    assert current_policy_content == context.original_policy_content, \
        "Policy content has changed between validations"


@then('there should be no gaps between shift-left and shift-right security')
def step_then_no_security_gaps(context):
    """Verify no security gaps between development and runtime."""
    consistency_encrypted = context.cedar_runner.compare_policy_consistency(
        context.cf_encrypted_result,
        context.s3_encrypted_result
    )
    
    consistency_unencrypted = context.cedar_runner.compare_policy_consistency(
        context.cf_unencrypted_result,
        context.s3_unencrypted_result
    )
    
    assert consistency_encrypted["analysis"]["no_security_gaps"], \
        "Security gaps detected in encrypted configuration validation"
    
    assert consistency_unencrypted["analysis"]["no_security_gaps"], \
        "Security gaps detected in unencrypted configuration validation"


# Additional helper steps can be added here as needed...