variable "oidc_provider_arn" {}
variable "oidc_issuer_url" {}
variable "mysql_secret_arn" {}
variable "postgres_secret_arn" {}

data "aws_iam_policy_document" "irsa_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
     values = [
        "system:serviceaccount:retail-app:retail-app-sa",
        "system:serviceaccount:retail-app:carts"
      ]
    }
  }
}

resource "aws_iam_role" "retail_app" {
  name               = "bedrock-retail-app-role"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
}

resource "aws_iam_role_policy" "retail_app_secrets" {
  role = aws_iam_role.retail_app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.mysql_secret_arn, var.postgres_secret_arn]
    }]
  })
}

output "retail_app_role_arn" { value = aws_iam_role.retail_app.arn }
resource "aws_iam_role_policy" "retail_app_dynamodb" {
  role = aws_iam_role.retail_app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = [
      "arn:aws:dynamodb:us-east-1:930804195409:table/bedrock-carts",
      "arn:aws:dynamodb:us-east-1:930804195409:table/bedrock-carts/index/*"
    ]
    }]
  })
}
