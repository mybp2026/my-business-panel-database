-- Migration: Update close_cash_register_session to support multi-method inputs
CREATE OR REPLACE FUNCTION pos_schema.close_cash_register_session(
    p_session_id     uuid,
    p_closing_amount numeric, -- Total user total
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

    -- Get system values for specific methods (IDs: 1=cash, 2=debit, 3=credit, 4=transfer, 5=points)
    SELECT COALESCE(total_amount, 0) INTO v_system_cash FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 1;
    SELECT COALESCE(total_amount, 0) INTO v_system_debit FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 2;
    SELECT COALESCE(total_amount, 0) INTO v_system_credit FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 3;
    SELECT COALESCE(total_amount, 0) INTO v_system_transfer FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 4;
    SELECT COALESCE(total_amount, 0) INTO v_system_points FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id AND payment_method_id = 5;
    
    SELECT COALESCE(SUM(total_amount), 0) INTO v_system_total_sales FROM pos_schema.session_payment_method_sales WHERE cash_register_session_id = p_session_id;

    -- Conciliation logic:
    v_expected_cash := v_session.opening_amount + v_system_cash;
    
    -- Total mismatch calculation
    -- Expected Total = Expected Cash + System Debit + System Credit + System Transfer
    v_mismatch_amt := p_closing_amount - (v_expected_cash + v_system_debit + v_system_credit + v_system_transfer);
    
    IF ABS(v_mismatch_amt) > 0.01 THEN
        v_mismatch := TRUE;
        v_mismatch_type := CASE WHEN v_mismatch_amt > 0 THEN 'surplus' ELSE 'shortage' END;
    END IF;

    -- Update legacy group sales
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
        cash_sales_amount     = p_user_cash,     -- Store user input
        debit_sales_amount    = p_user_debit,    -- Store user input
        credit_sales_amount   = p_user_credit,   -- Store user input
        transfer_sales_amount = p_user_transfer, -- Store user input
        points_sales_amount   = v_system_points, -- System calculated
        total_sales_amount    = v_system_total_sales, -- System calculated total sales
        mismatch              = v_mismatch,
        mismatch_amount       = ABS(v_mismatch_amt),
        mismatch_type         = v_mismatch_type,
        updated_at            = NOW()
    WHERE cash_register_session_id = p_session_id
    RETURNING * INTO v_session;

    RETURN v_session;
END;
$$;
