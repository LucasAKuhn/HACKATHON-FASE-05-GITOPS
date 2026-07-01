<#
============================================================================
 gerar-carga-demo.ps1  —  Geracao de carga e demo de SRE (SolidaryTech)
 VERSAO 2 — corrigida com os paths REAIS do Ingress (/donations)
============================================================================
 OBJETIVO
   Gera trafego real no donation-service (via Ingress-NGINX) para popular o
   dashboard de SRE com Latencia, Trafego, Erros e Saturacao. Opcionalmente
   injeta um pico de erros 5xx (escalando o servico para 0 por alguns
   segundos) para evidenciar o consumo do Error Budget e o auto-healing.

 PRE-REQUISITOS
   - Ambiente de pe (Fases 1 a 6 do roteiro-de-testes.md concluidas).
   - kubectl conectado ao cluster.
   - O endereco do Ingress:  kubectl get ingress -n solidarytech

 USO
   1) Descubra o endereco do Ingress:
        kubectl get ingress -n solidarytech
   2) Rode a carga (ajuste o ADDRESS):
        .\gerar-carga-demo.ps1 -Address "a1b2c3.us-east-1.elb.amazonaws.com"
   3) Para tambem injetar o pico de erros (recomendado para a gravacao):
        .\gerar-carga-demo.ps1 -Address "..." -InjetarErro

 NOTA SOBRE OS PATHS (confirmados no manifesto 04-ingress.yaml)
   O Ingress roteia por PREFIXO, sem rewrite:
     GET  /donations   -> lista doacoes (leitura no RDS)
     POST /donations   -> cria doacao   (escrita no RDS + evento no SQS)
   O endpoint /health NAO e exposto pelo Ingress (e usado so pela liveness
   probe interna), por isso a carga e feita direto em /donations.
============================================================================
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Address,

    [string]$DonationsPath = "/donations",
    [string]$Deployment    = "donation-service",
    [string]$Namespace     = "solidarytech",

    [int]$DuracaoSegundos = 180,
    [int]$QPS             = 60,
    [int]$Conexoes        = 25,

    [switch]$InjetarErro
)

$ErrorActionPreference = "Stop"
$baseUrl      = "http://$Address"
$donationsUrl = "$baseUrl$DonationsPath"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Geracao de carga - donation-service (SolidaryTech)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Ingress   : $baseUrl"
Write-Host " Donations : $donationsUrl"
Write-Host " Carga     : $QPS qps | $Conexoes conexoes | ${DuracaoSegundos}s por fase"
Write-Host " Injetar erro: $InjetarErro"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# FASE 1 - Trafego de leitura (GET /donations)
Write-Host "[FASE 1] Trafego de leitura (GET /donations) por ${DuracaoSegundos}s..." -ForegroundColor Yellow
kubectl run fortio-get --rm -it --image=fortio/fortio --restart=Never -- `
    load -qps $QPS -t "${DuracaoSegundos}s" -c $Conexoes $donationsUrl

# FASE 2 - Carga de escrita (POST /donations)
$payload = '{"ngo_id":1,"amount":50.0,"donor_name":"LoadTest"}'
Write-Host ""
Write-Host "[FASE 2] Carga de escrita (POST /donations) por ${DuracaoSegundos}s..." -ForegroundColor Yellow
kubectl run fortio-post --rm -it --image=fortio/fortio --restart=Never -- `
    load -qps $QPS -t "${DuracaoSegundos}s" -c $Conexoes `
    -X POST -payload $payload -content-type "application/json" $donationsUrl

# FASE 3 (opcional) - Injecao de erro 5xx + auto-healing
if ($InjetarErro) {
    Write-Host ""
    Write-Host "[FASE 3] INJECAO DE ERRO - escalando $Deployment para 0 replicas..." -ForegroundColor Red

    Start-Job -Name "carga-erro" -ScriptBlock {
        param($qps, $conexoes, $url, $payload)
        kubectl run fortio-erro --rm -i --image=fortio/fortio --restart=Never -- `
            load -qps $qps -t "40s" -c $conexoes -X POST -payload $payload `
            -content-type "application/json" $url
    } -ArgumentList $QPS, $Conexoes, $donationsUrl, $payload | Out-Null

    kubectl scale deploy $Deployment -n $Namespace --replicas=0
    Write-Host "  -> Servico fora do ar. Aguardando 20s (observe os 5xx subindo no Grafana)..." -ForegroundColor Red
    Start-Sleep -Seconds 20

    Write-Host "  -> Restaurando o servico (auto-healing)..." -ForegroundColor Green
    kubectl scale deploy $Deployment -n $Namespace --replicas=2
    kubectl rollout status deploy $Deployment -n $Namespace --timeout=120s

    Write-Host "  -> Servico restaurado. Error Budget consumido registrado no dashboard." -ForegroundColor Green
    Get-Job -Name "carga-erro" | Wait-Job | Remove-Job
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Carga concluida. Abra o Grafana e grave os takes do dashboard." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
