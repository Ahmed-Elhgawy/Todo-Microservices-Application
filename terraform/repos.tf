resource "aws_ecr_repository" "ecr-todo-api" {
  name                 = "todo-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecr_repository" "ecr-todo-worker" {
  name                 = "todo-worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecr_repository" "ecr-frontend" {
  name                 = "frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

locals {
  repos = [
    aws_ecr_repository.ecr-todo-api.name,
    aws_ecr_repository.ecr-todo-worker.name,
    aws_ecr_repository.ecr-frontend.name,
  ]
}

resource "aws_ecr_lifecycle_policy" "ecr-repos-policies" {
  count      = length(local.repos)
  repository = local.repos[count.index]

  policy = <<-EOF
    {
        "rules": [
            {
                "rulePriority": 1,
                "description": "Keep last 2 images",
                "selection": {
                    "tagStatus": "tagged",
                    "tagPrefixList": ["v"],
                    "countType": "imageCountMoreThan",
                    "countNumber": 2
                },
                "action": {
                    "type": "expire"
                }
            }
        ]
    }
  EOF
}