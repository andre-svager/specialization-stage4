# GitOps Guide - GCP Migration Complete

## 📋 Overview

with this gitops_guide is possible recreate current /gitops structure in another prompt ? 

This guide covers the complete GitOps infrastructure for ToggleMaster on Google Cloud Platform using ArgoCD for continuous deployment. The infrastructure follows GitOps best practices with automatic synchronization, self-healing, and monitoring.

## 🏗️ Current Structure

```
gitops/
├── helm/
│   └── common-service/          # Single reusable Helm chart for all services
│       ├── Chart.yaml           # Chart metadata
│       ├── templates/          # Kubernetes templates
│       │   ├── deployment.yaml  # Generic deployment
│       │   ├── service.yaml     # Service configuration
│       │   ├── hpa.yaml         # Horizontal Pod Autoscaler
│       │   ├── serviceaccount.yaml
│       │   ├── secret.yaml
│       │   └── _helpers.tpl     # Template helpers
│       ├── values.yaml          # Default values
│       └── values/              # Service-specific overrides
│           ├── analytics-service.yaml
│           ├── auth-service.yaml
│           ├── evaluation-service.yaml
│           ├── flag-service.yaml
│           └── target-service.yaml
├── apps/                        # ArgoCD Application manifests
│   ├── analytics-app.yaml       # Analytics service deployment
│   ├── auth-app.yaml            # Auth service deployment
│   ├── evaluation-app.yaml      # Evaluation service deployment
│   ├── flag-app.yaml            # Flag service deployment
│   ├── target-app.yaml          # Target service deployment
│   └── argocd-root.yaml         # App of Apps pattern
├── kustomize/                   # Environment-specific configurations
│   ├── base/                    # Base configuration
│   │   └── kustomization.yaml   # References common-service chart
│   └── overlays/                # Environment overrides
│       ├── dev/                 # Development environment
│       ├── staging/             # Staging environment
│       └── prod/                # Production environment
├── argocd-namespace.yaml        # ArgoCD namespace definition
├── argocd-config.yaml           # ArgoCD configuration
└── GITOPS_GUIDE.md             # This comprehensive guide
```

## 🚀 Key Features

- **Common Helm Chart**: Single reusable chart for all microservices (DRY principle)
- **ArgoCD Applications**: Individual application manifests for each service
- **Kustomize Overlays**: Environment-specific configurations (dev/staging/prod)
- **GCP Integration**: Optimized for Google Cloud Platform deployment
- **Pod-based Postgres**: Database running as Kubernetes pods (no external RDS)

## 🔄 GitOps Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                   GITOPS WORKFLOW - GCP                         │
└─────────────────────────────────────────────────────────────────┘

1. DEVELOPMENT
   └─ Developer modifies application code (ex: analytics-service)

2. CI/CD PIPELINE (GitHub Actions)
   ├─ Build Docker image
   ├─ Run tests
   ├─ Push to Artifact Registry: us-central1-docker.pkg.dev/PROJECT_ID/services/SERVICE_NAME:COMMIT_SHA
   └─ Update GitOps repository with new image tag

3. GIT REPOSITORY (GitOps Repo)
   ├─ Kubernetes manifests (gitops/apps/)
   ├─ Helm Charts (gitops/helm/common-service/)
   ├─ Kustomize bases and overlays
   └─ ArgoCD configurations

4. ARGOCD MONITORING
   ├─ ArgoCD detects repository changes
   ├─ Compares desired (repo) vs actual (cluster)
   └─ Automatic synchronization initiated

5. KUBERNETES CLUSTER (GKE)
   ├─ New Docker image pulled from Artifact Registry
   ├─ Pods replaced with new version
   ├─ Health checks pass
   └─ Traffic routed to new pods

6. OBSERVABILITY
   ├─ Logs from new pods
   ├─ Performance metrics
   ├─ Alerts and notifications
   └─ ArgoCD records final state
```

## 🤖 Automated CI/CD with ArgoCD

### Zero-Touch Deployment Pipeline

The complete CI/CD workflow is fully automated with no manual Docker deployment required:

**Pipeline Steps:**

1. **Code Push** - Developer pushes code to GitHub
2. **GitHub Actions Trigger** - CI pipeline starts automatically
3. **Build & Test** - Service builds and runs tests
4. **Security Scanning** - Trivy, gosec/bandit security scans
5. **Push to Artifact Registry** - Image pushed to `us-central1-docker.pkg.dev/fiap-502903/services/SERVICE_NAME:COMMIT_SHA`
6. **Update GitOps Repository** - CI automatically updates Helm values file with new image tag
7. **ArgoCD Auto-Sync** - ArgoCD detects GitOps repository change and deploys to GKE

### Required GitHub Secrets

Configure these in your GitHub repository settings:

```
GCP_PROJECT_ID: fiap-502903
GCP_WORKLOAD_IDENTITY_PROVIDER: projects/PROJECT_ID/locations/global/workloadIdentityPools/POOL/providers/PROVIDER
GCP_SERVICE_ACCOUNT: ci-service-account@fiap-502903.iam.gserviceaccount.com
GITHUB_TOKEN: (default GitHub token - no configuration needed)
```

### How It Works

**No manual Docker deployment needed.** The CI pipeline:

1. **Builds** your Docker image with Go/Python toolchain
2. **Scans** for security vulnerabilities (Trivy, gosec, bandit)
3. **Pushes** to Google Artifact Registry using Workload Identity
4. **Updates** `gitops/helm/common-service/values/SERVICE_NAME.yaml` with new image tag
5. **Commits** the change to the GitOps repository using GitHub token
6. **ArgoCD** automatically detects the change and syncs to GKE

### CI Pipeline Features

**Go Services (auth, evaluation):**
- Go 1.21 with dependency caching
- golangci-lint for linting
- gosec for security scanning
- Unit tests with race detector
- Coverage reporting to Codecov
- Trivy filesystem and image scanning

**Python Services (analytics, flag, target):**
- Python 3.11 with pip caching
- black/isort/flake8 for linting
- bandit for security scanning
- pytest for unit tests
- Coverage reporting to Codecov
- Trivy filesystem and image scanning

### ArgoCD Configuration

Your ArgoCD applications in `gitops/apps/` are configured to:
- Monitor the GitOps repository (`specialization-stage4.git`)
- Auto-sync on changes (automated sync policy)
- Use the common-service Helm chart
- Deploy to your GKE cluster (`togglemaster` in `us-central1`)
- Self-heal any manual modifications

### Benefits

- ✅ **Zero-touch deployment** - No manual Docker commands
- ✅ **GitOps compliance** - All changes tracked in Git
- ✅ **Automatic rollback** - Revert Git commit to rollback deployment
- ✅ **Multi-environment** - Use Kustomize overlays for dev/staging/prod
- ✅ **Self-healing** - ArgoCD maintains desired state
- ✅ **Security-first** - Automated vulnerability scanning
- ✅ **Workload Identity** - No hardcoded credentials
- ✅ **Audit trail** - Complete deployment history in Git

### Example Workflow

```bash
# Developer makes changes
git commit -m "feat: add new feature"
git push origin main

# GitHub Actions automatically:
# 1. Builds Docker image
# 2. Runs tests and security scans
# 3. Pushes to Artifact Registry
# 4. Updates gitops/helm/common-service/values/analytics-service.yaml
# 5. Commits change to GitOps repository

# ArgoCD automatically:
# 6. Detects GitOps repository change
# 7. Syncs new image to GKE cluster
# 8. Rolls out new deployment

# No manual intervention required!
```

## 🛠️ ArgoCD Setup for GKE

### Prerequisites

- GKE cluster running on Google Cloud Platform
- kubectl configured to connect to your GKE cluster
- Helm 3.x installed locally
- gcloud CLI installed and authenticated

### Installation Steps

#### 1. Install ArgoCD on GKE

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD using the official Helm chart
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd --namespace argocd --version 5.51.0

# Alternative: Install using kubectl
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### 2. Apply ArgoCD Configuration

```bash
# Apply namespace and configuration
kubectl apply -f gitops/argocd-namespace.yaml
kubectl apply -f gitops/argocd-config.yaml
```

#### 3. Access ArgoCD UI

```bash
# Port forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Default username: admin
# Get initial password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### 4. Configure Git Repository

```bash
# Login to ArgoCD CLI
argocd login localhost:8080 --username admin --password <initial-password>

# Add your Git repository
argocd repo add https://github.com/andre-svager/specialization-stage4.git \
  --name gitops-repo \
  --username andre-svager \
  --password <MY_PASS>

# Or configure via ArgoCD UI:
# Settings → Repositories → Connect Repo → HTTPS
# URL: https://github.com/andre-svager/specialization-stage4.git
```

#### 5. Deploy Applications

```bash
# Deploy individual applications
kubectl apply -f gitops/apps/analytics-app.yaml
kubectl apply -f gitops/apps/auth-app.yaml
kubectl apply -f gitops/apps/evaluation-app.yaml
kubectl apply -f gitops/apps/flag-app.yaml
kubectl apply -f gitops/apps/target-app.yaml

# Or deploy all at once
kubectl apply -f gitops/apps/
```

#### 6. Configure Workload Identity (Optional but Recommended)

```bash
# Create IAM service account for ArgoCD
gcloud iam service-accounts create argocd-sa \
  --project=PROJECT_ID \
  --display-name="ArgoCD Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:argocd-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# Configure Workload Identity
gcloud iam service-accounts add-iam-policy-binding argocd-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[argocd/argocd-server]"

# Annotate ArgoCD service account
kubectl annotate serviceaccount argocd-server -n argocd \
  iam.gke.io/gcp-service-account=argocd-sa@PROJECT_ID.iam.gserviceaccount.com
```

## 📝 Configuration Details

### Helm Chart Configuration

The `common-service` chart provides a single reusable template for all microservices:

**Key Parameters:**
- `serviceName`: Service name (analytics, auth, evaluation, flag, target)
- `image.repository`: Container image repository (GCR)
- `image.tag`: Container image tag
- `service.targetPort`: Service port
- `replicaCount`: Number of replicas
- `autoscaling.enabled`: Enable HPA
- `database.enabled`: Enable database configuration
- `database.secretName`: External database secret (optional)

**Service-Specific Values:**
Each service has its own values file in `values/` directory with:
- Image repository and tag
- Service ports
- Resource limits/requests
- Autoscaling configuration
- Environment variables
- Database configuration

### ArgoCD Application Configuration

Each application in `apps/` defines:
- **Source**: Git repository, path to Helm chart, values files
- **Destination**: Kubernetes cluster, namespace
- **Sync Policy**: Auto-sync, self-heal, prune
- **Release Name**: Unique Helm release name

**Example (analytics-app.yaml):**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: analytics-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/andre-svager/specialization-stage4.git
    targetRevision: main
    path: gitops/helm/common-service
    helm:
      releaseName: analytics-service
      valueFiles:
        - values/analytics-service.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Kustomize Configuration

**Base Configuration:**
- References the common-service Helm chart
- Applies common labels and annotations
- Generates default ConfigMaps and Secrets

**Environment Overlays:**
- **dev**: Development environment with minimal resources
- **staging**: Staging environment with moderate resources
- **prod**: Production environment with high availability and pod anti-affinity

## 🔄 Daily Workflow: Updating a Service

### Scenario: Update Analytics Service

**Manual Workflow (Old Way):**
```bash
# 1. Modify code
cd analytics-service
# ... make changes ...
git commit -m "feat: add new analytics feature"
git push origin main

# 2. CI Pipeline (GitHub Actions)
# - Build: docker build -t gcr.io/PROJECT_ID/analytics-service:v1.2.3 .
# - Test: pytest
# - Push: docker push gcr.io/PROJECT_ID/analytics-service:v1.2.3
# - Update: Push to GitOps repo with new tag

# 3. Update GitOps repository
cd gitops/helm/common-service/values
# Update image tag in analytics-service.yaml
git commit -m "ci: update analytics-service to v1.2.3"
git push origin main

# 4. ArgoCD detects and synchronizes automatically
# (verifiable in UI or with)
argocd app list

# 5. Validate deployment
kubectl rollout status deployment/analytics-service
kubectl logs -l app=analytics-service
```

**Automated Workflow (New Way):**
```bash
# 1. Modify code
cd analytics-service
# ... make changes ...
git commit -m "feat: add new analytics feature"
git push origin main

# That's it! Everything else happens automatically:
# - GitHub Actions builds, tests, scans, and pushes image
# - CI updates GitOps repository with new image tag
# - ArgoCD detects change and deploys to GKE
# - No manual steps required

# 2. Monitor deployment (optional)
argocd app get analytics-service
kubectl rollout status deployment/analytics-service
```

## 🧪 Validation and Testing

### Test 1: Health Check Services

```bash
# Verify ready pods
kubectl get pods -n default

# Verify endpoints
kubectl get endpoints

# Make request to service
kubectl port-forward service/analytics-service 8000:8000
curl http://localhost:8000/health
```

### Test 2: Simulate Pod Failure

```bash
# Delete a pod (ArgoCD should recreate it)
kubectl delete pod -l app=analytics-service

# Verify recreation
kubectl get pods -l app=analytics-service -w

# Confirm auto-healing worked
# (Pod should return in few seconds)
```

### Test 3: Manual Synchronization

```bash
# Deliberately desync
kubectl edit deployment analytics-service
# Remove a label or change image

# Force synchronization in ArgoCD
argocd app sync analytics-service

# Verify it returned to desired state
kubectl get deployment analytics-service -o yaml | grep image
```

## 📊 Continuous Monitoring

### ArgoCD Logs

```bash
# Server
kubectl logs -n argocd -f deployment/argocd-server

# Controller
kubectl logs -n argocd -f deployment/argocd-application-controller

# Repo Server
kubectl logs -n argocd -f deployment/argocd-repo-server
```

### Application Status

```bash
# List all with status
argocd app list

# JSON for parsing
argocd app list -o json | jq '.[] | {name: .metadata.name, status: .status.operationState.phase}'

# Watch in real-time
argocd app list -w
```

### Kubernetes Events

```bash
# View deployment events
kubectl describe deployment analytics-service

# View cluster events
kubectl get events -n default --sort-by='.lastTimestamp' | tail -20
```

## 🚨 Common Troubleshooting

### Application OutOfSync

**Problem**: Application shows "OutOfSync" status

**Solution 1**: Manual synchronization
```bash
argocd app sync analytics-service
```

**Solution 2**: Check differences
```bash
argocd app diff analytics-service
```

**Solution 3**: Verify repository credentials
```bash
argocd repo list
```

### Pods Not Starting

**Problem**: Pods stuck in "Pending" or "CrashLoopBackOff"

**Debug**:
```bash
# View detailed status
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name> --tail=100

# View events
kubectl get events -n default --sort-by='.lastTimestamp'

# Check available resources
kubectl top nodes
kubectl describe nodes
```

### Synchronization Error

**Problem**: "sync failed"

**Verify**:
```bash
# Validate manifests
kubectl apply -f gitops/apps/ --dry-run=client

# Validate Helm charts
helm lint gitops/helm/common-service/

# Test kustomize
kustomize build gitops/kustomize/overlays/dev
```

## 📈 Scaling to Production

### 1. Multi-Environment (Dev → Staging → Prod)

```bash
# ArgoCD Applications per environment
- dev-analytics (points to gitops/kustomize/overlays/dev)
- staging-analytics (points to gitops/kustomize/overlays/staging)
- prod-analytics (points to gitops/kustomize/overlays/prod)

# Each environment with:
- Separate namespace
- Different resources
- Different RBAC policies
- Specific notifications
```

### 2. Notifications

Configure notifications for Slack/Teams:

```yaml
# Add to ArgoCD ConfigMap
trigger.on-sync-failed: |
  message: Application {{.app.metadata.name}} sync failed
  slack:
    attachments: |
      [{
        "text": "{{.app.status.operationState.finishedAt}}"
      }]
```

### 3. Backup and Disaster Recovery

```bash
# Backup Applications
argocd app list -o yaml > backup-apps.yaml

# Backup ArgoCD Config
kubectl get cm,secret -n argocd -o yaml > backup-argocd.yaml

# Restore
kubectl apply -f backup-apps.yaml
kubectl apply -f backup-argocd.yaml
```

## 🔐 Security Best Practices

1. **Secrets Management**
   - Use Sealed Secrets for Git
   - Use External Secrets Operator for GCP Secret Manager
   - Never commit credentials

2. **RBAC**
   - Admin: only SRE/Platform team
   - Developer: create/sync/get apps
   - Readonly: view only

3. **Repository Protections**
   - Branch protection rules
   - Require PR reviews
   - Require status checks

4. **Audit Logging**
   - Enable ArgoCD audit logging
   - Monitor changes via Git history
   - Setup alerts for suspicious changes

## 📝 Migration Notes

- **Removed AWS-specific**: IAM policies, ECR references, RDS configurations
- **Consolidated Helm**: From 5 separate charts to 1 common chart
- **Updated ArgoCD apps**: To use common-service chart
- **Simplified Kustomize**: For GCP compatibility
- **Pod-based Postgres**: Database running as Kubernetes pods
- **GCP Integration**: Optimized for Google Cloud Platform

## 📚 References

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://www.gitops.tech/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
