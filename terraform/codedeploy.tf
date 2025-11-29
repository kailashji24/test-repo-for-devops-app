# 1. S3 Bucket for GitHub Actions Artifacts
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "codedeploy_bucket" {
  bucket = "cicd-artifacts-${random_id.bucket_id.hex}"
  force_destroy = true
}

# 2. IAM Role for CodeDeploy Service
resource "aws_iam_role" "codedeploy_service_role" {
  name = "codedeploy-service-role-final"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy_service_role.name
}

# 3. CodeDeploy Application & Group
resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = "Lift-and-Shift-App"
}

resource "aws_codedeploy_deployment_group" "group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "Lift-and-Shift-DG"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  # Connects to your existing ASG
  autoscaling_groups = [aws_autoscaling_group.asg.name] 

  # --- FIX: Tell CodeDeploy about the Load Balancer ---
  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.app_tg.name
    }
  }
  # ----------------------------------------------------

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }
}