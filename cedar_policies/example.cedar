// Example Cedar policy that allows s3:PutObject access to buckets
// Last updated: January 2025 - with CloudFormation permissions and OIDC integration
// Tested with local validation scripts and CI/CD pipeline
// Trigger for GitHub Actions validation
permit (
  principal == User::"alice",
  action == Action::"s3:PutObject",
  resource == Bucket::"example-bucket"
);
