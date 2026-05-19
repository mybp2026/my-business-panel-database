-- ======================================================
-- MIGRATION: pos/036-cash-session-user-declared-amounts.sql
-- Audit:
--   Backend pos.queries.ts findSessions selects user_cash_amount,
--   user_debit_amount, user_credit_amount, user_transfer_amount.
--   Columns missing, raises 42703 on any session list / close cycle.
--   Migration 035 stored user-declared inputs in *_sales_amount,
--   conflating system totals with user inputs.
--
--   This migration:
--     * Adds dedicated user_*_amount columns for user-declared totals.
--     * Recreates close_cash_register_session so:
--         - *_sales_amount columns store SYSTEM-calculated totals
--           (aggregated from session_payment_method_sales).
--         - user_*_amount columns store the user-declared inputs.
--     * Preserves arqueo (mismatch) logic from migration 035 exactly.
--
--   Existing closed sessions are not backfilled. Their *_sales_amount
--   columns retain the values written by migration 035 (user input),
--   and their new user_*_amount columns remain NULL. New closures
--   write both column groups with the correct semantics.
-- ======================================================
 BEGIN;

-- 1. Dedicated user-declared amount columns ---------------------------

ALTER TABLE pos_schema.cash_register_session ADD COLUMN IF NOT EXISTS user_cash_amount NUMERIC(14, 2),
                                                                                       ADD COLUMN IF NOT EXISTS user_debit_amount NUMERIC(14, 2),
                                                                                                                                  ADD COLUMN IF NOT EXISTS user_credit_amount NUMERIC(14, 2),
                                                                                                                                                                              ADD COLUMN IF NOT EXISTS user_transfer_amount NUMERIC(14, 2);

COMMENT ON COLUMN pos_schema.cash_register_session.user_cash_amount IS 'User-declared cash total at shift close. NULL = legacy session.';

COMMENT ON COLUMN pos_schema.cash_register_session.user_debit_amount IS 'User-declared debit total at shift close. NULL = legacy session.';

COMMENT ON COLUMN pos_schema.cash_register_session.user_credit_amount IS 'User-declared credit total at shift close. NULL = legacy session.';

COMMENT ON COLUMN pos_schema.cash_register_session.user_transfer_amount IS 'User-declared transfer total at shift close. NULL = legacy session.';

-- 2. Recreate close_cash_register_session -----------------------------
--    Same arqueo logic as 035. Difference: persist system totals in
--    *_sales_amount and user-declared inputs in user_*_amount.

CREATE OR REPLACE FUNCTION pos_schema.close_cash_register_session(p_session_id uuid, p_closing_amount numeric, p_user_cash numeric DEFAULT 0, p_user_debit numeric DEFAULT 0, p_user_credit numeric DEFAULT 0, p_user_transfer numeric DEFAULT 0) RETURNS pos_schema.cash_register_session LANGUAGE plpgsql AS $$
DECLARE
    v_session             pos_schema.cash_register_session%ROWTYPE;
    v_system_cash         NUMERIC(14, 2) := 0;
    v_system_debit        NUMERIC(14, 2) := 0;
    v_system_credit       NUMERIC(14, 2) := 0;
    v_system_transfer     NUMERIC(14, 2) := 0;
    v_system_points       NUMERIC(14, 2) := 0;
    v_system_total_sales  NUMERIC(14, 2) := 0;
    v_expected_cash       NUMERIC(14, 2);
    v_mismatch            BOOLEAN        := FALSE;
    v_mismatch_amt        NUMERIC(14, 2) := 0;
    v_mismatch_type       VARCHAR(10)    := NULL;
BEGIN
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

    -- Dynamic calculation for ALL payment methods (system values)
    INSERT INTO pos_schema.session_payment_method_sales
        (cash_register_session_id, payment_method_id, total_amount)
    SELECT
        p_session_id,
        cp.payment_method_id,
        COALESCE(SUM(cp.payment_amount), 0)
    FROM pos_schema.customer_payment cp
    INNER JOIN pos_schema.cash_register_sale crs ON crs.sale_id = cp.sale_id
    WHERE crs.cash_register_session_id = p_session_id
    GROUP BY cp.payment_method_id
    ON CONFLICT (cash_register_session_id, payment_method_id)
    DO UPDATE SET total_amount = EXCLUDED.total_amount;

    -- Get system values for specific methods
    -- (IDs: 1=cash, 2=debit, 3=credit, 4=transfer, 5=points)
    SELECT COALESCE(total_amount, 0) INTO v_system_cash
    FROM pos_schema.session_payment_method_sales
    WHERE cash_register_session_id = p_session_id AND payment_method_id = 1;

    SELECT COALESCE(total_amount, 0) INTO v_system_debit
    FROM pos_schema.session_payment_method_sales
    WHERE cash_register_session_id = p_session_id AND payment_method_id = 2;

    SELECT COALESCE(total_amount, 0) INTO v_system_credit
    FROM pos_schema.session_payment_method_sales
    WHERE cash_register_session_id = p_session_id AND payment_method_id = 3;

    SELECT COALESCE(total_amount, 0) INTO v_system_transfer
    FROM pos_schema.session_payment_method_sales
    WHERE cash_register_session_id = p_session_id AND payment_method_id = 4;

    SELECT COALESCE(total_amount, 0) INTO v_system_points
    FROM pos_schema.session_payment_method_sales
    WHERE cash_register_session_id = p_session_id AND payment_method_id = 5;

    SELECT COALESCE(SUM(total_amount), 0) INTO v_system_total_sales
    FROM pos_schema.session_payment_method_sales
    WHERE cash_register_session_id = p_session_id;

    -- Arqueo logic (unchanged from 035):
    v_expected_cash := v_session.opening_amount + v_system_cash;

    v_mismatch_amt := p_closing_amount
        - (v_expected_cash + v_system_debit + v_system_credit + v_system_transfer);

    IF ABS(v_mismatch_amt) > 0.01 THEN
        v_mismatch := TRUE;
        v_mismatch_type := CASE WHEN v_mismatch_amt > 0 THEN 'surplus' ELSE 'shortage' END;
    END IF;

    -- Per-group breakdown (legacy)
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

    UPDATE pos_schema.cash_register_session
    SET
        closed_at             = NOW(),
        closing_amount        = p_closing_amount,
        is_active             = FALSE,
        cash_sales_amount     = v_system_cash,
        debit_sales_amount    = v_system_debit,
        credit_sales_amount   = v_system_credit,
        transfer_sales_amount = v_system_transfer,
        points_sales_amount   = v_system_points,
        total_sales_amount    = v_system_total_sales,
        user_cash_amount      = p_user_cash,
        user_debit_amount     = p_user_debit,
        user_credit_amount    = p_user_credit,
        user_transfer_amount  = p_user_transfer,
        mismatch              = v_mismatch,
        mismatch_amount       = ABS(v_mismatch_amt),
        mismatch_type         = v_mismatch_type,
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
--
-- -- Restore 035 function signature/body
-- CREATE OR REPLACE FUNCTION pos_schema.close_cash_register_session(
--     p_session_id     uuid,
--     p_closing_amount numeric,
--     p_user_cash      numeric DEFAULT 0,
--     p_user_debit     numeric DEFAULT 0,
--     p_user_credit    numeric DEFAULT 0,
--     p_user_transfer  numeric DEFAULT 0
-- )
-- RETURNS pos_schema.cash_register_session
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--     v_session             pos_schema.cash_register_session%ROWTYPE;
--     v_system_cash         NUMERIC(14, 2) := 0;
--     v_system_debit        NUMERIC(14, 2) := 0;
--     v_system_credit       NUMERIC(14, 2) := 0;
--     v_system_transfer     NUMERIC(14, 2) := 0;
--     v_system_points       NUMERIC(14, 2) := 0;
--     v_system_total_sales  NUMERIC(14, 2) := 0;
--     v_expected_cash       NUMERIC(14, 2);
--     v_mismatch            BOOLEAN        := FALSE;
--     v_mismatch_amt        NUMERIC(14, 2) := 0;
--     v_mismatch_type       VARCHAR(10)    := NULL;
-- BEGIN
--     SELECT * INTO v_session FROM pos_schema.cash_register_session
--     WHERE cash_register_session_id = p_session_id FOR UPDATE;
--     IF NOT FOUND THEN RAISE EXCEPTION 'Session not found: %', p_session_id; END IF;
--     IF NOT v_session.is_active THEN RAISE EXCEPTION 'Session % is already closed', p_session_id; END IF;
--     INSERT INTO pos_schema.session_payment_method_sales
--         (cash_register_session_id, payment_method_id, total_amount)
--     SELECT p_session_id, cp.payment_method_id, COALESCE(SUM(cp.payment_amount), 0)
--     FROM pos_schema.customer_payment cp
--     INNER JOIN pos_schema.cash_register_sale crs ON crs.sale_id = cp.sale_id
--     WHERE crs.cash_register_session_id = p_session_id
--     GROUP BY cp.payment_method_id
--     ON CONFLICT (cash_register_session_id, payment_method_id)
--     DO UPDATE SET total_amount = EXCLUDED.total_amount;
--     SELECT COALESCE(total_amount, 0) INTO v_system_cash FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 1;
--     SELECT COALESCE(total_amount, 0) INTO v_system_debit FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 2;
--     SELECT COALESCE(total_amount, 0) INTO v_system_credit FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 3;
--     SELECT COALESCE(total_amount, 0) INTO v_system_transfer FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 4;
--     SELECT COALESCE(total_amount, 0) INTO v_system_points FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 5;
--     SELECT COALESCE(SUM(total_amount), 0) INTO v_system_total_sales FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id;
--     v_expected_cash := v_session.opening_amount + v_system_cash;
--     v_mismatch_amt := p_closing_amount - (v_expected_cash + v_system_debit + v_system_credit + v_system_transfer);
--     IF ABS(v_mismatch_amt) > 0.01 THEN
--         v_mismatch := TRUE;
--         v_mismatch_type := CASE WHEN v_mismatch_amt > 0 THEN 'surplus' ELSE 'shortage' END;
--     END IF;
--     INSERT INTO pos_schema.session_group_sales (cash_register_session_id, tenant_product_group_id, group_name, total_amount)
--     SELECT p_session_id, tpg.tenant_product_group_id, tpg.group_name, ROUND(SUM(si.total_price), 2)
--     FROM pos_schema.sale_item si
--     INNER JOIN pos_schema.cash_register_sale crs_link ON crs_link.sale_id = si.sale_id
--     INNER JOIN general_schema.product_variant_group_assignment pvga ON pvga.product_variant_id = si.product_variant_id AND pvga.tenant_id = si.tenant_id
--     INNER JOIN general_schema.tenant_product_group tpg ON tpg.tenant_product_group_id = pvga.tenant_product_group_id
--     WHERE crs_link.cash_register_session_id = p_session_id
--     GROUP BY tpg.tenant_product_group_id, tpg.group_name
--     ON CONFLICT (cash_register_session_id, tenant_product_group_id)
--     DO UPDATE SET total_amount = EXCLUDED.total_amount;
--     UPDATE pos_schema.cash_register_session
--     SET closed_at = NOW(), closing_amount = p_closing_amount, is_active = FALSE,
--         cash_sales_amount = p_user_cash, debit_sales_amount = p_user_debit,
--         credit_sales_amount = p_user_credit, transfer_sales_amount = p_user_transfer,
--         points_sales_amount = v_system_points, total_sales_amount = v_system_total_sales,
--         mismatch = v_mismatch, mismatch_amount = ABS(v_mismatch_amt),
--         mismatch_type = v_mismatch_type, updated_at = NOW()
--     WHERE cash_register_session_id = p_session_id RETURNING * INTO v_session;
--     RETURN v_session;
-- END;
-- $$;
--
-- ALTER TABLE pos_schema.cash_register_session
--     DROP COLUMN IF EXISTS user_cash_amount,
--     DROP COLUMN IF EXISTS user_debit_amount,
--     DROP COLUMN IF EXISTS user_credit_amount,
--     DROP COLUMN IF EXISTS user_transfer_amount;
--
-- COMMIT;
