variable "cluster_name" {}
variable "assets_bucket_arn" {}

resource "aws_iam_user" "dev_view" {
  name = "bedrock-dev-view"
}

resource "aws_iam_user_policy_attachment" "readonly" {
  user       = aws_iam_user.dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_access_key" "dev_view" {
  user = aws_iam_user.dev_view.name
}

resource "aws_iam_user_login_profile" "dev_view" {
  user                    = aws_iam_user.dev_view.name
  password_reset_required = true
}

resource "aws_iam_user_policy" "dev_view_s3_put" {
  user = aws_iam_user.dev_view.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "${var.assets_bucket_arn}/*"
    }]
  })
}

resource "aws_eks_access_entry" "dev_view" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_user.dev_view.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "dev_view" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_user.dev_view.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["retail-app"]
  }
}

output "dev_view_access_key_id" {
  value = aws_iam_access_key.dev_view.id
}

output "dev_view_secret_access_key" {
  value     = aws_iam_access_key.dev_view.secret
  sensitive = true
}

output "dev_view_console_password" {
  value     = aws_iam_user_login_profile.dev_view.password
  sensitive = true
}