# Spec: Add SMS and Push Notification Channels

Add SMS (via Twilio) and push notification (via FCM) delivery channels.

## Architecture Decision
- `internal/handlers/email_handler.go` — reference implementation
- `internal/providers/email_provider.go` — provider pattern to follow
- `internal/dispatcher/dispatcher.go` — dispatcher that routes to providers

## Exemplar
`internal/handlers/email_handler.go`

## Implementation Plan

### Task 1 — SMS handler and Twilio provider [INDEPENDENT]
Implement `SMSHandler` and `TwilioProvider` following the email pattern.
Acceptance: `internal/handlers/sms_handler.go` and `internal/providers/twilio_provider.go` exist with tests passing.

### Task 2 — Push notification handler and FCM provider [INDEPENDENT]
Implement `PushHandler` and `FCMProvider` following the email pattern.
Acceptance: `internal/handlers/push_handler.go` and `internal/providers/fcm_provider.go` exist with tests passing.

### Task 3 — Register both channels in dispatcher [SEQUENTIAL]
Wire SMS and Push into the dispatcher routing table.
Acceptance: Dispatcher routes `channel="sms"` and `channel="push"` to the new handlers.
