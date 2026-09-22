
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
