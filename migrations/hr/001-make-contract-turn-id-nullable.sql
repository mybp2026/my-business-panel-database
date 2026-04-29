-- Migration: hr/001-make-contract-turn-id-nullable
-- Allows creating contracts without a turn_id (e.g. admin employee during tenant onboarding,
-- before any turn has been configured for the branch).

ALTER TABLE hr_schema.contract
  ALTER COLUMN turn_id DROP NOT NULL;
