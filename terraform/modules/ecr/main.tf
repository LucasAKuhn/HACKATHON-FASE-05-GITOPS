locals {
  # Lista dos microsserviços do projeto SolidaryTech
  repos = ["ngo", "donation", "volunteer"]
}

resource "aws_ecr_repository" "repos" {
  count                = length(local.repos)
  name                 = "${local.repos[count.index]}-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Facilita o tear down do ambiente efêmero
}
