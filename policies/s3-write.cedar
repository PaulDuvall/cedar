// Allow PutObject if the user's department is operations
// This policy ensures secure write access to project artifacts
// Validated: January 2025 - with OIDC authentication
permit(
  principal,
  action,
  resource
)
when {
  principal is User &&
  principal.department == "operations" &&
  action == Action::"s3:PutObject" &&
  resource == Bucket::"project-artifacts"
};
