-- ======================================================
-- MIGRATION: pos/026-cash-session-shift-report.sql
-- Adds shift-close report to cash_register_session:
--   * Per-method sales totals (cash, debit, credit, transfer, points)
--   * Overall sales total
--   * Mismatch flag + amount + direction (surplus / shortage)
-- Adds session_group_sales for per-group breakdown.
-- Replaces the bare UPDATE close with a stored procedure that
-- computes the full report atomically on session close.
-- ======================================================

BEGIN;

-- ── 1. Report columns on cash_register_session ─────────────────────────

ALTER TABLE pos_schema.cash_register_session
    ADD COLUMN IF NOT EXISTS cash_sales_amount     NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS debit_sales_amount    NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS credit_sales_amount   NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS transfer_sales_amount NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS points_sales_amount   NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS total_sales_amount    NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS mismatch              BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS mismatch_amount       NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS mismatch_type         VARCHAR(10)
        CHECK (mismatch_type IN ('surplus', 'shortage'));

-- ── 2. Per-group sales breakdown table ─────────────────────────────────

CREATE TABLE IF NOT EXISTS pos_schema.session_group_sales (
    session_group_sales_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cash_register_session_id uuid NOT NULL
        REFERENCES pos_schema.cash_register_session(cash_register_session_id)
        ON DELETE CASCADE,
    tenant_product_group_id  uuid NOT NULL,
    group_name               VARCHAR(200) NOT NULL,
    total_amount             NUMERIC(14, 2) NOT NULL,
    UNIQUE (cash_register_session_id, tenant_product_group_id)
);

CREATE INDEX IF NOT EXISTS idx_session_group_sales_session
    ON pos_schema.session_group_sales(cash_register_session_id);

-- ── 3. Stored procedure ─────────────────────────────────────────────────
-- close_cash_register_session(session_id, closing_amount)
-- Aggregates payments + sales-by-group, detects mismatch, closes session.

CREATE OR REPLACE FUNCTION pos_schema.close_cash_register_session(
    p_session_id     uuid,
    p_closing_amount numeric
)
RETURNS pos_schema.cash_register_session
LANGUAGE plpgsql
AS $$
DECLARE
    v_session             pos_schema.cash_register_session%ROWTYPE;
    v_cash_sales          NUMERIC(14, 2) := 0;
    v_debit_sales         NUMERIC(14, 2) := 0;
    v_credit_sales        NUMERIC(14, 2) := 0;
    v_transfer_sales      NUMERIC(14, 2) := 0;
    v_points_sales        NUMERIC(14, 2) := 0;
    v_total_sales         NUMERIC(14, 2) := 0;
    v_expected_cash       NUMERIC(14, 2);
    v_mismatch            BOOLEAN        := FALSE;
    v_mismatch_amt        NUMERIC(14, 2) := NULL;
    v_mismatch_type       VARCHAR(10)    := NULL;
BEGIN
    -- Lock + validate
    SELECT * INTO v_session
    FROM pos_schema.cash_register_session
    WHERE cash_register_session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session not found: %', p_session_id;
    END IF;

    IF NOT v_session.is_active THEN
        RAISE EXCEPTION 'Session % is already closed', p_session_id;
    END IF;

    -- Aggregate payments by method (payment_method_id: 1=cash 2=debit 3=credit 4=transfer 5=points)
    SELECT
        COALESCE(SUM(cp.payment_amount) FILTER (WHERE cp.payment_method_id = 1), 0),
        COALESCE(SUM(cp.payment_amount) FILTER (WHERE cp.payment_method_id = 2), 0),
        COALESCE(SUM(cp.payment_amount) FILTER (WHERE cp.payment_method_id = 3), 0),
        COALESCE(SUM(cp.payment_amount) FILTER (WHERE cp.payment_method_id = 4), 0),
        COALESCE(SUM(cp.payment_amount) FILTER (WHERE cp.payment_method_id = 5), 0)
    INTO v_cash_sales, v_debit_sales, v_credit_sales, v_transfer_sales, v_points_sales
    FROM pos_schema.customer_payment cp
    INNER JOIN pos_schema.cash_register_sale crs ON crs.sale_id = cp.sale_id
    WHERE crs.cash_register_session_id = p_session_id;

    v_total_sales := v_cash_sales + v_debit_sales + v_credit_sales
                     + v_transfer_sales + v_points_sales;

    -- Mismatch: closing_amount should equal opening_amount + cash collected
    v_expected_cash := v_session.opening_amount + v_cash_sales;
    IF ABS(p_closing_amount - v_expected_cash) > 0.01 THEN
        v_mismatch      := TRUE;
        v_mismatch_amt  := ROUND(ABS(p_closing_amount - v_expected_cash), 2);
        v_mismatch_type := CASE
            WHEN p_closing_amount > v_expected_cash THEN 'surplus'
            ELSE 'shortage'
        END;
    END IF;

    -- Insert per-group sales (ignore groups with no sales; upsert safe on re-run)
    INSERT INTO pos_schema.session_group_sales
        (cash_register_session_id, tenant_product_group_id, group_name, total_amount)
    SELECT
        p_session_id,
        tpg.tenant_product_group_id,
        tpg.group_name,
        ROUND(SUM(si.total_price), 2)
    FROM pos_schema.sale_item si
    INNER JOIN pos_schema.cash_register_sale crs_link
        ON crs_link.sale_id = si.sale_id
    INNER JOIN general_schema.product_variant_group_assignment pvga
        ON  pvga.product_variant_id = si.product_variant_id
        AND pvga.tenant_id          = si.tenant_id
    INNER JOIN general_schema.tenant_product_group tpg
        ON tpg.tenant_product_group_id = pvga.tenant_product_group_id
    WHERE crs_link.cash_register_session_id = p_session_id
    GROUP BY tpg.tenant_product_group_id, tpg.group_name
    ON CONFLICT (cash_register_session_id, tenant_product_group_id)
    DO UPDATE SET total_amount = EXCLUDED.total_amount;

    -- Close the session and stamp all report fields
    UPDATE pos_schema.cash_register_session
    SET
        closed_at             = NOW(),
        closing_amount        = p_closing_amount,
        is_active             = FALSE,
        cash_sales_amount     = v_cash_sales,
        debit_sales_amount    = v_debit_sales,
        credit_sales_amount   = v_credit_sales,
        transfer_sales_amount = v_transfer_sales,
        points_sales_amount   = v_points_sales,
        total_sales_amount    = v_total_sales,
        mismatch              = v_mismatch,
        mismatch_amount       = CASE WHEN v_mismatch THEN v_mismatch_amt  ELSE NULL END,
        mismatch_type         = CASE WHEN v_mismatch THEN v_mismatch_type ELSE NULL END,
        updated_at            = NOW()
    WHERE cash_register_session_id = p_session_id
    RETURNING * INTO v_session;

    RETURN v_session;
END;
$$;

COMMIT;


-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP FUNCTION IF EXISTS pos_schema.close_cash_register_session(uuid, numeric);
-- DROP TABLE IF EXISTS pos_schema.session_group_sales CASCADE;
-- ALTER TABLE pos_schema.cash_register_session
--     DROP COLUMN IF EXISTS cash_sales_amount,
--     DROP COLUMN IF EXISTS debit_sales_amount,
--     DROP COLUMN IF EXISTS credit_sales_amount,
--     DROP COLUMN IF EXISTS transfer_sales_amount,
--     DROP COLUMN IF EXISTS points_sales_amount,
--     DROP COLUMN IF EXISTS total_sales_amount,
--     DROP COLUMN IF EXISTS mismatch,
--     DROP COLUMN IF EXISTS mismatch_amount,
--     DROP COLUMN IF EXISTS mismatch_type;
-- COMMIT;
