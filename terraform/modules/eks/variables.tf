variable "vpc_id" {}
variable "public_subnets" {
  description = "IDs das subnets públicas"
  type        = list(string)
}

variable "private_subnets" {
  description = "IDs das subnets privadas"
  type        = list(string)
}

variable "lab_role_arn" {}
variable "lab_eks_role_arn" {}
