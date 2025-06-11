// Example Cedar policy that allows s3:PutObject access to buckets
// Last updated: January 2025 - with CloudFormation permissions
// Tested with local validation scripts
permit (
  principal == User::"alice",
  action == Action::"s3:PutObject",
  resource == Bucket::"example-bucket"
);
