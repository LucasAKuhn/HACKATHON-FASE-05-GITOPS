data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

module "networking" {
  source = "./modules/networking"
}

module "eks" {
  source           = "./modules/eks"
  vpc_id           = module.networking.vpc_id
  public_subnets   = module.networking.public_subnets
  private_subnets  = module.networking.private_subnets
  lab_role_arn     = data.aws_iam_role.lab_role.arn
  lab_eks_role_arn = data.aws_iam_role.lab_role.arn
}

module "database" {
  source          = "./modules/database"
  vpc_id          = module.networking.vpc_id
  public_subnets  = module.networking.public_subnets
  private_subnets = module.networking.private_subnets
  db_password     = var.db_password
}

module "messaging" {
  source = "./modules/messaging"
}

module "ecr" {
  source = "./modules/ecr"
}
