# Project: Notification Service

Go microservice for sending push, email, and SMS notifications.

## Stack
- Go 1.22
- PostgreSQL
- go test for tests

## Conventions
- Handlers in `internal/handlers/`
- Provider integrations in `internal/providers/`
- Exemplar: `internal/handlers/email_handler.go`

## Commands
- `go test ./...` — run tests
- `golangci-lint run` — lint
