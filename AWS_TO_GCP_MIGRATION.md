# AWS to GCP Migration Plan

This document outlines all steps required to migrate the ToggleMaster microservices platform from AWS to Google Cloud Platform (GCP).
Create all those structures as IAC utilizing terraforms present on /infra/modules folder
Change terraforms configurations to be applyed on GCP

---

## Table of Contents

1. [Infrastructure & Networking Migration](#1-infrastructure--networking-migration)
2. [Terraform Remote State Migration](#2-terraform-remote-state-migration)
3. [IAM Migration with Academy Restrictions](#3-iam-migration-with-academy-restrictions)
4. [Kubernetes Migration (EKS → GKE)](#4-kubernetes-migration-eks--gke)
5. [Database Migration](#5-database-migration)
6. [Container Registry Migration](#6-container-registry-migration)
7. [Messaging Migration](#7-messaging-migration)
8. [CI Pipeline Migration with DevSecOps Stages](#8-ci-pipeline-migration-with-devsecops-stages)
9. [GitOps Repository Setup](#9-gitops-repository-setup)
10. [ArgoCD Installation on GKE](#10-argocd-installation-on-gke)
11. [Automatic Image Tag Update](#11-automatic-image-tag-update)
12. [ArgoCD Auto-Sync Configuration](#12-argocd-auto-sync-configuration)
13. [Security & Secrets Management](#13-security--secrets-management)
14. [Monitoring & Logging Migration](#14-monitoring--logging-migration)
15. [Testing & Validation](#15-testing--validation)
16. [Cutover Strategy](#16-cutover-strategy)
17. [Documentation Updates](#17-documentation-updates)
18. [Team Training](#18-team-training)
19. [Deliverables Preparation](#19-deliverables-preparation)

---

## 1. Infrastructure & Networking Migration

### Current AWS → GCP Equivalent

| AWS Service | GCP Equivalent |
|-------------|----------------|
| VPC | GCP VPC |
| Subnets (Public/Private) | GCP Subnets |
| NAT Gateway | Cloud NAT |
| Internet Gateway | Cloud Router |
| Route Tables | VPC Routes |
| Security Groups | VPC Firewall Rules |
| Elastic IPs | (Not needed - ephemeral IPs) |

### Steps

1. **Create GCP VPC**
   - Use same CIDR block (10.1.0.0/16)
   - Configure VPC with custom mode
   - Enable private Google access

2. **Create Subnets**
   - Create public subnets in same availability zones
   - Create private subnets in same availability zones
   - Configure subnet IP ranges

3. **Configure Cloud NAT**
   - Create Cloud NAT gateway for private subnet egress
   - Configure NAT logging (optional)

4. **Set up Cloud Router**
   - Create Cloud Router for internet connectivity
   - Configure BGP sessions

5. **Migrate Security Groups to Firewall Rules**
   - Convert AWS security group rules to VPC firewall rules
   - Create ingress/egress rules for each service
   - Apply rules to appropriate network tags

6. **Update Terraform Provider**
   - Replace `hashicorp/aws` with `hashicorp/google`
   - Update provider configuration
   - Migrate all Terraform resources to GCP equivalents

---

## 2. Terraform Remote State Migration

### Steps

1. **Create GCS Bucket for State**
   ```hcl
   terraform {
     backend "gcs" {
       bucket = "togglemaster-tfstate"
       prefix = "infra/terraform.tfstate"
     }
   }
   ```

2. **Configure State Locking**
   - GCS provides built-in locking
   - Enable versioning on bucket

3. **Migrate Existing State**
   - Verify state integrity on local terraform state file

4. **Test State Operations**
   - Test `terraform plan`
   - Test `terraform apply`
   - Verify state locking works

---

## 3. IAM Migration 

**Steps:**

1. **Create GCP Service Accounts**
   - Create service account for GKE cluster
   - Create service account for node pools
   - Create service accounts for each microservice

2. **Grant IAM Permissions**
   - Grant appropriate roles (Viewer, Editor, custom roles)
   - Configure least privilege access

3. **Configure Workload Identity**
   - Set up Workload Identity federation between GKE and GCP
   - Configure Kubernetes service accounts to use Workload Identity

4. **Migrate KMS Keys**
   - Export encryption keys from AWS KMS
   - Import to Cloud KMS
   - Update resources to use Cloud KMS

---

## 4. Kubernetes Migration (EKS → GKE)

### Current AWS → GCP Equivalent

| AWS Service | GCP Equivalent |
|-------------|----------------|
| EKS | Google Kubernetes Engine (GKE) |
| EKS Node Groups | GKE Node Pools |
| IAM Roles for Service Accounts | Workload Identity |

### Steps

1. **Create GKE Cluster**
   - Choose Standard mode
   - Configure cluster version
   - Set up cluster networking

2. **Configure Node Pools**
   - Create node pools with equivalent instance types
   - Configure autoscaling
   - Set up node labels and taints

3. **Set up Workload Identity**
   - Enable Workload Identity on cluster
   - Configure IAM service accounts
   - Update Kubernetes service accounts

4. **Migrate kubeconfig**
   - Update kubeconfig to point to GKE cluster
   - Test cluster connectivity
   - Verify node readiness

5. **Update ArgoCD**
   - Update ArgoCD to deploy to GKE cluster
   - Configure cluster context
   - Test application deployments

---

## 5. Database Migration

### PostgreSQL (RDS → create a pod with postgres based on docker oficial image)

**Steps:**

1. **Create POSTgresql SQL pod**
   - Create one database for auth service database
   - Create one database for flag service database
   - Create one database for target service database
   - Explanin how to create , expose and connect


2. **Update Connection Strings**
   - Update Kubernetes secrets with Postgres SQL endpoints
   - Update application configuration
   - Test database connectivity

### Redis (ElastiCache → Memorystore)

**Steps:**

1. **Create Memorystore Instance**
   - Create Memorystore for Redis instance
   - Configure Redis version and tier
   - Set up VPC peering

2. **Migrate Data**
   - If ephemeral: Flush existing Redis data
   - If persistent: Use Redis MIGRATE command or dump/restore

3. **Update Connection String**
   - Update Kubernetes secrets with Memorystore endpoint
   - Update application configuration
   - Test Redis connectivity

### DynamoDB → Firestore

**Steps:**

1. **Create Firestore Database**
   - Create Firestore database in Native mode
   - Configure database location

2. **Export DynamoDB Data**
   - Use AWS Data Pipeline or custom script
   - Export ToggleMasterAnalytics table

3. **Transform Data Schema**
   - Convert DynamoDB schema to Firestore document structure
   - Handle data type conversions

4. **Import Data to Firestore**
   - Use Firestore batch operations
   - Import transformed data
   - Verify data integrity

5. **Update Application Code**
   - Replace DynamoDB SDK with Firestore SDK
   - Update data access patterns
   - Test application functionality

6. **Update Terraform**
   - Remove DynamoDB resource
   - Add Firestore resource
   - Update outputs

---

## 6. Container Registry Migration

### Current AWS → GCP Equivalent

| AWS Service | GCP Equivalent |
|-------------|----------------|
| ECR | Artifact Registry |

### Steps

1. **Create Artifact Registry Repositories**
   - Create repository for analytics-service
   - Create repository for auth-service
   - Create repository for evaluation-service
   - Create repository for flag-service
   - Create repository for target-service

2. **Build and Push Images**
   - Build Docker images for each service
   - Tag images appropriately
   - Push to Artifact Registry

3. **Update Kubernetes Manifests**
   - Update image URLs to point to Artifact Registry
   - Update image pull secrets if needed

4. **Update CI/CD Pipelines**
   - Configure authentication to Artifact Registry
   - Update Docker build/push steps
   - Update image scanning tools

5. **Cleanup**
   - Verify images work correctly
   - Delete old ECR repositories

---

## 7. Messaging Migration

### Current AWS → GCP Equivalent

| AWS Service | GCP Equivalent |
|-------------|----------------|
| SQS | Pub/Sub |

### Steps

1. **Create Pub/Sub Topic**
   - Create topic for evaluation queue
   - Configure topic permissions

2. **Create Pub/Sub Subscription**
   - Create subscription for the topic
   - Configure subscription settings (ack deadline, retry policy)

3. **Update Application Code**
   - Replace SQS SDK with Pub/Sub SDK
   - Update message publishing logic
   - Update message consumption logic

4. **Update Terraform**
   - Remove SQS resource
   - Add Pub/Sub topic and subscription resources
   - Update outputs

5. **Test Messaging**
   - Test message publishing
   - Test message consumption
   - Verify message ordering (if using FIFO)

---

## 8. CI Pipeline Migration with DevSecOps Stages

### Stage 1: Build & Unit Test

**Steps:**

1. **Configure GitHub Actions for GCP Authentication**
   - Set up Workload Identity Federation or Service Account Key
   - Configure GitHub Actions secrets
   - Test authentication

2. **Set Up Build Environment**
   - Configure Go build environment for Go services
   - Configure Python build environment for Python services
   - Install required dependencies

3. **Run Unit Tests**
   - Execute unit tests for each microservice
   - Generate test coverage reports
   - Fail pipeline if tests fail

### Stage 2: Linter/Static Analysis

**Steps:**

1. **Install Linters**
   - Install golangci-lint for Go services
   - Install pylint/flake8 for Python services

2. **Run Linters**
   - Execute linters in CI pipeline
   - Generate linting reports
   - Fail pipeline on linting errors

### Stage 3: Security Scan (SAST & SCA)

**Steps:**

1. **Install Trivy for SCA**
   - Install Trivy in CI pipeline
   - Configure Trivy to scan dependencies
   - Scan for vulnerabilities in dependencies

2. **Install SAST Tools**
   - Install gosec for Go services
   - Install bandit for Python services
   - Scan source code for vulnerabilities

3. **Generate Security Reports**
   - Generate vulnerability reports
   - Upload reports as artifacts

4. **Implement CRITICAL Vulnerability Block**
   - Configure pipeline to fail on CRITICAL vulnerabilities
   - Set severity threshold
   - Block pipeline progression if CRITICAL found

### Stage 4: Docker Build & Push

**Steps:**

1. **Build Docker Images**
   - Build Docker image for each service
   - Use multi-stage builds for optimization
   - Tag images with commit hash (e.g., v1.0.0-a1b2c3d)

2. **Run Container Scan**
   - Run Trivy on built Docker images
   - Scan for vulnerabilities in container layers
   - Fail pipeline if CRITICAL vulnerabilities found

3. **Authenticate to Artifact Registry**
   - Use `gcloud auth configure-docker`
   - Configure Docker credentials

4. **Push Images**
   - Push images to Artifact Registry
   - Verify push succeeded

---

## 9. GitOps Repository Setup

### Steps

1. **Create GitOps Repository**
   - Create separate repository or folder in monorepo
   - Structure: `gitops/manifests/` or `gitops/helm-charts/`

2. **Add Kubernetes Manifests**
   - Add deployment manifests for all 5 services
   - Add service manifests
   - Add config maps and secrets
   - Add ingress manifests

3. **Add Helm Charts (Optional)**
   - Create Helm charts for each service
   - Configure values files for different environments

4. **Add ArgoCD Application Manifests**
   - Create Application resources for each service
   - Configure source and destination
   - Set sync policies

5. **Initialize Repository**
   - Initialize with Git
   - Push to remote repository
   - Verify structure

---

## 10. ArgoCD Installation on GKE

### Steps

1. **Install ArgoCD via Helm**
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm install argocd argo/argo-cd -n argocd --create-namespace
   ```

   OR via Terraform with Helm provider:
   ```hcl
   resource "helm_release" "argocd" {
     name       = "argocd"
     repository = "https://argoproj.github.io/argo-helm"
     chart      = "argo-cd"
     namespace  = "argocd"
   }
   ```

2. **Configure ArgoCD for GKE**
   - Configure ArgoCD to use GKE cluster
   - Set up cluster context
   - Configure repository credentials

3. **Set up ArgoCD Server**
   - Configure LoadBalancer service
   - Set up ingress for external access
   - Configure TLS certificates

4. **Configure ArgoCD RBAC**
   - Set up role-based access control
   - Configure user permissions
   - Set up SSO (optional)

5. **Verify Installation**
   - Access ArgoCD UI
   - Verify cluster connectivity
   - Test application deployment

---

## 11. Automatic Image Tag Update

### Steps

1. **Add CI Pipeline Step**
   - Add step after Docker push in CI pipeline
   - Configure step to update GitOps repository

2. **Update Image Tag**
   - Use `yq` to update image tag in YAML files:
     ```bash
     yq e '.spec.template.spec.containers[0].image = "new-image:tag"' -i deployment.yaml
     ```
   - Or use `sed` for simple replacements

3. **Commit and Push Changes**
   - Commit updated manifests to GitOps repository
   - Push to remote repository
   - Use GitHub token for authentication

4. **Verify Update**
   - Verify tag was updated correctly
   - Verify commit was pushed
   - Check ArgoCD detects change

---

## 12. ArgoCD Auto-Sync Configuration

### Steps

1. **Create ArgoCD Application Resources**
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: auth-service
   spec:
     source:
       repoURL: https://github.com/your-org/gitops-repo
       path: manifests/auth-service
     destination:
       server: https://kubernetes.default.svc
       namespace: default
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```

2. **Configure Auto-Sync Policy**
   - Set `syncPolicy.automated` to true
   - Configure `prune` to remove resources not in Git
   - Configure `selfHeal` to fix drift

3. **Set up Git Webhook**
   - Configure webhook in Git repository
   - Point webhook to ArgoCD server
   - Configure webhook secret

4. **Configure Sync Wave**
   - Set up sync wave for ordered deployments
   - Configure dependencies between applications
   - Set up health checks

5. **Test Auto-Sync**
   - Trigger a pipeline change
   - Verify ArgoCD detects change
   - Verify automatic sync occurs
   - Verify application is deployed


<!-- 
---

## 13. Security & Secrets Management

### Steps

1. **Migrate Database Credentials**
   - Remove hardcoded credentials from manifests
   - Create Kubernetes Secrets for each database
   - Use GCP Secret Manager for sensitive data

2. **Set up GCP Secret Manager**
   - Create secrets in Secret Manager
   - Store database credentials
   - Store API keys and tokens

3. **Configure External Secrets Operator**
   - Install External Secrets Operator in GKE cluster
   - Create ExternalSecret resources
   - Configure sync from Secret Manager to Kubernetes Secrets

4. **Update Application Configuration**
   - Update applications to read from Kubernetes Secrets
   - Remove environment variables with sensitive data
   - Test secret injection

5. **Rotate Secrets**
   - Set up secret rotation policies
   - Automate secret rotation
   - Test rotation process

---

## 14. Monitoring & Logging Migration

### Current AWS → GCP Equivalent

| AWS Service | GCP Equivalent |
|-------------|----------------|
| CloudWatch | Cloud Monitoring & Cloud Logging |
| X-Ray | Cloud Trace |

### Steps

1. **Set up Cloud Logging**
   - Configure Cloud Logging for application logs
   - Set up log sinks
   - Configure log retention

2. **Configure Cloud Monitoring**
   - Set up metrics collection
   - Create custom metrics
   - Configure dashboards

3. **Update Application Code**
   - Replace CloudWatch SDK with Cloud Logging SDK
   - Replace X-Ray SDK with Cloud Trace SDK
   - Update logging configuration

4. **Create Dashboards**
   - Create monitoring dashboards
   - Set up alerts
   - Configure notification channels

5. **Test Monitoring**
   - Verify logs are being collected
   - Verify metrics are being reported
   - Test alerting

---

## 15. Testing & Validation

### Steps

1. **Deploy Staging Environment**
   - Deploy all services to GKE staging cluster
   - Verify all pods are running
   - Check service connectivity

2. **Run Integration Tests**
   - Execute integration test suite
   - Test service-to-service communication
   - Test database connectivity
   - Test messaging

3. **Performance Testing**
   - Run load tests
   - Measure response times
   - Identify bottlenecks
   - Optimize as needed

4. **Security Scanning**
   - Run security scans with GCP Security Command Center
   - Scan for vulnerabilities
   - Review security posture
   - Remediate findings

5. **Disaster Recovery Testing**
   - Test backup and restore procedures
   - Test failover scenarios
   - Verify RTO and RPO
   - Update runbooks

---

## 16. Cutover Strategy

### Options

#### Blue-Green Deployment
- Run both AWS and GCP environments in parallel
- Switch DNS to point to GCP
- Keep AWS as rollback option

#### Canary Deployment
- Gradually migrate traffic from AWS to GCP
- Start with small percentage of traffic
- Increase gradually
- Monitor for issues

#### Big Bang
- Complete cutover after testing
- Execute during low-traffic period
- Fastest but highest risk

### Steps

1. **Choose Cutover Strategy**
   - Evaluate risk tolerance
   - Choose appropriate strategy
   - Plan rollback procedure

2. **Execute Cutover**
   - Follow chosen strategy
   - Monitor for issues
   - Be ready to rollback

3. **Post-Cutover Validation**
   - Verify all services are working
   - Monitor performance
   - Check error rates
   - Validate data integrity

4. **Decommission AWS Resources**
   - After successful migration
   - Delete AWS resources
   - Cancel AWS services
   - Clean up accounts

---

## 17. Documentation Updates

### Steps

1. **Update README**
   - Add GCP-specific instructions
   - Update architecture diagrams
   - Update setup guides

2. **Update Deployment Guides**
   - Document GCP deployment process
   - Update troubleshooting guides
   - Add GCP console navigation

3. **Update Configuration Documentation**
   - Document GCP-specific configurations
   - Update environment variables
   - Document service account setup

4. **Update Runbooks**
   - Create GCP-specific runbooks
   - Update incident response procedures
   - Document common GCP operations

5. **Update Architecture Diagrams**
   - Update to show GCP services
   - Update network diagrams
   - Update data flow diagrams

---

## 18. Team Training

### Steps

1. **Provide GCP Training**
   - Organize GCP training sessions
   - Cover core GCP services
   - Cover GCP console navigation

2. **Document GCP Operations**
   - Create quick reference guides
   - Document common operations
   - Create video tutorials

3. **Update On-Call Procedures**
   - Update on-call runbooks for GCP
   - Train on-call team
   - Conduct drills

4. **Knowledge Sharing**
   - Conduct knowledge sharing sessions
   - Share lessons learned
   - Document best practices

---

## 19. Deliverables Preparation

### Video Demonstration (up to 20 min)

**Required Content:**

1. **IaC Demonstration**
   - Show `terraform plan` running
   - Show `terraform apply` running
   - Show final GCP resources:
     - VPCs
     - Cloud SQL instances
     - GKE cluster
     - All resources created via code

2. **DevSecOps Pipeline Demonstration**
   - Make intentional change to microservice code
     - Insert error OR
     - Add vulnerable dependency
   - Show pipeline failing at security stage
   - Fix the issue
   - Show pipeline passing

3. **GitOps Demonstration**
   - Show pipeline updating image tag in GitOps repository
   - Show commit being pushed

4. **ArgoCD Demonstration**
   - Show ArgoCD detecting the change
   - Show ArgoCD synchronizing new version to cluster
   - Show all 5 microservices being managed

### Code Deliverables

1. **Terraform Code**
   - Well-structured and modular
   - All infrastructure as code
   - Proper use of modules
   - State management configured

2. **GitHub Actions Workflows**
   - All DevSecOps stages implemented
   - Build & Unit Test
   - Linter/Static Analysis
   - Security Scan (SAST & SCA with Trivy)
   - Docker Build & Push with Container Scan
   - CRITICAL vulnerability block rule implemented

3. **Kubernetes Manifests**
   - Adjusted for GitOps
   - Properly structured
   - Separate GitOps repository/folder
   - ArgoCD Application manifests included

---

## Summary Checklist

- [ ] Infrastructure & Networking migrated to GCP
- [ ] Terraform remote state migrated to GCS
- [ ] IAM configured (Academy or personal account)
- [ ] GKE cluster created and configured
- [ ] Databases migrated (Cloud SQL, Memorystore, Firestore)
- [ ] Container registry migrated to Artifact Registry
- [ ] Messaging migrated to Pub/Sub
- [ ] CI pipeline with all DevSecOps stages
- [ ] GitOps repository set up
- [ ] ArgoCD installed on GKE
- [ ] Automatic image tag update implemented
- [ ] ArgoCD auto-sync configured
- [ ] Secrets management configured
- [ ] Monitoring and logging migrated
- [ ] Testing and validation completed
- [ ] Cutover executed
- [ ] Documentation updated
- [ ] Team trained
- [ ] Deliverables prepared (video and code)

---

## Estimated Timeline

| Phase | Duration |
|-------|----------|
| Infrastructure Migration | 2-3 weeks |
| Database Migration | 1-2 weeks |
| Application Migration | 2-3 weeks |
| CI/CD Migration | 1-2 weeks |
| GitOps Setup | 1 week |
| Testing & Validation | 1-2 weeks |
| Cutover | 1 week |
| Documentation & Training | 1 week |

**Total Estimated Time: 9-14 weeks**

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Data loss during migration | Full backups before migration, test restore procedures |
| Application downtime | Use blue-green deployment, plan rollback |
| Performance degradation | Load testing before cutover, monitor closely |
| Security vulnerabilities | Security scanning, penetration testing |
| Team unfamiliarity with GCP | Training, documentation, gradual migration |
| Cost overruns | Cost monitoring, budget alerts, optimization |

---

## References

- [GCP Documentation](https://cloud.google.com/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [ArgoCD Documentation](https://argoproj.github.io/argo-cd/)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs) -->
