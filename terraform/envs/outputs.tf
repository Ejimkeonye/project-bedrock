output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_name" { value = module.eks.cluster_name }
output "region" { value = "us-east-1" }
output "vpc_id" { value = module.vpc.vpc_id }
output "assets_bucket_name" { value = module.s3_lambda.bucket_name }
output "alb_controller_role_arn" { value = module.alb_controller.alb_controller_role_arn }
output "dev_view_access_key_id" {
  value = module.iam_dev_user.dev_view_access_key_id
}

output "dev_view_secret_access_key" {
  value     = module.iam_dev_user.dev_view_secret_access_key
  sensitive = true
}

output "dev_view_console_password" {
  value     = module.iam_dev_user.dev_view_console_password
  sensitive = true
}