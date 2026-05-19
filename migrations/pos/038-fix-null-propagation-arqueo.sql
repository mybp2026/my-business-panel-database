-- ======================================================
-- MIGRATION: pos/038-fix-null-propagation-arqueo.sql
-- Audit:
--   In PostgreSQL PL/pgSQL, `SELECT col INTO var FROM t WHERE ...`
--   sets var = NULL when no row matches, regardless of DECLARE := 0.
--   Migration 037 used per-SELECT queries against session_payment_method_sales.
--   When a session has no sales, the INSERT inserts nothing, and each
--   subsequent SELECT returns no rows → all v_system_* become NULL.
--   NULL arithmetic propagates: v_diff_cash = user - (opening + NULL) = NULL,
--   ABS(NULL) > 0.01 is NULL (not TRUE) → mismatch never fires.
--   Also mismatch_amount = ABS(NULL) = NULL → frontend shows ——.
--
--   Fix: replace per-method SELECT INTO queries with a single aggregate
--   SELECT using FILTER, guaranteed to return exactly one row with 0
--   for methods with no sales.
-- ======================================================

CREATE OR REPLACE FUNCTION pos_schema.close_cash_register_session(
    p_session_id     uuid,
    p_closing_amount numeric,
    p_user_cash      numeric DEFAULT 0,
    p_user_debit     numeric DEFAULT 0,
    p_user_credit    numeric DEFAULT 0,
    p_user_transfer  numeric DEFAULT 0
)
RETURNS pos_schema.cash_register_session
LANGUAGE plpgsql
AS $$
DECLARE
    v_session             pos_schema.cash_register_session%ROWTYPE;
    v_system_cash         NUMERIC(14, 2) := 0;
    v_system_debit        NUMERIC(14, 2) := 0;
    v_system_credit       NUMERIC(14, 2) := 0;
    v_system_transfer     NUMERIC(14, 2) := 0;
    v_system_points       NUMERIC(14, 2) := 0;
    v_system_total_sales  NUMERIC(14, 2) := 0;
    v_diff_cash           NUMERIC(14, 2);
    v_diff_debit          NUMERIC(14, 2);
    v_diff_credit         NUMERIC(14, 2);
    v_diff_transfer       NUMERIC(14, 2);
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

    -- Aggregate all payment methods into session_payment_method_sales
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

    -- Single aggregate query: guaranteed one row, no NULL from missing methods
    SELECT
        COALESCE(SUM(total_amount) FILTER (WHERE payment_method_id = 1), 0),
        COALESCE(SUM(total_amount) FILTER (WHERE payment_method_id = 2), 0),
        COALESCE(SUM(total_amount) FILTER (WHERE payment_method_id = 3), 0),
        COALESCE(SUM(total_amount) FILTER (WHERE payment_method_id = 4), 0),
        COALESCE(SUM(total_amount) FILTER (WHERE payment_method_id = 5), 0),
        COALESCE(SUM(total_amount), 0)
    INTO
        v_system_cash,
        v_system_debit,
        v_system_credit,
        v_system_transfer,
        v_system_points,
        v_system_total_sales
    FROM pos_schema.session_payment_method_sales
    WHERE cash_register_session_id = p_session_id;

    -- Per-method diff:
    --   cash: user must hold opening_amount + cash_sales (float + collections)
    --   other methods: user declared must match system exactly
    v_diff_cash     := p_user_cash     - (v_session.opening_amount + v_system_cash);
    v_diff_debit    := p_user_debit    - v_system_debit;
    v_diff_credit   := p_user_credit   - v_system_credit;
    v_diff_transfer := p_user_transfer - v_system_transfer;

    IF ABS(v_diff_cash)     > 0.01
    OR ABS(v_diff_debit)    > 0.01
    OR ABS(v_diff_credit)   > 0.01
    OR ABS(v_diff_transfer) > 0.01
    THEN
        v_mismatch     := TRUE;
        v_mismatch_amt := v_diff_cash + v_diff_debit + v_diff_credit + v_diff_transfer;
        v_mismatch_type := CASE WHEN v_mismatch_amt > 0 THEN 'surplus' ELSE 'shortage' END;
    END IF;

    -- Per-group breakdown
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


-- ======================================================
-- ROLLBACK
-- ======================================================
-- Restore 037 function (per-SELECT queries, NULL propagation bug retained):
--
-- CREATE OR REPLACE FUNCTION pos_schema.close_cash_register_session(
--     p_session_id uuid, p_closing_amount numeric,
--     p_user_cash numeric DEFAULT 0, p_user_debit numeric DEFAULT 0,
--     p_user_credit numeric DEFAULT 0, p_user_transfer numeric DEFAULT 0
-- ) RETURNS pos_schema.cash_register_session LANGUAGE plpgsql AS $$
-- ... (037 body) ...
-- $$;
