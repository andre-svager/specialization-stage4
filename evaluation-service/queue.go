package main

import (
	"log"
	"time"
)

// EvaluationEvent is the message payload published on every flag evaluation.
type EvaluationEvent struct {
	UserID    string    `json:"user_id"`
	FlagName  string    `json:"flag_name"`
	Result    bool      `json:"result"`
	Timestamp time.Time `json:"timestamp"`
}

// EventPublisher abstracts the underlying message queue/broker so the app
// isn't tied to any single cloud provider's SDK.
type EventPublisher interface {
	Publish(event EvaluationEvent) error
	Close() error
}

// noopPublisher is used when no queue is configured — logs locally instead
// of failing, matching the original "SQS disabled" fallback behavior.
type noopPublisher struct{}

func (noopPublisher) Publish(event EvaluationEvent) error {
	log.Printf("[QUEUE_DISABLED] Evento: User '%s', Flag '%s', Result '%t'", event.UserID, event.FlagName, event.Result)
	return nil
}

func (noopPublisher) Close() error { return nil }

// sendEvaluationEvent publishes the evaluation result through the configured queue provider.
func (a *App) sendEvaluationEvent(userID, flagName string, result bool) {
	event := EvaluationEvent{
		UserID:    userID,
		FlagName:  flagName,
		Result:    result,
		Timestamp: time.Now().UTC(),
	}

	if a.Publisher == nil {
		log.Printf("[QUEUE_DISABLED] Evento: User '%s', Flag '%s', Result '%t'", userID, flagName, result)
		return
	}

	if err := a.Publisher.Publish(event); err != nil {
		log.Printf("Erro ao enviar mensagem para a fila: %v", err)
	}
}
