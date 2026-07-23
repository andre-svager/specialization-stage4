# analytics-service (Python)

Este p  serviço de análise (analytics) do projeto ToggleMaster. Ele é um *worker* de backend e não possui uma API pública (exceto `/health`).

Sua única função é:
1.  Ouvir constantemente o tópico/assinatura do **Google Cloud Pub/Sub** (que o `evaluation-service` preenche).
2.  Consumir as mensagens de evento da assinatura (subscription).
3.  Gravar os dados de análise em uma coleção do **Firestore** (Native mode).

## 📦 Pré-requisitos (Local)

* [Python](https://www.python.org/) (versão 3.9 ou superior)
* **Credenciais do GCP:** Este serviço **DEVE** ter credenciais do GCP para acessar Pub/Sub e Firestore. Configure-as em seu terminal ou defina a variável de ambiente:
  * `GOOGLE_APPLICATION_CREDENTIALS` — caminho para o JSON de uma **service account**, OU
  * Application Default Credentials via `gcloud auth application-default login` (uso local/dev)
* **Recursos do GCP:** As APIs, o tópico/assinatura Pub/Sub e a coleção Firestore precisam existir no projeto (ver seção IaC abaixo).

## 🏗️ Infraestrutura como Código (Terraform)

Esta seção define os recursos que um agente/Terraform deve provisionar para este serviço. Use como especificação de entrada para gerar os arquivos `.tf`.

### APIs necessárias
```hcl
resource "google_project_service" "pubsub" {
  service = "pubsub.googleapis.com"
}

resource "google_project_service" "firestore" {
  service = "firestore.googleapis.com"
}
```

### Pub/Sub (substitui o SQS)
```hcl
resource "google_pubsub_topic" "analytics_events" {
  name = "toggle-master-analytics-events"
}

resource "google_pubsub_subscription" "analytics_worker" {
  name  = "toggle-master-analytics-worker-sub"
  topic = google_pubsub_topic.analytics_events.name

  ack_deadline_seconds = 20
}
```

### Firestore (substitui o DynamoDB)
```hcl
resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
}
```
> Firestore não usa "tabelas com throughput provisionado" como o DynamoDB — a coleção `ToggleMasterAnalytics` é criada implicitamente na primeira gravação, sem necessidade de definir capacidade.

**Coleção equivalente:** `ToggleMasterAnalytics`
**Chave do documento (equivalente à Partition Key):** `event_id` (String) — usar como Document ID.

### Service Account e permissões
```hcl
resource "google_service_account" "analytics_service" {
  account_id   = "analytics-service"
  display_name = "Analytics Service Worker"
}

resource "google_project_iam_member" "pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.analytics_service.email}"
}

resource "google_project_iam_member" "firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.analytics_service.email}"
}
```

### Variáveis esperadas
```hcl
variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}
```

## 🚀 Rodando Localmente

**1. Clone o repositório** e entre na pasta `analytics-service`.

**2. Configure as Variáveis de Ambiente:** Crie um arquivo chamado `.env` na raiz desta pasta (`analytics-service/`) com o seguinte conteúdo. **Garanta que suas credenciais do GCP também estejam configuradas no seu ambiente.**
```.env
# Porta que este serviço (health check) irá rodar
PORT="8005"

# --- Configuração do GCP ---
# ID do projeto GCP
GCP_PROJECT_ID="seu-projeto-gcp"

# Nome da assinatura (subscription) Pub/Sub criada pelo Terraform
GCP_PUBSUB_SUBSCRIPTION="toggle-master-analytics-worker-sub"

# Nome da coleção Firestore usada para gravar os eventos
GCP_FIRESTORE_COLLECTION="ToggleMasterAnalytics"

# Região dos recursos GCP
GCP_REGION="us-central1"

# Caminho para o JSON da service account (necessário fora do GCP, ex: local/dev)
GOOGLE_APPLICATION_CREDENTIALS="/caminho/para/service-account.json"
```

**3. Instale as Dependências:**
```bash
pip install -r requirements.txt
```

**4. Inicie o Serviço:**
```bash
gunicorn --bind 0.0.0.0:8005 app:app
```
O servidor estará rodando em `http://localhost:8005`. Você verá logs no terminal assim que o worker Pub/Sub iniciar e (eventualmente) processar mensagens.

## 🧪 Testando o Serviço

Testar este serviço é diferente. Você não vai chamar uma API dele.

**1. Verifique a Saúde:**
```bash
curl http://localhost:8005/health
```
Saída esperada: `{"status":"ok"}`

**2. Gere Eventos:**

- Vá para o `evaluation-service` (que deve estar rodando) e faça algumas requisições de avaliação:
```bash
curl "http://localhost:8004/evaluate?user_id=test-user-1&flag_name=enable-new-dashboard"
curl "http://localhost:8004/evaluate?user_id=test-user-2&flag_name=enable-new-dashboard"
```
- **Alternativa:** Publique uma mensagem manualmente pelo Console do Google Cloud Pub/Sub, ou via CLI:
```bash
gcloud pubsub topics publish toggle-master-analytics-events \
  --message='{"event_id":"manual-test-1","flag_name":"enable-new-dashboard","user_id":"test-user-1"}'
```

**3. Observe os Logs:**

No terminal do `analytics-service`, você deverá ver os logs aparecendo, indicando que as mensagens foram recebidas e salvas no Firestore:
```bash
INFO:Iniciando o worker Pub/Sub...
INFO:Recebidas 2 mensagens.
INFO:Processando mensagem ID: ...
INFO:Evento ... (Flag: enable-new-dashboard) salvo no Firestore.
INFO:Processando mensagem ID: ...
INFO:Evento ... (Flag: enable-new-dashboard) salvo no Firestore.
```

**4. Verifique o Firestore:**

Vá até o console do Google Cloud, abra o **Firestore**, selecione a coleção `ToggleMasterAnalytics` e visualize os documentos.

Você verá os itens que o worker acabou de inserir.

**5. Atualizar somente o container caso necessário:**
```bash
docker compose up -d --no-deps --build analytics-service
```
# ci trigger Thu Jul 23 08:13:54 PM -03 2026
