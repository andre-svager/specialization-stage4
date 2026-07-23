import os
import threading
import json
import uuid
import time
import logging
from flask import Flask, jsonify
from dotenv import load_dotenv
from google.cloud import firestore
from google.cloud import pubsub_v1

# Configura o logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
log = logging.getLogger(__name__)

# Carrega .env para desenvolvimento local
load_dotenv()

# --- Configuração ---
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
GCP_PUBSUB_SUBSCRIPTION = os.getenv("GCP_PUBSUB_SUBSCRIPTION")
GCP_FIRESTORE_COLLECTION = os.getenv("GCP_FIRESTORE_COLLECTION", "ToggleMasterAnalytics")
GCP_REGION = os.getenv("GCP_REGION", "us-central1")

if not all([GCP_PROJECT_ID, GCP_PUBSUB_SUBSCRIPTION]):
    log.critical("Erro: GCP_PROJECT_ID e GCP_PUBSUB_SUBSCRIPTION devem ser definidos.")
    raise RuntimeError("Missing GCP configuration")

# --- Clientes GCP ---
try:
    firestore_client = firestore.Client(project=GCP_PROJECT_ID)
    subscriber = pubsub_v1.SubscriberClient()
    subscription_path = subscriber.subscription_path(GCP_PROJECT_ID, GCP_PUBSUB_SUBSCRIPTION)
    log.info("Clientes GCP inicializados com sucesso.")
except Exception as e:
    log.critical(f"Erro ao inicializar clientes GCP: {e}")
    raise


# --- Pub/Sub Worker ---

def process_message(message: pubsub_v1.subscriber.message.Message):
    """Processa uma única mensagem Pub/Sub e a grava no Firestore."""
    try:
        log.info(f"Processando mensagem ID: {message.message_id}")
        body = json.loads(message.data.decode("utf-8"))

        event_id = str(uuid.uuid4())
        document_ref = firestore_client.collection(GCP_FIRESTORE_COLLECTION).document(event_id)
        document_ref.set({
            "event_id": event_id,
            "user_id": body.get("user_id", ""),
            "flag_name": body.get("flag_name", ""),
            "result": body.get("result", False),
            "timestamp": body.get("timestamp", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())),
        })

        log.info(f"Evento {event_id} (Flag: {body.get('flag_name', '')}) salvo no Firestore.")
        message.ack()

    except json.JSONDecodeError:
        log.error(f"Erro ao decodificar JSON da mensagem ID: {message.message_id}")
        message.nack()
    except Exception as e:
        log.error(f"Erro inesperado ao processar {message.message_id}: {e}")
        message.nack()


def pubsub_worker_loop():
    """Loop principal do worker que ouve a assinatura Pub/Sub."""
    log.info("Iniciando o worker Pub/Sub...")

    def callback(message: pubsub_v1.subscriber.message.Message) -> None:
        process_message(message)

    streaming_pull_future = subscriber.subscribe(subscription_path, callback=callback)
    log.info(f"Conectado à assinatura Pub/Sub: {subscription_path}")

    try:
        streaming_pull_future.result()
    except KeyboardInterrupt:
        streaming_pull_future.cancel()
    except Exception as e:
        log.error(f"Erro no loop principal do Pub/Sub: {e}")
        raise


# --- Servidor Flask (Apenas para Health Check) ---

app = Flask(__name__)


@app.route("/health")
def health():
    # Uma verificação de saúde real poderia checar a conexão com o DynamoDB/SQS
    return jsonify({"status": "ok"})


# --- Inicialização ---


def start_worker():
    """Inicia o worker Pub/Sub em uma thread separada."""
    worker_thread = threading.Thread(target=pubsub_worker_loop, daemon=True)
    worker_thread.start()


# Inicia o worker Pub/Sub em uma thread de background
# Isso garante que ele inicie tanto com 'flask run' quanto com 'gunicorn'
start_worker()

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8005))
    app.run(host="0.0.0.0", port=port, debug=False)
