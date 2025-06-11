#!/usr/bin/env python3
"""
Cedar Policy Runner for ATDD Tests

This module provides a wrapper around the Cedar CLI for use in ATDD test scenarios.
It handles both shift-left (CloudFormation) and shift-right (runtime) validation.
"""

import subprocess
import json
import time
import os
from pathlib import Path
from typing import Dict, Any, Optional, Tuple

class CedarPolicyRunner:
    def __init__(self, policy_dir: str = "policies", schema_file: str = "schema.cedarschema"):
        self.policy_dir = Path(policy_dir)
        self.schema_file = Path(schema_file)
        self.project_root = Path(__file__).parent.parent.parent.parent
        
    def validate_cloudformation_template(self, template_path: str, entities_file: str) -> Dict[str, Any]:
        """
        Perform shift-left validation on CloudFormation template using Cedar policies.
        
        Args:
            template_path: Path to CloudFormation template
            entities_file: Path to Cedar entities JSON file
            
        Returns:
            Dict containing validation result and timing information
        """
        start_time = time.time()
        
        try:
            # Run Cedar authorization command
            cmd = [
                "cedar", "authorize",
                "--policies", str(self.project_root / self.policy_dir),
                "--schema", str(self.project_root / self.schema_file),
                "--entities", entities_file,
                "--principal", 'ConfigEvaluation::"s3-bucket-server-side-encryption-enabled"',
                "--action", 'Action::"cloudformation:ValidateTemplate"',
                "--resource", 'CloudFormationTemplate::"encrypted-s3-bucket-template"'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            
            end_time = time.time()
            execution_time = end_time - start_time
            
            # Parse Cedar CLI output
            is_compliant = result.returncode == 0
            decision = "ALLOW" if is_compliant else "DENY"
            
            return {
                "decision": decision,
                "compliant": is_compliant,
                "execution_time_seconds": execution_time,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "context": "shift-left",
                "resource_type": "cloudformation_template"
            }
            
        except subprocess.TimeoutExpired:
            return {
                "decision": "ERROR",
                "compliant": False,
                "execution_time_seconds": time.time() - start_time,
                "error": "Command timed out",
                "context": "shift-left"
            }
        except Exception as e:
            return {
                "decision": "ERROR", 
                "compliant": False,
                "execution_time_seconds": time.time() - start_time,
                "error": str(e),
                "context": "shift-left"
            }
    
    def validate_s3_bucket(self, bucket_name: str, entities_file: str) -> Dict[str, Any]:
        """
        Perform shift-right validation on live S3 bucket using Cedar policies.
        
        Args:
            bucket_name: Name of S3 bucket to validate
            entities_file: Path to Cedar entities JSON file
            
        Returns:
            Dict containing validation result and timing information
        """
        start_time = time.time()
        
        try:
            # Run Cedar authorization command for S3 bucket
            cmd = [
                "cedar", "authorize",
                "--policies", str(self.project_root / self.policy_dir),
                "--schema", str(self.project_root / self.schema_file),
                "--entities", entities_file,
                "--principal", 'ConfigEvaluation::"s3-bucket-server-side-encryption-enabled"',
                "--action", 'Action::"config:EvaluateCompliance"',
                "--resource", f'S3Resource::"{bucket_name}"'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            
            end_time = time.time()
            execution_time = end_time - start_time
            
            # Parse Cedar CLI output
            is_compliant = result.returncode == 0
            decision = "ALLOW" if is_compliant else "DENY"
            
            return {
                "decision": decision,
                "compliant": is_compliant,
                "execution_time_seconds": execution_time,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "context": "shift-right",
                "resource_type": "s3_bucket"
            }
            
        except subprocess.TimeoutExpired:
            return {
                "decision": "ERROR",
                "compliant": False,
                "execution_time_seconds": time.time() - start_time,
                "error": "Command timed out",
                "context": "shift-right"
            }
        except Exception as e:
            return {
                "decision": "ERROR",
                "compliant": False,
                "execution_time_seconds": time.time() - start_time,
                "error": str(e),
                "context": "shift-right"
            }
    
    def compare_policy_consistency(self, cf_result: Dict[str, Any], s3_result: Dict[str, Any]) -> Dict[str, Any]:
        """
        Compare policy decisions between shift-left and shift-right contexts.
        
        Args:
            cf_result: Result from CloudFormation validation
            s3_result: Result from S3 bucket validation
            
        Returns:
            Dict containing consistency analysis
        """
        decisions_match = cf_result["decision"] == s3_result["decision"]
        compliant_match = cf_result["compliant"] == s3_result["compliant"]
        
        return {
            "consistent": decisions_match and compliant_match,
            "decisions_match": decisions_match,
            "compliant_match": compliant_match,
            "shift_left_decision": cf_result["decision"],
            "shift_right_decision": s3_result["decision"],
            "shift_left_time": cf_result["execution_time_seconds"],
            "shift_right_time": s3_result["execution_time_seconds"],
            "analysis": {
                "same_policy_file": True,  # Always true in our case
                "same_reasoning_logic": decisions_match,
                "no_security_gaps": decisions_match and compliant_match
            }
        }
    
    def validate_policy_exists(self, policy_name: str) -> bool:
        """Verify that a Cedar policy file exists."""
        policy_path = self.project_root / self.policy_dir / f"{policy_name}.cedar"
        return policy_path.exists()
    
    def get_policy_content(self, policy_name: str) -> Optional[str]:
        """Get the content of a Cedar policy file."""
        policy_path = self.project_root / self.policy_dir / f"{policy_name}.cedar"
        if policy_path.exists():
            return policy_path.read_text()
        return None
    
    def validate_schema_exists(self) -> bool:
        """Verify that the Cedar schema file exists."""
        schema_path = self.project_root / self.schema_file
        return schema_path.exists()

if __name__ == "__main__":
    # Simple test of the Cedar Policy Runner
    runner = CedarPolicyRunner()
    
    print("Cedar Policy Runner Test")
    print("=" * 40)
    print(f"Policy directory exists: {runner.policy_dir.exists()}")
    print(f"Schema file exists: {runner.schema_file.exists()}")
    print(f"S3 encryption policy exists: {runner.validate_policy_exists('s3-encryption-enforcement')}")
    
    if runner.validate_policy_exists('s3-encryption-enforcement'):
        print("\nPolicy content preview:")
        content = runner.get_policy_content('s3-encryption-enforcement')
        print(content[:200] + "..." if len(content) > 200 else content)