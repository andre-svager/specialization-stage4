package main

import (
	"context"
	"encoding/json"
	"log"

	"cloud.google.com/go/pubsub"
)

type pubsubPublisher struct {
	client *pubsub.Client
	topic  *pubsub.Topic
}

// newPubSubPublisher builds an EventPublisher backed by Google Cloud Pub/Sub.
func newPubSubPublisher(ctx context.Context, projectID, topicName string) (EventPublisher, error) {
	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		return nil, err
	}
	return &pubsubPublisher{client: client, topic: client.Topic(topicName)}, nil
}

func (p *pubsubPublisher) Publish(event EvaluationEvent) error {
	body, err := json.Marshal(event)
	if err != nil {
		return err
	}
	ctx := context.Background()
	result := p.topic.Publish(ctx, &pubsub.Message{Data: body})
	if _, err := result.Get(ctx); err != nil {
		return err
	}
	log.Printf("Evento publicado no Pub/Sub (Flag: %s)", event.FlagName)
	return nil
}

func (p *pubsubPublisher) Close() error {
	p.topic.Stop()
	return p.client.Close()
}
