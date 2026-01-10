# iac/ecr.tf

resource "aws_ecr_repository" "app_repo" {
  name                 = "asterra-geo-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true 

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.environment}-ecr-repo"
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}