# Terraform + GitOps Implementation Plan for the GCP Migration

This document turns the migration checklist from [AWS_TO_GCP_MIGRATION.md](AWS_TO_GCP_MIGRATION.md) into a practical implementation plan for the current repository structure, using the existing Terraform modules under [infra/modules](infra/modules) and the GitOps assets under [gitops](gitops).

## 1. Executive Summary

The current Terraform code is AWS-specific and must be reworked for Google Cloud Platform. The existing repository already contains a strong base for:

- Terraform module organization under [infra](infra)
- Kubernetes deployment assets under [gitops/helm](gitops/helm)
- ArgoCD application definitions under [gitops/apps](gitops/apps)

The migration should therefore follow a phased approach:

1. Replace the AWS provider and resources with GCP equivalents.
2. Provision the platform services required by the five stage services.
3. Deploy the services through ArgoCD and Helm.
4. Validate end-to-end communication between services, databases, and messaging.

---

## 2. Validation of the Migration Document Items

| Migration topic | Status | Implementation note |
|---|---|---|
| Infrastructure and networking | Partial | The existing networking module is AWS-based. It must be rewritten using GCP VPC, subnets, Cloud Router, Cloud NAT, and firewall rules. |
| Terraform remote state | Partial | The repository currently uses an AWS S3 backend. It should be migrated to a GCS backend with versioning and state locking. |
| IAM and service accounts | Partial | The current Terraform does not include GCP service accounts or Workload Identity. These must be added. |
| Kubernetes migration from EKS to GKE | Partial | The existing EKS module needs to be replaced with a GKE module. |
| PostgreSQL migration | Partial | The documentation suggests a PostgreSQL pod, but for production the recommended target is Cloud SQL for PostgreSQL. |
| Redis migration | Partial | The current Terraform provisions ElastiCache. It should be rewritten to provision Memorystore for Redis. |
| DynamoDB to Firestore | Partial | The current Terraform provisions DynamoDB, while the app code uses AWS SDKs. This requires both infrastructure and application changes. |
| Container registry migration | Partial | The existing ECR module must be replaced with Artifact Registry repositories. |
| Messaging migration | Partial | SQS must be replaced with Pub/Sub, and the application code must be adapted. |
| CI/CD migration | Partial | The repository has no GCP-based CI pipeline yet. GitHub Actions should be added with GCP authentication and Artifact Registry publishing. |
| GitOps repository setup | Partial | The repository already contains GitOps assets, but they must be aligned to GKE, GCP image repositories, and GCP-managed dependencies. |
| ArgoCD installation on GKE | Partial | The ArgoCD assets are present, but they must be validated for the GKE environment and cluster access. |
| Automatic image tag update | Partial | The GitOps workflow should be enhanced to update Helm values or manifests with the new image tag. |
| Auto-sync and GitOps rollout | Partial | ArgoCD application definitions already exist and can be extended with automated sync and health checks. |
| Security and secrets | Partial | Kubernetes secrets and GCP Secret Manager should be integrated. |
| Monitoring and logging | Partial | This is currently not covered by the Terraform modules and should be introduced as a later phase. |
| Testing and validation | Partial | The repository has testing scripts under [gitops/tests](gitops/tests), but they must be updated for GKE and GCP resources. |

---

## 3. Recommended Target Architecture

### 3.1 Infrastructure

Provision the following GCP resources:

- VPC and subnets
- Cloud Router and Cloud NAT
- Firewall rules
- GKE cluster and node pools
- Containerized PostgreSQL deployment inside the cluster for:
  - auth-service
  - flag-service
  - target-service
- Memorystore for Redis
- Firestore database
- Pub/Sub topic and subscription for evaluation events
- Artifact Registry repositories for all services
- GCP service accounts and Workload Identity
- GCS bucket for Terraform state

The PostgreSQL choice is intentional: the team requested a containerized deployment, so the implementation should use a Kubernetes StatefulSet or Helm-managed PostgreSQL deployment rather than Cloud SQL. This keeps the architecture aligned with the current repository style and avoids introducing a heavier managed database dependency for the first rollout.

### 3.2 Application Platform

Deploy the following services through Kubernetes and ArgoCD:

- analytics-service
- auth-service
- evaluation-service
- flag-service
- target-service

Use Helm charts from [gitops/helm](gitops/helm) as the deployment mechanism and ArgoCD applications from [gitops/apps](gitops/apps) for reconciliation.

For the GitOps model, the current [gitops](gitops) directory should be treated as a bootstrap and reference implementation only. It is not the recommended long-term source of truth because it mixes infrastructure, application deployment assets, and environment-specific configuration in one place. The preferred model is a dedicated GitOps repository, for example:

- togglemaster-gitops

That repository should contain only:

- Helm values and environment overlays
- ArgoCD Application manifests
- Kubernetes secrets templates or secret references
- Deployment policies and sync configuration

Terraform should remain in the main application repository, while the GitOps repository becomes the declarative runtime state for the cluster.

---

## 4. Implementation Plan by Phase

### Phase 0 - Prepare the repository for GCP

Deliverables:

- Create a GCP-compatible Terraform provider configuration.
- Replace the AWS backend with a GCS backend.
- Add variables for GCP project, region, zone, and environment naming.
- Define a naming convention for all resources.

Actions:

- Update [infra/provider.tf](infra/provider.tf) to use the Google provider.
- Update [infra/variables.tf](infra/variables.tf) with GCP-specific values.
- Add a GCS backend configuration to [infra/main.tf](infra/main.tf) or a dedicated backend file.

### Phase 1 - Rebuild the network module for GCP

Deliverables:

- A GCP network module equivalent to the current AWS networking module.

Resources to create:

- google_compute_network
- google_compute_subnetwork
- google_compute_router
- google_compute_router_nat
- google_compute_firewall

Notes:

- The current AWS security group logic should be converted into firewall rules and network tags.

### Phase 2 - Provision the Kubernetes platform

Deliverables:

- A GKE cluster and node pool module.

Resources to create:

- google_container_cluster
- google_container_node_pool
- GCP service accounts for cluster and node pools
- Workload Identity configuration

Notes:

- This replaces the current EKS-based module in [infra/modules/eks](infra/modules/eks).

### Phase 3 - Provision data services

Deliverables:

- PostgreSQL, Redis, and Firestore resources under the database layer.

Resources to create:

- Cloud SQL for PostgreSQL instances for auth, flag, and target services
- Memorystore for Redis
- Firestore database

Notes:

- The current Terraform creates three RDS instances and one Redis cluster. These must be rewritten for GCP-managed services.
- The documentation mentions a PostgreSQL pod, but Cloud SQL is the recommended production-grade target.

### Phase 4 - Provision messaging and container registry

Deliverables:

- Pub/Sub topics and subscriptions
- Artifact Registry repositories

Resources to create:

- google_pubsub_topic
- google_pubsub_subscription
- google_artifact_registry_repository

Notes:

- This replaces the AWS SQS and ECR resources in [infra/modules/messaging](infra/modules/messaging) and [infra/modules/ecr](infra/modules/ecr).

### Phase 5 - Add IAM and secrets support

Deliverables:

- Service accounts for each application
- IAM bindings and Workload Identity
- Secret storage strategy

Recommended approach:

- Use Workload Identity for Kubernetes applications.
- Store secrets in Secret Manager or Kubernetes Secrets via GitOps.

### Phase 6 - Prepare the application deployment assets

Deliverables:

- Helm values updated to GCP services
- Kubernetes manifests or Helm templates for all services
- Secrets and environment variable wiring

Actions:

- Update [gitops/helm](gitops/helm) values for each service.
- Replace AWS-specific environment variables with GCP equivalents.
- Add service account annotations for Workload Identity where needed.

### Phase 7 - Integrate ArgoCD and GitOps

Deliverables:

- ArgoCD installed on GKE
- ArgoCD Applications for each service
- Automated sync and self-healing enabled

Actions:

- Review and adjust [gitops/argocd](gitops/argocd) assets.
- Validate the existing App of Apps pattern in [gitops/apps](gitops/apps).
- Configure the Git repository URL, credentials, and sync policy.

### Phase 8 - CI/CD for GCP

Deliverables:

- GitHub Actions workflow for build, test, image push, and deployment

Actions:

- Authenticate GitHub Actions to GCP using Workload Identity Federation or a service account key.
- Build and push images to Artifact Registry.
- Update image tags in the GitOps repository.

### Phase 9 - Validation and cutover

Deliverables:

- Full deployment validation
- Service-to-service connectivity checks
- Smoke tests for all services

Validation checklist:

- All pods healthy
- Databases reachable
- Pub/Sub delivery working
- Analytics worker writing to Firestore
- ArgoCD applications synced and healthy

---

## 5. Application-Specific Notes

### analytics-service

The current implementation uses AWS SQS and DynamoDB. To run on GCP it must be updated to:

- Pub/Sub consumer instead of SQS consumer
- Firestore writer instead of DynamoDB writer

This is the most important functional change needed beyond Terraform. The analytics flow should write to Firestore documents keyed by event ID and timestamp.

### evaluation-service

The service currently uses AWS SDK and SQS logic. It should be adapted to:

- Pub/Sub publishing
- Redis-backed evaluation flow
- GCP-compatible environment variables

The Pub/Sub integration should publish evaluation events to a dedicated topic, and the analytics worker should subscribe to that topic.

### auth-service, flag-service, target-service

These services are primarily database-backed and should be deployed with:

- PostgreSQL connection strings pointing to the containerized PostgreSQL deployment in the cluster
- Kubernetes Secrets generated and managed through GitOps
- Service accounts for secure access when needed

The database deployment should be handled by a dedicated PostgreSQL Helm chart or a lightweight StatefulSet-based manifest. The services should consume connection details from Secrets rather than embedding them in manifests or environment files.

---

## 6. What Should Be Implemented First

Recommended implementation order:

1. GCP Terraform provider and backend
2. VPC and firewall resources
3. GKE cluster and node pools
4. Cloud SQL, Memorystore, Firestore
5. Artifact Registry and Pub/Sub
6. Helm values and service manifests
7. ArgoCD installation and application rollout
8. CI/CD workflow and image automation

This order minimizes risk and allows the platform to be brought up incrementally.

---

## 7. Architecture Decisions Adopted for Implementation

The following decisions are now considered the baseline for the implementation:

1. Database model
   - PostgreSQL will be deployed as a containerized workload inside the Kubernetes cluster.
   - This avoids introducing a managed database dependency in the first implementation and keeps the deployment consistent with the current repository’s container-native structure.

2. Messaging model
   - Evaluation events will be published directly to Pub/Sub.
   - The analytics service will consume from the corresponding subscription without an intermediate SQS compatibility layer.

3. Analytics persistence model
   - Analytics events will be written to Firestore.
   - The service code should be refactored to use Firestore APIs instead of DynamoDB.

4. Secret management model
   - Kubernetes Secrets will be managed by GitOps.
   - The GitOps repository will hold the declarative Secret manifests or templated values, while deployment automation will apply them to the cluster.

5. GitOps repository model
   - A dedicated GitOps repository is recommended.
   - The current [gitops](gitops) directory should not be the long-term source of truth because it mixes bootstrapping scripts, Helm charts, app definitions, and environment-specific assets in the same folder.
   - The new GitOps repository should be focused only on runtime deployment state and should be referenced by ArgoCD as the single source of truth for cluster resources.

6. CI/CD execution model
   - GitHub Actions should build images, push them to Artifact Registry, and update the GitOps repository with the new image tags.
   - ArgoCD should then reconcile the cluster from the GitOps repository.

7. Environment scope
   - The first implementation should target a staging-like environment first, then be hardened for production after validation.

---

## 8. Definition of Done

The migration can be considered complete when:

- Terraform provisions the full GCP infrastructure without manual steps.
- The five services deploy successfully on GKE through ArgoCD and Helm.
- Database and messaging connectivity works end to end.
- The analytics flow works with Pub/Sub and Firestore.
- The GitOps repository updates images automatically and ArgoCD keeps the cluster in sync.
