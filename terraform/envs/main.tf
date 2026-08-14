module "vpc" {
  source = "../modules/vpc"
}

module "eks" {
  source             = "../modules/eks"
  cluster_version    = "1.34"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
}

module "rds" {
  source             = "../modules/rds"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
}

module "dynamodb" {
  source = "../modules/dynamodb"
}

module "irsa_retail_app" {
  source              = "../modules/irsa-retail-app"
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_issuer_url     = module.eks.oidc_issuer_url
  mysql_secret_arn    = module.rds.mysql_secret_arn
  postgres_secret_arn = module.rds.postgres_secret_arn
}

module "s3_lambda" {
  source     = "../modules/s3-lambda"
  student_id = "alt-soe-tin-025-0166"
}

module "iam_dev_user" {
  source            = "../modules/iam-dev-user"
  cluster_name      = module.eks.cluster_name
  assets_bucket_arn = module.s3_lambda.bucket_arn
}

module "alb_controller" {
  source            = "../modules/alb-controller"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
}

module "github_oidc" {
  source      = "../modules/github-oidc"
  github_repo = "Ejimkeonye/project-bedrock"
}
