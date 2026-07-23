package main

import (
	"encoding/json"
	"log"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
)

type sqsPublisher struct {
	svc      *sqs.SQS
	queueURL string
}

// newSQSPublisher builds an EventPublisher backed by AWS SQS.
func newSQSPublisher(queueURL, region string) (EventPublisher, error) {
	sess, err := session.NewSession(&aws.Config{Region: aws.String(region)})
	if err != nil {
		return nil, err
	}
	return &sqsPublisher{svc: sqs.New(sess), queueURL: queueURL}, nil
}

func (p *sqsPublisher) Publish(event EvaluationEvent) error {
	body, err := json.Marshal(event)
	if err != nil {
		return err
	}
	_, err = p.svc.SendMessage(&sqs.SendMessageInput{
		MessageBody: aws.String(string(body)),
		QueueUrl:    aws.String(p.queueURL),
	})
	if err == nil {
		log.Printf("Evento publicado no SQS (Flag: %s)", event.FlagName)
	}
	return err
}

func (p *sqsPublisher) Close() error { return nil }
