-- Core read model: cases, their attempts, and the event log.
-- Table named payment_case because CASE is a reserved SQL keyword.

CREATE TABLE payment_case (
  id                 char(26)    PRIMARY KEY,
  customer_ref       text        NOT NULL,
  amount_minor       integer     NOT NULL CHECK (amount_minor > 0),
  currency           char(3)     NOT NULL DEFAULT 'EUR',
  status             text        NOT NULL,
  simulation_profile text        NOT NULL DEFAULT 'ALWAYS_SUCCEED',
  attempt_count      integer     NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT payment_case_status_check CHECK (status IN (
    'NEW', 'IN_PROGRESS', 'FAILED',
    'RETRY_PENDING', 'RETRY_IN_PROGRESS',
    'RESOLVED', 'PERMANENTLY_FAILED'
  ))
);

CREATE INDEX payment_case_status_created_idx ON payment_case (status, created_at DESC, id DESC);

CREATE INDEX payment_case_created_idx ON payment_case (created_at DESC, id DESC);

CREATE TABLE payment_attempt (
  id             char(26)    PRIMARY KEY,
  case_id        char(26)    NOT NULL REFERENCES payment_case(id) ON DELETE CASCADE,
  attempt_number integer     NOT NULL CHECK (attempt_number > 0),
  status         text        NOT NULL,
  provider_ref   text,
  failure_code   text,
  failure_reason text,
  started_at     timestamptz NOT NULL DEFAULT now(),
  completed_at   timestamptz,

  CONSTRAINT payment_attempt_status_check CHECK (status IN (
    'PENDING', 'IN_FLIGHT', 'SUCCEEDED',
    'TIMED_OUT', 'FAILED_RETRYABLE', 'FAILED_PERMANENT'
  )),

  CONSTRAINT payment_attempt_failure_code_check CHECK (failure_code IS NULL OR failure_code IN (
    'INSUFFICIENT_FUNDS', 'TIMEOUT', 'TEMPORARY_MANDATE_ERROR',
    'ACCOUNT_CLOSED', 'MANDATE_REVOKED', 'FRAUD_SUSPECTED'
  )),

  CONSTRAINT payment_attempt_case_number_unique UNIQUE (case_id, attempt_number)
);

CREATE INDEX payment_attempt_case_idx ON payment_attempt (case_id, attempt_number DESC);

CREATE TABLE payment_event (
  id             char(26)    PRIMARY KEY,
  case_id        char(26)    NOT NULL REFERENCES payment_case(id) ON DELETE CASCADE,
  attempt_id     char(26)    REFERENCES payment_attempt(id) ON DELETE SET NULL,
  type           text        NOT NULL,
  payload        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  correlation_id char(26)    NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT payment_event_type_check CHECK (type IN (
    'CASE_CREATED', 'ATTEMPT_STARTED', 'ATTEMPT_SUCCEEDED',
    'ATTEMPT_FAILED', 'RETRY_REQUESTED', 'RETRY_DENIED'
  ))
);

CREATE INDEX payment_event_case_created_idx ON payment_event (case_id, created_at DESC);