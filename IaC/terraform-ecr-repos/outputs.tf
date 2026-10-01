
output "frontend_repository_url" {
  value = module.ecr.frontend_repository_url
}

output "backend_repository_url" {
  value = module.ecr.backend_repository_url
}

output "trusted_base_images_repository_url" {
  value = module.ecr.trusted_base_images_repository_url
}

output "github_actions_ecr_push_role_arn" {
  value = aws_iam_role.ecr_push.arn
}

# Goes into the AWS_BASE_IMAGE_CURATOR_ROLE_ARN GitHub secret - same
# handling as the ecr_push role ARN above.
output "github_actions_base_image_curator_role_arn" {
  value = aws_iam_role.base_image_curator.arn
}
