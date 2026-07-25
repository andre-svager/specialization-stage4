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

# --- OpenTelemetry Imports ---
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes
from opentelemetry.trace import SpanKind, Status, StatusCode
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor

# Configura o logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
log = logging.getLogger(__name__)

# Inject trace_id and span_id into Python standard logs for Loki correlation
LoggingInstrumentor().instrument(set_logging_format=True)

# Carrega .env para desenvolvimento local
load_dotenv()

# --- Configuração ---
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
GCP_PUBSUB_SUBSCRIPTION = os.getenv("GCP_PUBSUB_SUBSCRIPTION")
GCP_FIRESTORE_COLLECTION = os.getenv("GCP_FIRESTORE_COLLECTION", "ToggleMasterAnalytics")
GCP_REGION = os.getenv("GCP_REGION", "us-central1")
OTEL_COLLECTOR_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.monitoring.svc.cluster.local:4317")

if not all([GCP_PROJECT_ID, GCP_PUBSUB_SUBSCRIPTION]):
    log.critical("Erro: GCP_PROJECT_ID e GCP_PUBSUB_SUBSCRIPTION devem ser definidos.")
    raise RuntimeError("Missing GCP configuration")

# --- OTel Setup & TracerProvider Initialization ---
resource = Resource.create(attributes={
    ResourceAttributes.SERVICE_NAME: "analytics-service",
    ResourceAttributes.SERVICE_VERSION: "1.0.0",
    ResourceAttributes.DEPLOYMENT_ENVIRONMENT: os.getenv("ENVIRONMENT", "production")
})

tracer_provider = TracerProvider(resource=resource)
otlp_exporter = OTLPSpanExporter(endpoint=OTEL_COLLECTOR_ENDPOINT, insecure=True)
tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(tracer_provider)

tracer = trace.get_tracer(__name__, "1.0.0")

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
    """Processa uma única mensagem Pub/Sub e a grava no Firestore com tracing OTel."""
    # 1. Extrai o contexto do trace das propriedades/atributos da mensagem do Pub/Sub
    carrier = dict(message.attributes) if message.attributes else {}
    extracted_context = TraceContextTextMapPropagator().extract(carrier=carrier)

    # 2. Inicia o Span do Worker como CONSUMER ligado ao trace original do publisher
    with tracer.start_as_current_span(
        "pubsub.process_message",
        context=extracted_context,
        kind=SpanKind.CONSUMER,
        attributes={
            "messaging.system": "gcp_pubsub",
            "messaging.destination": GCP_PUBSUB_SUBSCRIPTION,
            "messaging.message_id": message.message_id,
        }
    ) as span:
        try:
            log.info(f"Processando mensagem ID: {message.message_id}")
            body = json.loads(message.data.decode("utf-8"))

            user_id = body.get("user_id", "")
            flag_name = body.get("flag_name", "")
            result = body.get("result", False)

            span.set_attribute("analytics.user_id", user_id)
            span.set_attribute("analytics.flag_name", flag_name)
            span.set_attribute("analytics.result", result)

            event_id = str(uuid.uuid4())
            
            # Sub-span específico para o salvamento no Firestore
            with tracer.start_as_current_span("db.firestore.set", kind=SpanKind.CLIENT) as db_span:
                db_span.set_attribute("db.system", "firestore")
                db_span.set_attribute("db.collection", GCP_FIRESTORE_COLLECTION)
                db_span.set_attribute("db.document_id", event_id)

                document_ref = firestore_client.collection(GCP_FIRESTORE_COLLECTION).document(event_id)
                document_ref.set({
                    "event_id": event_id,
                    "user_id": user_id,
                    "flag_name": flag_name,
                    "result": result,
                    "timestamp": body.get("timestamp", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())),
                })

            log.info(f"Evento {event_id} (Flag: {flag_name}) salvo no Firestore.")
            message.ack()

        except json.JSONDecodeError as exc:
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, "JSON Decode Error"))
            log.error(f"Erro ao decodificar JSON da mensagem ID: {message.message_id}")
            message.nack()
        except Exception as e:
            span.record_exception(e)
            span.set_status(Status(StatusCode.ERROR, str(e)))
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

# Instrumentação automática para rotas do Flask
FlaskInstrumentor().instrument_app(app)


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


# --- Inicialização ---

def start_worker():
    """Inicia o worker Pub/Sub em uma thread separada."""
    worker_thread = threading.Thread(target=pubsub_worker_loop, daemon=True)
    worker_thread.start()


start_worker()

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8005))
    app.run(host="0.0.0.0", port=port, debug=False)