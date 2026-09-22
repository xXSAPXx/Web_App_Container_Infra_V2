
##################################################################
# ECR repositories for the app images - pushed to automatically by
# .github/workflows/build-push-images.yml on merge to main.
#
# image_tag_mutability = IMMUTABLE: safe with the tagging scheme CI
# uses (v<run_number> always increments; the short-SHA tag is only
# ever re-pushed for the exact same commit, which BuildKit's cache
# makes an identical-digest no-op in practice) - blocks anything else
# from silently overwriting a tag already in use.
#
# encryption_configuration: KMS (the default AWS-managed aws/ecr key,
# not a dedicated customer-managed one - satisfies Checkov's
# CKV_AWS_136 at no extra cost). This is set once at creation and
# can't be changed in place - flagged and confirmed before applying,
# since force_delete = true meant Terraform would recreate both repos
# (and delete every image in them) to apply this change.
##################################################################

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.repository_prefix}-frontend"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.repository_prefix}-backend"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

# Trusted base image repo - curated, scanned base images (node:26-alpine,
# httpd:2.4-alpine) that backend/frontend Dockerfiles pull FROM instead of
# Docker Hub directly. Populated by a dedicated curation workflow (pull
# upstream -> Trivy scan -> only if clean, push here) - not by
# build-push-images.yml.
#
# MUTABLE, unlike the app repos above: each base image lives under one
# stable tag (node-26-alpine, httpd-2.4-alpine) that gets overwritten
# whenever a re-scanned refresh is pushed - there's no per-commit
# versioning scheme here to make immutability meaningful. No lifecycle
# policy either - only ever 2 tags total, nothing to expire.
resource "aws_ecr_repository" "trusted_base_images" {
  name                 = "trusted_base_images"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

# Keep only the most recent N images per repo so this doesn't grow unbounded
# across repeated manual pushes during testing.
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.max_image_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_image_count
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.max_image_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_image_count
      }
      action = { type = "expire" }
    }]
  })
}
