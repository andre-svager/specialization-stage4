# GitOps Guide — ToggleMaster on GCP

Cluster: `togglemaster-gke` · Zone: `us-central1-a` · Project: `fiap-502903`

This guide covers the GitOps infrastructure for ToggleMaster on GCP using
ArgoCD for continuous deployment: automatic sync, self-healing, and a
common Helm chart shared across all 5 microservices.

## Structure

```
gitops/
├── helm/common-service/         # Single reusable Helm chart for all services
│   ├── templates/                # deployment, service, hpa, secret, serviceaccount
│   ├── values.yaml                # Defaults (database.enabled: false)
│   └── values/                    # Per-service overrides
│       ├── analytics-service.yaml
│       ├── auth-service.yaml
│       ├── evaluation-service.yaml
│       ├── flag-service.yaml
│       └── target-service.yaml
├── apps/                          # ArgoCD Application manifests (app-of-apps)
│   ├── analytics-app.yaml
│   ├── auth-app.yaml
│   ├── evaluation-app.yaml
│   ├── flag-app.yaml
│   ├── target-app.yaml
│   ├── postgres-app.yaml          # Postgres, ArgoCD-managed (sync-wave: -1)
│   └── argocd-root.yaml           # App of Apps — watches this whole folder
├── postgres/                      # Postgres manifests (namespace, secret, configmap, deployment, service)
├── kustomize/                     # dev / staging / prod overlays
├── argocd-namespace.yaml
└── argocd-config.yaml
```

**Key change from the original design:** Postgres was originally provisioned
via a Terraform module (`infra/modules/postgres`). It's now managed entirely
through ArgoCD as a plain Deployment + Service + ConfigMap, like the other
5 services — this avoids a class of Terraform/Kubernetes-provider timing bugs
where the `kubernetes` provider can't reliably be configured from a data
source created in the same apply as the GKE cluster. Terraform now owns only
cloud infra (GKE, networking, IAM, Artifact Registry); GitOps owns everything
running inside the cluster.

## Workflow

```
1. Developer pushes code
2. GitHub Actions: build → test → security scan (Trivy/gosec/bandit) →
   push image to Artifact Registry (us-central1-docker.pkg.dev/fiap-502903/services/SERVICE:SHA)
3. CI updates gitops/helm/common-service/values/SERVICE.yaml with the new tag,
   commits to this repo
4. ArgoCD detects the change, syncs the new image to GKE
5. No manual deployment steps required
```

## Starting ArgoCD

ArgoCD only needs a working GKE cluster — it does **not** depend on the
Workload Identity / IAM setup (that's only needed later, for CI to push
images to Artifact Registry). Install it independently of any pending IAM
work.

**1. Point kubectl at the cluster**
```bash
gcloud container clusters get-credentials togglemaster-gke --zone us-central1-a --project fiap-502903
kubectl get nodes
```

**2. Namespace + ArgoCD config**
```bash
kubectl apply -f gitops/argocd-namespace.yaml
kubectl apply -f gitops/argocd-config.yaml
```

**3. Install ArgoCD (Helm)**
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --version 5.51.0
kubectl get pods -n argocd -w
```

**4. Get the admin password, log in**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# in another terminal:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
argocd login localhost:8080 --username admin --password <password>
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get nodes
kubectl top node
kubectl describe node gke-togglemaster-gke-togglemaster-gke-d0e44a52-uv18 | tail -30
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc argocd-server -n argocd -w
```
UI: `https://localhost:8080`

**5. Connect the GitHub repo** (use a Personal Access Token, not your account password)
```bash
argocd repo add https://github.com/andre-svager/specialization-stage4.git \
  --name gitops-repo \
  --username andre-svager \
  --password <GitHub PAT>
```

**6. Deploy the app-of-apps root**
```bash
kubectl apply -f gitops/apps/argocd-root.yaml
```
`argocd-root` watches `gitops/apps/` with `automated: { prune: true, selfHeal: true }`,
so this single apply cascades into every `Application` manifest in that
folder — all 5 services plus Postgres. No need to `kubectl apply` each one
individually.

**7. Verify**
```bash
argocd app list
kubectl get pods -n db-infra
kubectl get pods -n default
```

## Required GitHub Secrets (for CI → Artifact Registry)

**Step 1 — apply the IAM module** to create the Workload Identity Pool,
Provider, and CI/CD service account:
```bash
cd infra
terraform apply
```

**Step 2 — get the real values** (never use placeholder values):
```bash
terraform output workload_identity_provider
terraform output ci_service_account
```
Expect something like:
- `workload_identity_provider`: `projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`
- `ci_service_account`: `ci-service-account@fiap-502903.iam.gserviceaccount.com`

If `workload_identity_provider` is empty, the IAM module hasn't applied
successfully yet — check for errors before continuing (see Troubleshooting).

**Step 3 — set the repo secrets**
```bash
gh secret set GCP_PROJECT_ID --body "fiap-502903"
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body "<value from step 2>"
gh secret set GCP_SERVICE_ACCOUNT --body "ci-service-account@fiap-502903.iam.gserviceaccount.com"
```
(or via UI: Settings → Secrets and variables → Actions)

## Daily Workflow: Updating a Service

```bash
cd analytics-service
# ... make changes ...
git commit -m "feat: add new analytics feature"
git push origin main
```
Everything else is automatic: CI builds/tests/scans/pushes the image, updates
the GitOps values file, and ArgoCD syncs it to GKE.

```bash
# optional monitoring
argocd app get analytics-service
kubectl rollout status deployment/analytics-service
```

## Validation

```bash
# Health check
kubectl get pods -n default
kubectl port-forward service/analytics-service 8000:8000
curl http://localhost:8000/health

# Self-heal test — delete a pod, ArgoCD should recreate it
kubectl delete pod -l app=analytics-service
kubectl get pods -l app=analytics-service -w

# Manual sync test
kubectl edit deployment analytics-service   # change something
argocd app sync analytics-service
kubectl get deployment analytics-service -o yaml | grep image
```

## Monitoring

```bash
kubectl logs -n argocd -f deployment/argocd-server
kubectl logs -n argocd -f deployment/argocd-application-controller
argocd app list
argocd app list -o json | jq '.[] | {name: .metadata.name, status: .status.operationState.phase}'
```

## Troubleshooting

**Application OutOfSync**
```bash
argocd app sync analytics-service
argocd app diff analytics-service
argocd repo list       # verify repo credentials
```

**Pods stuck Pending / CrashLoopBackOff**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name> --tail=100
kubectl get events -n default --sort-by='.lastTimestamp'
kubectl top nodes
```

**Sync failed**
```bash
kubectl apply -f gitops/apps/ --dry-run=client
helm lint gitops/helm/common-service/
kustomize build gitops/kustomize/overlays/dev
```

**Kubernetes provider errors in Terraform** (`dial tcp 127.0.0.1:80: connect: connection refused`)
This happens if a `kubernetes`/`helm` provider is configured from a data
source tied to a resource (e.g. the GKE cluster) created in the *same*
apply — Terraform evaluates provider blocks before the graph runs, so the
data source can resolve empty. This is why Postgres was moved out of
Terraform entirely (see Structure above). If it recurs elsewhere, either
split into two Terraform states (cluster infra vs. in-cluster resources) or
remove any `depends_on` on the data source once the cluster already exists.

**Workload Identity Federation errors**
- `attribute condition must reference one of the provider's claims` — the
  provider needs both an `attribute_mapping` entry for `attribute.repository`
  and an `attribute_condition` referencing it (Google requires this).
- `member ... is of an unknown type` — the IAM member string must use the
  pool provider's full resource path
  (`google_iam_workload_identity_pool.github_actions.name`), not the short
  `workload_identity_pool_id`.

## Scaling to Production

- Multi-environment: separate ArgoCD Applications per env pointing at
  `gitops/kustomize/overlays/{dev,staging,prod}`, each with its own
  namespace, resource limits, and RBAC.
- Notifications: wire ArgoCD's notification controller to Slack/Teams on
  sync failure.
- Backup: `argocd app list -o yaml > backup-apps.yaml`;
  `kubectl get cm,secret -n argocd -o yaml > backup-argocd.yaml`.

## Security Best Practices

1. Secrets: prefer Sealed Secrets or External Secrets Operator (GCP Secret
   Manager) over plain `Secret` manifests in Git for anything beyond
   coursework.
2. RBAC: admin restricted to platform/SRE, developers get create/sync/get,
   everyone else read-only.
3. Branch protection + required PR review + required status checks.
4. Enable ArgoCD audit logging; monitor changes via Git history.

## Known Gotchas (fixed / to watch)

- **Cluster location is `us-central1-a`** (a zone, not a region). The CI
  workflows (`ci-go-reusable.yml`, `ci-python-reusable.yml`) must reference
  `cluster_name: togglemaster-gke` and `location: us-central1-a` to match —
  double-check these before relying on CI to reach the cluster.
- Postgres init SQL must `CREATE USER` for each service (`auth_service`,
  `flag_service`, `target_service`) in addition to `CREATE DATABASE` —
  services will fail to authenticate otherwise.
- `terraform.tfstate` should live only in the GCS backend
  (`togglemaster-tfstate` bucket) — don't commit local state files or
  `.terraform/` to the repo.

## References

- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://www.gitops.tech/)
- [GKE Docs](https://cloud.google.com/kubernetes-engine)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)


PTHON REUSABLE

- name: Update GitOps repository with new image tag
        env:
          SERVICE_NAME: ${{ inputs.service_name }}
          IMAGE_URI: ${{ env.image_uri }}
          COMMIT_SHA: ${{ github.sha }}
          GITHUB_TOKEN: ${{ secrets.gh_token }}
        run: |
          # Clone GitOps repository
          git clone https://x-access-token:${GITHUB_TOKEN}@github.com/andre-svager/specialization-stage4.git gitops-repo
          cd gitops-repo
          
          # Update image tag in Helm values file
          VALUES_FILE="gitops/helm/common-service/values/${SERVICE_NAME}.yaml"
          if [ -f "$VALUES_FILE" ]; then
            # Update image repository and tag
            yq eval ".image.repository = \"${IMAGE_URI%:*}\"" -i "$VALUES_FILE"
            yq eval ".image.tag = \"${IMAGE_URI##*:}\"" -i "$VALUES_FILE"
            
            # Commit and push changes
            git config user.name "GitHub Actions"
            git config user.email "actions@github.com"
            git add "$VALUES_FILE"
            git commit -m "ci: update ${SERVICE_NAME} image to ${IMAGE_URI##*:}"
            git push origin main
            echo "✓ Updated GitOps repository with new image tag"
          else
            echo "⚠ Values file not found: $VALUES_FILE"
          fi
        continue-on-error: true







Lessons learned

Artifact Registry hostnames use the region, not the zone. The correct format is us-central1-docker.pkg.dev
To find usages

 % find . -path "*/.github/workflows*" -name "*.yml" -exec grep -Hn "us-central1-a" {} \;


kubectl run curl-test --image=curlimages/curl -n default -it --rm -- curl http://auth-service.default.svc.cluster.local:8001/health

kubectl logs flag-service-6cb7bc566-hh8bl -n default --previous --tail=20

kubectl get application flag-service -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}'

git checkout main
git merge feature/gitops
git push origin main
kubectl apply -f gitops/apps/argocd-root.yaml

when resorce not found
kubectl get pods -n default -l app.kubernetes.io/name=evaluation-service

> Verify wty images not pulled from Argocd
kubectl get pods -n default -l app.kubernetes.io/name=evaluation-service

>>> evaluation-service-86cd578c78-l75wh   0/1     CrashLoopBackOff   4 (35s ago)   115s

kubectl describe pod <pod-name> -n default | grep -i image
>>>
´´´
     Image:          us-central1-docker.pkg.dev/fiap-502903/evaluation-service/evaluation-service:latest
    Image ID:       us-central1-docker.pkg.dev/fiap-502903/evaluation-service/evaluation-service@sha256:9029d53f9e15da88b7f3fb77642f9fa40f2e3b306308835438ed4478f8d03446
  Normal   Pulled     96s (x6 over 4m30s)   kubelet            Container image "us-central1-docker.pkg.dev/fiap-502903/evaluation-service/evaluation-service:latest" already present on machine and can be accessed by the pod
´´´

configure user and pass locally
git config --global credential.helper store


grep -A3 "^image:" gitops/helm/common-service/values/evaluation-service.yaml
image: repository: us-central1-docker.pkg.dev/fiap-502903/evaluation-service/evaluation-service
podAnnotations:

grep "pullPolicy" gitops/helm/common-service/values.yaml gitops/helm/common-service/templates/deployment.yaml
gitops/helm/common-service/values.yaml:  pullPolicy: IfNotPresent


git add gitops/helm/common-service/templates/serviceaccount.yaml gitops/helm/common-service/values/analytics-service.yaml
git commit -m "fix: bind analytics-service KSA to GCP service account via workload identity"
git push origin main
git pull origin main --no-rebase
git push origin main
 kubectl apply -f gitops/apps/argocd-root.yaml