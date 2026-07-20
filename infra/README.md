# FIAP Stage 3 - Infrastructure as Code (IaC) com Terraform

Estrutura modular de Terraform para provisionar a infraestrutura AWS completa do projeto FIAP Stage 3, incluindo EKS, RDS, ElastiCache, DynamoDB, SQS e ECR.

## 📋 Estrutura de Diretórios

```
infra/
├── modules/
qcleart

│   ├── networking/        # VPC, subnets, IGW, NAT Gateway, security groups
│   ├── eks/              # EKS cluster, node groups, OIDC provider
│   ├── databases/        # 3x RDS PostgreSQL, ElastiCache Redis, DynamoDB
│   ├── messaging/        # SQS queues com DLQ
│   └── ecr/              # 5 repositórios ECR (um por serviço)
├── provider.tf           # Configuração de provedores (AWS, TLS)
├── main.tf               # Chamadas dos módulos
├── variables.tf          # Variáveis globais
├── outputs.tf            # Outputs da infraestrutura
└── terraform.tfvars.example  # Exemplo de valores
```

## 🚀 Começando

### Pré-requisitos

- **Terraform** >= 1.5 ([Download](https://www.terraform.io/downloads))
- **AWS CLI** configurado com credenciais
- **AWS Account** com permissões IAM suficientes
- **kubectl** (para interagir com EKS depois)

### 1. Clonar/Preparar o Repositório

```bash
cd infra/
```

### 2. Copiar e Configurar o arquivo de variáveis

```bash
cp terraform.tfvars.example terraform.tfvars
```

**Editar `terraform.tfvars` com seus valores:**

```hcl
environment = "staging"
cluster_name = "fiap-stage3-eks"

# IMPORTANTE: Alterar a senha RDS!
rds_username = "postgres"
rds_password = "postgres"
```

### 3. Inicializar Terraform

```bash
terraform init
```

Isto irá:
- Download dos plugins do Terraform
- Criação da pasta `.terraform/`
- Inicialização do backend local

**Opcional - Configurar Backend Remoto (S3 + DynamoDB):**

Se quiser usar state remoto (recomendado para produção):

```bash
# 1. Criar bucket S3 e tabela DynamoDB manualmente primeiro
# 2. Descomentar a seção backend em provider.tf
# 3. Executar novamente:
terraform init -migrate-state
```

### 4. Validar a Configuração

```bash
terraform validate
```

Verifica se não há erros de sintaxe.

### 5. Planejar a Infraestrutura (Etapa por Etapa)

**Vamos testar cada módulo com `terraform plan` antes de aplicar:**

#### Passo 1: Networking

```bash
terraform plan -target=module.networking -out=tfplan_networking
```

Revise os recursos que serão criados:
- VPC, subnets públicas/privadas
- Internet Gateway, NAT Gateway
- Route tables
- Security groups

#### Passo 2: EKS

```bash
terraform plan -target=module.eks -out=tfplan_eks
```

Revise:
- IAM roles e policies
- EKS cluster
- Node group
- OIDC provider

#### Passo 3: Databases

```bash
terraform plan -target=module.databases -out=tfplan_databases
```

Revise:
- 3 instâncias RDS PostgreSQL (auth, flag, target)
- ElastiCache Redis
- DynamoDB table

#### Passo 4: Messaging (SQS)

```bash
terraform plan -target=module.messaging -out=tfplan_messaging
```

Revise:
- 1 fila SQS FIFO (evaluation)
- Dead Letter Queue (DLQ)
- CloudWatch alarms

#### Passo 5: ECR

```bash
terraform plan -target=module.ecr -out=tfplan_ecr
```

Revise:
- 5 repositórios ECR
- Lifecycle policies
- Repository policies

### 6. Aplicar a Infraestrutura

**Após revisar cada `terraform plan`, aplicar:**

```bash
# Aplicar networking
terraform apply tfplan_networking

# Aguardar conclusão (~5-10 min)...

# Aplicar EKS
terraform apply tfplan_eks

# Aguardar conclusão (~15-20 min)...

# Aplicar databases
terraform apply tfplan_databases

# Aguardar conclusão (~10-15 min)...

# Aplicar messaging
terraform apply tfplan_messaging

# Aplicar ECR
terraform apply tfplan_ecr
```

**OU aplicar tudo de uma vez (não recomendado para produção):**

```bash
terraform apply
```

### 7. Verificar a Infraestrutura

Após aplicação bem-sucedida:

```bash
terraform output
```

Isto mostrará:
- VPC ID, subnets
- EKS cluster endpoint
- Endpoints RDS (host:port)
- Endpoint Redis
- URLs dos repositórios ECR
- URLs das filas SQS

### 8. Conectar ao EKS

```bash
# Atualizar kubeconfig
aws eks update-kubeconfig --name fiap-stage3-eks --region us-east-1

# Verificar conexão
kubectl get nodes
```

## 📊 Detalhes da Infraestrutura

### VPC & Networking
- **CIDR:** 10.1.0.0/16
- **Subnets:** 2 públicas + 2 privadas (em 2 AZs)
- **NAT Gateway:** 1 (para acesso à internet das subnets privadas)
- **IGW:** Internet Gateway para subnets públicas

### EKS
- **Versão:** 1.29
- **Node Group:** 1 (t3.medium, 1-2 nós)
- **OIDC Provider:** Para IRSA (IAM Roles for Service Accounts)

### RDS PostgreSQL
- **Instâncias:** 3 (auth, flag, target)
- **Versão:** 13
- **Classe:** db.t3.small
- **Storage:** 20GB (gp2)
- **Backup:** 7 dias
- **Multi-AZ:** Não (staging)

### ElastiCache Redis
- **Versão:** 7.0
- **Node Type:** cache.t3.micro
- **Nós:** 1 (desenvolvimento)
- **Encryption:** Habilitada (at-rest)

### DynamoDB
- **Tabela:** ToggleMasterAnalytics
- **Billing:** PAY_PER_REQUEST
- **Encryption:** Habilitada
- **Point-in-time recovery:** Habilitada

### SQS
- **Tipo:** FIFO (para ordenação garantida)
- **Filas:** evaluation
- **DLQ:** evaluation-dlq
- **Encryption:** Habilitada

### ECR
- **Repositórios:** 5 (um por serviço)
- **Scanning:** Habilitado
- **Lifecycle:** Manter últimas 10 imagens

## 🔧 Gerenciamento da Infraestrutura

### Modificar Configurações

1. Edite as variáveis em `terraform.tfvars`
2. Execute `terraform plan` para revisar mudanças
3. Execute `terraform apply` para aplicar

Exemplo - Escalar o EKS:

```hcl
# Em terraform.tfvars
node_desired_size = 3
node_max_size = 4
```

```bash
terraform plan
terraform apply
```

### Destruir a Infraestrutura

**CUIDADO: Isto deletará tudo (RDS, EKS, etc.)**

```bash
terraform destroy
```

Para destruir apenas um módulo:

```bash
terraform destroy -target=module.ecr
```

### Ver Estado Atual

```bash
terraform state list
terraform state show module.eks.aws_eks_cluster.main
```

## 📝 Arquivos Importantes

| Arquivo | Descrição |
|---------|-----------|
| `provider.tf` | Configuração de provedores AWS e TLS |
| `main.tf` | Chamadas dos módulos |
| `variables.tf` | Definição de variáveis globais |
| `outputs.tf` | Outputs da infraestrutura |
| `terraform.tfvars` | Valores das variáveis (NÃO commitar com secrets!) |
| `.gitignore` | Arquivos a ignorar no Git |

## 🔐 Segurança & Boas Práticas

### 1. Não commitar `terraform.tfvars`

```bash
# Adicionar ao .gitignore
echo "terraform.tfvars" >> .gitignore
```

### 2. Usar AWS Secrets Manager para Passwords

Para produção, usar secrets:

```bash
# Criar secret
aws secretsmanager create-secret --name rds/postgres/password --secret-string "SenhaForte@123"

# Usar em variables.tf com data source
```

### 3. Usar Backend Remoto com Lock

```hcl
# provider.tf
backend "s3" {
  bucket         = "seu-bucket-terraform"
  key            = "stage3/terraform.tfstate"
  dynamodb_table = "terraform-locks"
}
```

### 4. Habilitar Encryption

- ✅ EKS: Etcd criptografado
- ✅ RDS: Storage encryption
- ✅ ElastiCache: At-rest encryption
- ✅ DynamoDB: SSE habilitado
- ✅ SQS: SSE habilitado

### 5. Backup & Disaster Recovery

- RDS: Backup automático com 7 dias retenção
- DynamoDB: Point-in-time recovery habilitada
- EKS: Etcd backup automático (AWS gerenciado)

## 🐛 Troubleshooting

### Erro: "InvalidParameterCombination"

Verifique se o environment é válido (staging/production).

### Erro: "AccessDenied" ao criar recursos

Verifique permissões IAM da conta AWS.

### EKS demora muito tempo (~20 min)

Isto é normal na primeira criação. Aguarde a conclusão.

### Nodes não entram em Ready

```bash
kubectl get nodes -v=8
kubectl describe nodes
kubectl logs -n kube-system -l component=kubelet
```

## 📚 Referências

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform Best Practices](https://www.terraform.io/language/modules/develop)

## 📞 Suporte

Para problemas ou dúvidas:

1. Verificar logs: `terraform apply -var="..."`
2. Validar: `terraform validate`
3. Formatter: `terraform fmt -recursive`
4. Consultar documentação oficial

---

**Última atualização:** Maio 2026
**Versão Terraform:** >= 1.5
**Versão AWS Provider:** ~> 5.0
