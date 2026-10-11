# ReplyX + Tiledesk integration blueprint

Status: design / integration foundation only. No runtime integration is implemented by this document.
Base: ReplyX `develop`. Source references: https://github.com/Skylordxgit/ReplyX and https://github.com/Tiledesk/tiledesk .

## Architectural decision
Retain ReplyX (Rails, Vue, PostgreSQL, Redis/Sidekiq) as the authoritative customer-support application. Connect narrowly scoped Tiledesk services as separate, containerized optional services through a ReplyX-owned adapter, never by merging unrelated Git histories or sharing databases.

Tiledesk's `tiledesk` repository is principally deployment orchestration; actual chatbot runtime, design studio, dashboard, and chat transport are separate images/projects. Pin and inspect each component version and individual license before reuse. The deployment repo LICENSE is MIT; this does not establish licensing for all distributed images or enterprise-only features.

## Core invariants
1. ReplyX owns tenant, user, role, inbox, channel credentials, contact, conversation, assignment, status, messaging and transcript persistence.
2. Tiledesk may draft an automated response, request handoff, or propose workflow actions. ReplyX authorizes and persists every effect. Never let Tiledesk write directly to ReplyX tables.
3. No duplication of channel webhooks: Meta/WhatsApp/Telegram events enter ReplyX once. No second responder after human takeover.
4. Every integration event contains account_id, inbox_id, conversation_id, message_id, event_id, timestamp, schema_version, correlation_id, and trace_id; UUID event_id is deduplicated.
5. Every integration call is tenant-scoped and signed/authenticated; redact PII from logs and retain only necessary data.
6. The integration is disabled by default per workspace. Emergency kill switch must fall back to normal human ReplyX handling.
7. Preserve existing custom agent-password flows, agent analytics, and production schemas.

## Planned data flow
Channel -> ReplyX inbound webhook -> persisted message -> Sidekiq integration dispatch (after commit) -> ReplyX integration adapter -> optional Tiledesk bot/flow service -> validated proposed action -> ReplyX authorization -> ReplyX outbound messaging/assignment -> original channel.

Outbound processing must implement idempotency, bounded retries, dead-letter storage, delivery reconciliation, rate limiting and bot/human ownership locks. Never silently retry non-idempotent channel sends.

## Adapter contract proposal (version 1, not implemented)
- `POST /internal/automation/v1/events`: dispatch standardized ReplyX event, signed service-to-service. Return acceptance ID; asynchronous result preferred.
- `POST /internal/automation/v1/actions`: external worker proposes one of `reply`, `handoff`, `tag`, `assign_team`, `close`. ReplyX validates roles, account boundaries, and message state.
- `GET /internal/automation/v1/health`: readiness and build/version (restricted internally).
- Store mappings of ReplyX account/inbox/bot ID to Tiledesk project/flow ID, encrypted secrets, delivery status and execution runs.
- Define contracts in OpenAPI/JSON Schema, write contract tests and replay tests before deployment.

## Delivery phases
### Phase 0: audit and licensing
- Inventory desired features and APIs in Tiledesk chatbot, Design Studio, server, and AI services. Confirm component-level licensing and any paid/enterprise limitations.
- Capture current ReplyX baseline; back up production database and files. Review ReplyX local/production Compose, auth, integration scopes, secret handling.
- Prove isolated Tiledesk sandbox starts with pinned images, strong generated credentials, and non-public dependency ports. Tiledesk demo documentation uses default admin credentials; never deploy defaults publicly.

### Phase 1: adapter MVP
- Add ReplyX `tiledesk_automation` feature flag, tenant-specific config, health/status UI (admin only), audit logs and service credentials.
- Dispatch inbound message to sandbox via Sidekiq with after-commit semantics and replay protection.
- Support a single chatbot auto-reply and explicit handoff on a test inbox; enforce one bot/human owner and safe fallback.
- Implement integration tests for duplicate webhooks, timeouts, bad signatures, cross-workspace requests, cancellation, no channel credentials exposed to Tiledesk.

### Phase 2: visual workflow builder
- Embed/link a vetted editor with SSO or tightly scoped token exchange. Prefer exporting versioned flow JSON rather than coupling to the full Tiledesk dashboard.
- Allow triggers, conditions, business hours, tags, routing, handoff, response templates, AI node, wait with cancellation.
- Publish flow versions; simulate a flow against sample events; rollback. Agent view remains ReplyX.

### Phase 3: AI knowledge and observability
- Tenant-isolated KB ingestion, consent/retention controls, retrieval/citation controls, prompt injection safeguards, approved responses, language fallback.
- Metrics: bot containment, transfer rate, time to first human response, response accuracy review, failures, task queue backlog, cost per resolved conversation.

### Phase 4: production hardening
- Load-test 3k+ inbound chats/day with burst and concurrent-agent scenarios, measure p95 and error rates.
- Keep Tiledesk optional; use queues, independent scaling, circuit breaker, observability, alerts, rollback.
- Explicit security assessment, vulnerability scanning, dependency updates, incident response runbook.

## First implementation slice / acceptance criteria
A sandbox agent receives a message in ReplyX. The bot proposes a reply through the adapter and ReplyX sends it once via the existing channel. Manual takeover suppresses all later bot replies. Across two workspace tenants, no event, secret, KB entry or flow can cross tenant boundaries. An offline Tiledesk worker does not block human replies and failed events remain inspectable and replayable.

## Do not do
- Do not overwrite `develop`, do not merge `Tiledesk/tiledesk` as a Git remote, do not import full Tiledesk dashboard and Chat21 messaging stack wholesale.
- Do not reuse default `admin@tiledesk.com`/`superadmin`, demo secrets, or hardcoded tokens from example Compose.
- Do not assume MIT deployment repo license covers unrelated components or private enterprise builds.
