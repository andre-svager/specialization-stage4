# Observability & Self-Healing Implementation Plan

This plan implements a comprehensive observability stack with Prometheus, Loki, Grafana, OpenTelemetry, Datadog APM, OpsGenie incident management, Discord notifications, and GitHub Actions-based self-healing for the ToggleMaster microservices application.

## Architecture Overview

**Monitoring Stack (via Helm/ArgoCD):**
- Prometheus: Metrics collection and storage (ephemeral, no persistence)
- Loki: Centralized log aggregation (ephemeral, no persistence)  
- Grafana: Dashboarding with custom dashboards (internal access, optional port-forward for visualization)

**Telemetry Pipeline:**
- OpenTelemetry Collector: Central routing for metrics, logs, traces
- Receives telemetry from services → processes → forwards to Prometheus, Loki, Datadog

**APM & Tracing:**
- Datadog APM (education tier) for distributed tracing
- OpenTelemetry SDK instrumentation in microservices
- Service map visualization for all 5 microservices

**Alerting & Self-Healing:**
- Prometheus AlertManager for alert rules
- OpsGenie for incident management
- Discord webhook for notifications
- GitHub Actions webhook for automated self-healing (kubectl rollout restart)

## Implementation Phases

### Phase 1: Monitoring Stack Deployment (Helm/ArgoCD)

**1.1 Create monitoring namespace and Helm charts**
- Create `gitops/monitoring/` directory structure
- Add ArgoCD Application for monitoring stack
- Deploy Prometheus via kube-prometheus-stack Helm chart
- Deploy Loki via Loki Stack Helm chart
- Deploy Grafana (included in kube-prometheus-stack)

**1.2 Configure Prometheus**
- Enable ServiceMonitor CRD
- Configure service discovery for existing services
- Set up scraping for all 5 microservices (auth, analytics, evaluation, flag, target)
- Configure retention to ephemeral (no PVC)

**1.3 Configure Loki**
- Deploy Loki with promtail for log collection
- Configure log scraping from all pods
- Set up log parsing and labels
- Configure retention to ephemeral (no PVC)

**1.4 Configure Grafana**
- Create admin credentials secret
- Configure Prometheus and Loki datasources
- Create custom dashboard showing:
  - Cluster resource usage (CPU, memory, storage)
  - Microservice request rates (RPS, latency)
  - Real-time logs from Loki
  - Service health status

**1.5 Add to GitOps**
- Create `gitops/apps/monitoring-app.yaml` ArgoCD Application
- Configure sync policy for automated deployment

### Phase 2: OpenTelemetry Collector Deployment

**2.1 Deploy OpenTelemetry Collector**
- Add OTel Collector Helm chart to monitoring stack
- Configure receivers:
  - OTLP (for application telemetry)
  - Prometheus (for metrics scraping)
  - Filelog (for log collection)

**2.2 Configure exporters**
- Prometheus exporter for metrics
- Loki exporter for logs
- Datadog exporter for traces and metrics

**2.3 Configure processors**
- Batch processor for efficient data transmission
- Resource processor to add service metadata
- Attributes processor for enrichment

**2.4 GitOps integration**
- Add OTel Collector to monitoring ArgoCD Application
- Configure service discovery for automatic endpoint detection

### Phase 3: Datadog APM Integration

**3.1 Datadog Agent Deployment**
- Deploy Datadog Agent via Helm chart
- Configure Datadog API key (education tier)
- Enable APM and trace collection
- Configure log collection integration

**3.2 Application Instrumentation**
- Add OpenTelemetry SDK dependencies to all services:
  - Go services (auth, evaluation): `go.opentelemetry.io/...`
  - Python services (analytics, flag, target): `opentelemetry-api`, `opentelemetry-sdk`

**3.3 Instrument auth-service (Go)**
- Add OTel HTTP middleware
- Configure span naming and attributes
- Add custom metrics for authentication events
- Export traces to OTel Collector

**3.4 Instrument evaluation-service (Go)**
- Add OTel HTTP middleware
- Add span attributes for flag evaluation
- Instrument PubSub message processing
- Export traces to OTel Collector

**3.5 Instrument Python services (analytics, flag, target)**
- Add OTel auto-instrumentation
- Configure Flask/FastAPI instrumentation
- Add custom metrics for business logic
- Export traces to OTel Collector

**3.6 Service Map Configuration**
- Configure Datadog service mapping
- Set up service dependencies
- Enable distributed tracing across all 5 services
- Verify complete service map in Datadog UI

### Phase 4: Alerting Configuration

**4.1 Prometheus Alert Rules**
- Create alert rule for high error rates:
  ```yaml
  - alert: HighErrorRateAuth
    expr: rate(http_requests_total{service="auth-service",status=~"5.."}[5m]) > 0.05
    annotations:
      summary: "Auth service error rate > 5%"
  ```
- Add alerts for:
  - High latency (p95 > 1s)
  - High CPU usage (> 80%)
  - High memory usage (> 80%)
  - Pod restarts
  - Service down

**4.2 AlertManager Configuration**
- Configure AlertManager receiver for OpsGenie
- Set up alert routing based on severity
- Configure alert grouping and inhibition
- Add alert templates for Discord notifications

**4.3 OpsGenie Integration**
- Create OpsGenie API key
- Configure AlertManager webhook to OpsGenie
- Set up OpsGenie integration for incident creation
- Configure escalation rules
- Add on-call schedules

**4.4 Discord Integration**
- Create Discord webhook URL
- Configure AlertManager to send alerts to Discord
- Format alert messages for Discord
- Add service-specific channels if needed

### Phase 5: Self-Healing Automation

**5.1 GitHub Actions Webhook Setup**
- Create GitHub Actions workflow for self-healing
- Configure webhook trigger from AlertManager
- Add repository_dispatch event type
- Set up authentication token

**5.2 Self-Healing Workflow**
- Create `.github/workflows/self-healing.yml`:
  ```yaml
  on: 
    repository_dispatch:
      types: [alert-triggered]
  jobs:
    restart-deployment:
      runs-on: ubuntu-latest
      steps:
        - name: Configure kubectl
        - name: Restart affected deployment
          run: kubectl rollout restart deployment/${{ github.event.client_payload.service }}
  ```

**5.3 AlertManager Webhook Configuration**
- Configure AlertManager to call GitHub Actions webhook
- Include service name and alert details in payload
- Add authentication headers
- Test webhook delivery

**5.4 Self-Healing Logic**
- Implement restart logic for different alert types:
  - High error rate → restart deployment
  - High CPU → scale up HPA
  - Pod crash → restart pod
- Add cooldown period to prevent flapping
- Log all self-healing actions

### Phase 6: Documentation & Testing

**6.1 Documentation**
- Update GitOps guide with monitoring stack
- Create Datadog integration guide
- Document alert rules and thresholds
- Create self-healing runbook

**6.2 Testing**
- Test Prometheus metrics collection
- Verify Loki log aggregation
- Test Grafana dashboards
- Verify Datadog APM traces
- Test alert generation
- Test OpsGenie incident creation
- Test Discord notifications
- Test self-healing webhook
- Perform end-to-end self-healing demo

**6.3 Demo Preparation**
- Prepare cluster status overview
- Set up Grafana dashboard views
- Configure Loki log views
- Prepare Datadog service map
- Set up alert trigger test
- Prepare self-healing demonstration

## File Structure

```
gitops/
├── monitoring/
│   ├── prometheus/
│   │   ├── values.yaml
│   │   └── alert-rules.yaml
│   ├── loki/
│   │   └── values.yaml
│   ├── grafana/
│   │   ├── values.yaml
│   │   └── dashboards/
│   │       └── toggle-master-dashboard.json
│   └── otel-collector/
│       └── values.yaml
├── apps/
│   └── monitoring-app.yaml
└── datadog/
    └── datadog-agent/
        └── values.yaml

.github/
└── workflows/
    └── self-healing.yml

services/
├── auth-service/ (add OTel instrumentation)
├── evaluation-service/ (add OTel instrumentation)
├── analytics-service/ (add OTel instrumentation)
├── flag-service/ (add OTel instrumentation)
└── target-service/ (add OTel instrumentation)
```

## Required Secrets

- **Datadog**: DD_API_KEY (education tier)
- **OpsGenie**: OPSGENIE_API_KEY
- **Discord**: DISCORD_WEBHOOK_URL
- **GitHub Actions**: GH_TOKEN for kubectl access
- **Grafana**: GRAFANA_ADMIN_PASSWORD

## Implementation Order

1. Deploy monitoring stack (Prometheus, Loki, Grafana) via ArgoCD
2. Deploy OpenTelemetry Collector
3. Deploy Datadog Agent
4. Instrument application code with OTel SDKs
5. Configure Prometheus alert rules
6. Set up OpsGenie integration
7. Configure Discord notifications
8. Implement GitHub Actions self-healing
9. Create Grafana dashboards
10. Test end-to-end observability and self-healing

## Success Criteria

- ✅ All 5 microservices instrumented with OTel
- ✅ Prometheus collecting metrics from all services
- ✅ Loki aggregating logs from all services
- ✅ Grafana dashboard showing cluster and service metrics
- ✅ Datadog APM showing complete service map
- ✅ Distributed tracing working across services
- ✅ Alert rules triggering on high error rates
- ✅ OpsGenie creating incidents from alerts
- ✅ Discord receiving alert notifications
- ✅ Self-healing restarting deployments on alerts
- ✅ Demo video showing all components working
