# --- GitHub Actions OIDC provider + IAM role for Terraform CI/CD ---
# Lets GitHub Actions assume an AWS role without storing long-lived access keys.

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # GitHub's OIDC thumbprint (rarely changes, but verify against
  # https://github.blog/changelog/ if this ever needs updating)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions_terraform" {
  name = "github-actions-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # IMPORTANT: replace with your actual GitHub org/user and repo name.
            # Allowing both main branch runs and pull requests to assume this role.
            # Using wildcards (*) to support GitHub's new OIDC immutable subject format (repo:owner@id/repo@id)
            "token.actions.githubusercontent.com:sub" = [
              "repo:GeekKwame*/terraform-study-project*:ref:refs/heads/main",
              "repo:GeekKwame*/terraform-study-project*:pull_request"
            ]
          }
        }
      }
    ]
  })
}

# Start scoped to what Phase 1 actually needs (EC2, VPC, IAM read).
# Widen this deliberately as later phases add ECR/ECS/ALB resources —
# don't jump straight to AdministratorAccess.
resource "aws_iam_role_policy" "terraform_permissions" {
  name = "terraform-phase1-permissions"
  role = aws_iam_role.github_actions_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "iam:GetRole",
          "iam:PassRole",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_terraform.arn
}