resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }
  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = "true"
  }
  set {
    name  = "controller.metrics.serviceMonitor.additionalLabels.release"
    value = "prometheus"
  }
}

# Stack de Observabilidade simplificada
resource "helm_release" "kube_prometheus_stack" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "observability"
  create_namespace = true
}


# ============================================================================
# OTel Collector — configurado para EXPORTAR traces para o New Relic (OTLP).
# Substitui o bloco "helm_release.otel_collector" anterior.
# A license key vem da variável new_relic_license_key (TF_VAR_new_relic_license_key).
# ============================================================================
resource "helm_release" "otel_collector" {
  name             = "otel-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  namespace        = "observability"
  create_namespace = true

  set {
    name  = "mode"
    value = "daemonset"
  }
  set {
    name  = "image.repository"
    value = "otel/opentelemetry-collector-contrib"
  }

  # Configuração do pipeline: recebe via OTLP e exporta para o New Relic.
  values = [<<-YAML
    config:
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318
      processors:
        batch: {}
      exporters:
        otlphttp/newrelic:
          endpoint: "https://otlp.nr-data.net"
          headers:
            api-key: "${var.new_relic_license_key}"
        debug:
          verbosity: normal
      service:
        pipelines:
          traces:
            receivers: [otlp]
            processors: [batch]
            exporters: [otlphttp/newrelic, debug]
  YAML
  ]
}





# --- OBSERVABILIDADE AVANÇADA (LOGS) ---
resource "helm_release" "loki" {
  name             = "loki"
  namespace        = "observability"
  create_namespace = true
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = "5.41.5" # Uma versão mais estável e light
  timeout          = 600
  wait             = false

  set {
    name  = "deploymentMode"
    value = "SingleBinary"
  }
  set {
    name  = "loki.auth_enabled"
    value = "false"
  }
  set {
    name  = "loki.commonConfig.replication_factor"
    value = "1"
  }
  set {
    name  = "loki.containerSecurityContext.readOnlyRootFilesystem"
    value = "false"
  }
  set {
    name  = "loki.storage.type"
    value = "filesystem"
  }
  set {
    name  = "singleBinary.replicas"
    value = "1"
  }
  set {
    name  = "read.replicas"
    value = "0"
  }
  set {
    name  = "write.replicas"
    value = "0"
  }
  set {
    name  = "backend.replicas"
    value = "0"
  }
  set {
    name  = "gateway.enabled"
    value = "false"
  }
  set {
    name  = "singleBinary.persistence.enabled"
    value = "false"
  }

  depends_on = [module.eks]
}

resource "helm_release" "promtail" {
  name             = "promtail"
  namespace        = "observability"
  create_namespace = true
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = "6.15.3"
  timeout          = 300
  wait             = true

  set {
    name  = "config.clients[0].url"
    value = "http://loki.observability.svc.cluster.local:3100/loki/api/v1/push"
  }

  depends_on = [helm_release.loki]
}

# --- GITOPS AUTOMATION ---
resource "kubernetes_secret_v1" "argocd_repo_secret" {
  metadata {
    name      = "repos-github-secret"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    url      = var.github_repo_url
    password = var.github_pat
    username = "oauth2"
    type     = "git"
  }

  depends_on = [ helm_release.argocd ]
}

resource "null_resource" "argocd_application" {
  triggers = {
    repo_url     = var.github_repo_url
    cluster_name = module.eks.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region us-east-1 --name ${self.triggers.cluster_name}
      kubectl apply -f ${path.root}/../k8s/09-argo-application.yaml
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.argocd_repo_secret
  ]
}

# Geração dinâmica de ConfigMap com os endpoints dos serviços gerenciados
resource "kubernetes_namespace_v1" "solidarytech" {
  metadata {
    name = "solidarytech"
  }
}

resource "local_file" "configmap_k8s" {
  filename = "${path.module}/../k8s/00-configmap.yaml"
  content  = <<-EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: solidarytech-config
  namespace: solidarytech
data:
  DATABASE_HOST: "${module.database.postgres_host}"
  DATABASE_NAME: "postgres"
  AWS_SQS_URL: "${module.messaging.sqs_url}"
  AWS_DYNAMODB_TABLE: "${module.messaging.dynamodb_table}"
  AWS_REGION: "${var.aws_region}"
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector-opentelemetry-collector.observability.svc.cluster.local:4318"
EOT
}

# --- 9. GITOPS AUTOMAÇÃO DE BANCOS DE DADOS E SECRETS (ZERO-TOUCH) ---

# Injeção de Secret direta via Terraform
resource "kubernetes_secret_v1" "db_credentials" {
  metadata {
    name      = "db-credentials"
    namespace = "solidarytech"
  }

  data = {
    password_ngo     = var.db_password_ngo
    password_donation = var.db_password_donation
    dsn_ngo      = "postgres://app_ngo:${var.db_password_ngo}@${module.database.postgres_host}:5432/ngo_db?sslmode=disable"
    dsn_donation = "postgres://app_donation:${var.db_password_donation}@${module.database.postgres_host}:5432/donation_db?sslmode=disable"
  }

  depends_on = [ module.eks, kubernetes_namespace_v1.solidarytech ]
}

# Inicializa as tabelas lógicas no RDS através de um Job executado
# de dentro do cluster EKS (evitando bloqueios de VPC/Security Groups locais)
resource "kubernetes_job_v1" "db_init" {
  metadata {
    name      = "db-init-job"
    namespace = "solidarytech"
  }
  spec {
    ttl_seconds_after_finished = 60 # Remove o Job e o Pod 60 segundos após o término
    template {
      metadata {
        labels = {
          app = "db-init"
        }
      }
      spec {
        container {
          name    = "psql-runner"
          image   = "postgres:15-alpine"
          command = ["/bin/sh", "-c"]
          args    = [
            replace(<<-EOF
            export PGPASSWORD='${var.db_password}'
            echo "[DATABASE] Criando bancos e usuarios..."
            psql -h ${module.database.postgres_host} -U postgres -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'ngo_db'" | grep -q 1 || psql -h ${module.database.postgres_host} -U postgres -d postgres -c "CREATE DATABASE ngo_db"
            psql -h ${module.database.postgres_host} -U postgres -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'donation_db'" | grep -q 1 || psql -h ${module.database.postgres_host} -U postgres -d postgres -c "CREATE DATABASE donation_db"

            psql -h ${module.database.postgres_host} -U postgres -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname = 'app_ngo'" | grep -q 1 || psql -h ${module.database.postgres_host} -U postgres -d postgres -c "CREATE ROLE app_ngo WITH LOGIN PASSWORD '${var.db_password_ngo}'"
            psql -h ${module.database.postgres_host} -U postgres -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname = 'app_donation'" | grep -q 1 || psql -h ${module.database.postgres_host} -U postgres -d postgres -c "CREATE ROLE app_donation WITH LOGIN PASSWORD '${var.db_password_donation}'"

            echo "[DATABASE] Configurando permissoes e schema ngo_db..."
            psql -h ${module.database.postgres_host} -U postgres -d ngo_db -c "
              GRANT CONNECT ON DATABASE ngo_db TO app_ngo;
              GRANT USAGE ON SCHEMA public TO app_ngo;

              CREATE TABLE IF NOT EXISTS ngos (
                  id SERIAL PRIMARY KEY,
                  name VARCHAR(150) NOT NULL,
                  email VARCHAR(100) UNIQUE NOT NULL,
                  cause VARCHAR(100) NOT NULL,
                  city VARCHAR(100) NOT NULL,
                  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
              );

              INSERT INTO ngos (name, email, cause, city) VALUES 
              ('Anjos de Patas', 'contato@anjosdepatas.org', 'Proteção Animal', 'Osasco'),
              ('Educa Mais', 'info@educamais.org', 'Educação', 'São Paulo')
              ON CONFLICT DO NOTHING;

              GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_ngo;
              GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_ngo;
              ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_ngo;
              ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_ngo;
            "

            echo "[DATABASE] Configurando permissoes e schema donation_db..."
            psql -h ${module.database.postgres_host} -U postgres -d donation_db -c "
              GRANT CONNECT ON DATABASE donation_db TO app_donation;
              GRANT USAGE ON SCHEMA public TO app_donation;

              CREATE TABLE IF NOT EXISTS donations (
                  id SERIAL PRIMARY KEY,
                  ngo_id INT NOT NULL,
                  amount NUMERIC(10, 2) NOT NULL,
                  donor_name VARCHAR(100) NOT NULL,
                  status VARCHAR(20) NOT NULL,
                  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
              );

              GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_donation;
              GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_donation;
              ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_donation;
              ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_donation;
            "
            EOF
            , "\r", "")
          ]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 4
  }

  wait_for_completion = true
  depends_on = [
    module.database,
    module.eks
  ]
}
