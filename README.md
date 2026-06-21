# 🏗️ SolidaryTech — GitOps Repository (GITOPS)

Manifestos Kubernetes e Infraestrutura (Terraform). Monitorado pelo ArgoCD como fonte de verdade do cluster.

**💻 Repo de Aplicações:** [HACKATHON-FASE-05-APPS](https://github.com/SEU-USER/HACKATHON-FASE-05-APPS)

---

## 📂 Estrutura do Repo

```text
HACKATHON-FASE-05-GITOPS/
├── k8s/                             # Manifestos K8s monitorados pelo ArgoCD
│   ├── 00-db-init-job.yaml          # Job de inicialização do DB
│   ├── 01-ngo.yaml                  # NGO Service
│   ├── 02-donation.yaml             # Donation Service (LoadBalancer)
│   ├── 03-volunteer.yaml            # Volunteer Service
│   ├── 08-hpa.yaml                  # Autoscaling
│   ├── 09-argo-application.yaml     # Application do ArgoCD
│   └── 12-external-secret.yaml      # External Secrets
└── terraform/                       # IaC (AWS Academy)
    ├── providers.tf                 # Backend Local
    ├── network.tf                   # VPC + Subnets
    ├── eks.tf                       # Cluster EKS
    ├── rds.tf                       # PostgreSQL
    ├── messaging.tf                 # SQS + DynamoDB
    └── helm.tf                      # Helm charts
```

---

## ☁️ Infraestrutura (AWS Academy)

Configurado para contornar os limites do Learner Lab:
- Usa `LabEksClusterRole` para o EKS e `LabRole` nos nodes.
- Sem *Enhanced Monitoring* no RDS.
- Node group limitado a 3 `t3.medium`.
- Backend do Terraform configurado dinamicamente para **S3** (via variável de ambiente `TF_VAR_state_bucket`), garantindo persistência e segurança de estado em nível de produção.
- `auxiliar_terraform.ps1` é o script central de orquestração.

---

## 🔄 GitOps Workflow

```text
APPS                                 GITOPS (este repo)
├── Código dos serviços              ├── k8s/ ◄── ArgoCD monitora
├── Workflows CI/CD                  ├── terraform/
└── Dockerfiles                              ▲
         │                                   │
         └──► CI faz cross-repo update ──────┘
              da imagem Docker
```

Sincronização automática via ArgoCD. O setup inicial do banco roda via hook PostSync (`00-db-init-job.yaml`).

---

## 🚀 Deploy (Quick Start)

### Provisionar Infra
```powershell
cd terraform
terraform init
terraform apply -var="github_repo_url=https://github.com/SEU-USER/HACKATHON-FASE-05-GITOPS.git"
```

### Sync GitOps
Faça commit e push deste repositório para o GitHub. O ArgoCD detecta a pasta `k8s/` e aplica os manifestos.

### Destruir
No fim do dia, limpe a infraestrutura para evitar consumo de créditos:
```powershell
cd terraform
terraform destroy -auto-approve
```
