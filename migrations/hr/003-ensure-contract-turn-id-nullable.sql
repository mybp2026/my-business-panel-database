-- ============================================================
-- Migration HR-003: ensure contract.turn_id is nullable
-- ------------------------------------------------------------
--   La migración 001 ya intentaba dejar la columna como NULL,
--   pero algunas instancias se levantaron desde un schema más
--   antiguo y mantienen la constraint. Esta versión es
--   idempotente: si la columna ya admite NULL no hace nada;
--   si no, le quita el NOT NULL.
--
--   Razón de negocio: durante el onboarding de un nuevo tenant
--   no se ha definido ningún turno todavía, así que el contrato
--   del primer admin se crea sin turn_id.
-- ============================================================

BEGIN;

ALTER TABLE hr_schema.contract
    ALTER COLUMN turn_id DROP NOT NULL;

COMMIT;
