variable "aws_region" {
  description = "Regiao principal da AWS para a infraestrutura"
  type        = string
  default     = "us-east-1"
}

variable "github_pat" {
  description = "Personal Access Token do GitHub para o ArgoCD ler o repositorio privado"
  type        = string
  sensitive   = true
  default     = "" # Pode ficar vazio na declaracao, passar via TF_VAR_github_pat
}

variable "github_repo_url" {
  description = "A URL do seu repositorio Git que o ArgoCD deve escutar. Passe via TF_VAR_github_repo_url"
  type        = string
  default     = "https://github.com/julianopoklen/HACKATHON-FASE-05-GITOPS.git"
}

variable "db_password" {
  description = "A senha mestre dos bancos de dados RDS. Obrigatoria via: TF_VAR_db_password"
  type        = string
  sensitive   = true
  default     = "SolidaryTech2026!"
}

variable "db_password_ngo" {
  description = "A senha do banco de dados ngo_db para o usuario app_ngo. Obrigatoria via: TF_VAR_db_password_ngo"
  type        = string
  sensitive   = true
  default     = "SolidaryTech2026_NGO!"
}

variable "db_password_donation" {
  description = "A senha do banco de dados donation_db para o usuario app_donation. Obrigatoria via: TF_VAR_db_password_donation"
  type        = string
  sensitive   = true
  default     = "SolidaryTech2026_DONATION!"
}

variable "new_relic_license_key" {
  description = "Chave de ingestao do APM (New Relic / Datadog). Passe via TF_VAR_new_relic_license_key"
  type        = string
  sensitive   = true
  default     = ""
}
