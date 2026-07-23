package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/joho/godotenv"
)

// Contexto global para o Redis
var ctx = context.Background()

// App struct para injeção de dependência
type App struct {
	RedisClient         *redis.Client
	Publisher           EventPublisher
	HttpClient          *http.Client
	FlagServiceURL      string
	TargetingServiceURL string
}

func main() {
	_ = godotenv.Load() // Carrega .env para dev local

	// --- Configuração ---
	port := os.Getenv("PORT")
	if port == "" {
		port = "8004"
	}

	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		log.Fatal("REDIS_URL deve ser definida (ex: redis://localhost:6379)")
	}

	flagSvcURL := os.Getenv("FLAG_SERVICE_URL")
	if flagSvcURL == "" {
		log.Fatal("FLAG_SERVICE_URL deve ser definida")
	}

	targetingSvcURL := os.Getenv("TARGETING_SERVICE_URL")
	if targetingSvcURL == "" {
		log.Fatal("TARGETING_SERVICE_URL deve ser definida")
	}

	// --- Configuração de fila (agnóstica de provedor) ---
	var publisher EventPublisher = noopPublisher{}

	switch provider := os.Getenv("QUEUE_PROVIDER"); provider {
	case "sqs":
		queueURL := os.Getenv("AWS_SQS_URL")
		region := os.Getenv("AWS_REGION")
		if queueURL == "" || region == "" {
			log.Fatal("AWS_SQS_URL e AWS_REGION devem ser definidos quando QUEUE_PROVIDER=sqs")
		}
		p, err := newSQSPublisher(queueURL, region)
		if err != nil {
			log.Fatalf("Não foi possível criar cliente SQS: %v", err)
		}
		publisher = p
		log.Println("Publisher SQS inicializado com sucesso.")

	case "pubsub":
		projectID := os.Getenv("GCP_PROJECT_ID")
		topic := os.Getenv("PUBSUB_TOPIC")
		if projectID == "" || topic == "" {
			log.Fatal("GCP_PROJECT_ID e PUBSUB_TOPIC devem ser definidos quando QUEUE_PROVIDER=pubsub")
		}
		p, err := newPubSubPublisher(ctx, projectID, topic)
		if err != nil {
			log.Fatalf("Não foi possível criar cliente Pub/Sub: %v", err)
		}
		publisher = p
		log.Println("Publisher Pub/Sub inicializado com sucesso.")

	default:
		log.Println("Atenção: QUEUE_PROVIDER não definido. Eventos não serão enviados.")
	}

	// --- Inicializa Clientes ---

	// Cliente Redis
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("Não foi possível parsear a URL do Redis: %v", err)
	}
	rdb := redis.NewClient(opt)
	if _, err := rdb.Ping(ctx).Result(); err != nil {
		log.Fatalf("Não foi possível conectar ao Redis: %v", err)
	}
	log.Println("Conectado ao Redis com sucesso!")

	// Cliente HTTP (com timeout)
	httpClient := &http.Client{
		Timeout: 5 * time.Second,
	}

	// Cria a instância da App
	app := &App{
		RedisClient:         rdb,
		Publisher:           publisher,
		HttpClient:          httpClient,
		FlagServiceURL:      flagSvcURL,
		TargetingServiceURL: targetingSvcURL,
	}

	// --- Rotas ---
	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.healthHandler)
	mux.HandleFunc("/evaluate", app.evaluationHandler)

	log.Printf("Serviço de Avaliação (Go) rodando na porta %s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}
