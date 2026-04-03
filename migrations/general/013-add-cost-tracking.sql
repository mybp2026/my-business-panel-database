-- ============================================================
-- Migration 013: Cost Tracking for Financial Module (Phase 1)
-- ============================================================
-- Adds:
--   1. exchange_rate table in general_schema
--   2. cost_price + weighted_avg_cost columns on product_variant
--   3. product_cost_history table in general_schema
--   4. convert_currency() function
--   5. update_product_cost_on_receipt() function
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- 1. Exchange Rate table
-- -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS general_schema.exchange_rate (
    exchange_rate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency_id INTEGER NOT NULL REFERENCES general_schema.currency(currency_id),
    to_currency_id   INTEGER NOT NULL REFERENCES general_schema.currency(currency_id),
    rate             NUMERIC(12,6) NOT NULL CHECK (rate > 0),
    effective_date   DATE NOT NULL,
    source           VARCHAR(50) DEFAULT 'MANUAL', -- 'BCCR', 'MANUAL', etc.
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(from_currency_id, to_currency_id, effective_date),
    CHECK (from_currency_id <> to_currency_id)
);

CREATE INDEX IF NOT EXISTS idx_exchange_rate_lookup
    ON general_schema.exchange_rate(from_currency_id, to_currency_id, effective_date DESC);

COMMENT ON TABLE general_schema.exchange_rate IS
    'Historical exchange rates between currencies. One rate per currency pair per day.';

-- -----------------------------------------------------------------
-- 2. Add cost columns to product_variant
-- -----------------------------------------------------------------
ALTER TABLE general_schema.product_variant
    ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12,3) DEFAULT 0 CHECK (cost_price >= 0);

ALTER TABLE general_schema.product_variant
    ADD COLUMN IF NOT EXISTS weighted_avg_cost NUMERIC(12,3) DEFAULT 0 CHECK (weighted_avg_cost >= 0);

ALTER TABLE general_schema.product_variant
    ADD COLUMN IF NOT EXISTS last_purchase_date TIMESTAMP;

COMMENT ON COLUMN general_schema.product_variant.cost_price IS
    'Last acquisition cost (unit cost from most recent purchase)';
COMMENT ON COLUMN general_schema.product_variant.weighted_avg_cost IS
    'Weighted average cost: (old_stock * old_avg + new_qty * new_cost) / (old_stock + new_qty)';
COMMENT ON COLUMN general_schema.product_variant.last_purchase_date IS
    'Date of the most recent purchase that updated the cost';

-- -----------------------------------------------------------------
-- 3. Product Cost History table
-- -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS general_schema.product_cost_history (
    cost_history_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id          UUID NOT NULL,
    product_variant_id UUID NOT NULL,
    purchase_order_id  UUID,
    unit_cost          NUMERIC(12,3) NOT NULL CHECK (unit_cost >= 0),
    currency_id        INTEGER REFERENCES general_schema.currency(currency_id),
    exchange_rate      NUMERIC(12,6),
    unit_cost_converted NUMERIC(12,3),
    quantity           INTEGER NOT NULL CHECK (quantity > 0),
    effective_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (tenant_id, product_variant_id)
        REFERENCES general_schema.product_variant(tenant_id, product_variant_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_product_cost_history_variant
    ON general_schema.product_cost_history(tenant_id, product_variant_id, effective_date DESC);

CREATE INDEX IF NOT EXISTS idx_product_cost_history_purchase
    ON general_schema.product_cost_history(purchase_order_id);

COMMENT ON TABLE general_schema.product_cost_history IS
    'Tracks every cost change per product variant, linked to the purchase order that caused it.';

-- -----------------------------------------------------------------
-- 4. convert_currency() function
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION general_schema.convert_currency(
    p_amount           NUMERIC,
    p_from_currency_id INTEGER,
    p_to_currency_id   INTEGER,
    p_date             DATE DEFAULT CURRENT_DATE
) RETURNS NUMERIC
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_rate NUMERIC(12,6);
BEGIN
    -- Same currency: no conversion needed
    IF p_from_currency_id = p_to_currency_id THEN
        RETURN p_amount;
    END IF;

    -- Find the most recent rate on or before the given date
    SELECT er.rate INTO v_rate
    FROM general_schema.exchange_rate er
    WHERE er.from_currency_id = p_from_currency_id
      AND er.to_currency_id   = p_to_currency_id
      AND er.effective_date   <= p_date
    ORDER BY er.effective_date DESC
    LIMIT 1;

    IF v_rate IS NULL THEN
        -- Try the inverse
        SELECT (1.0 / er.rate) INTO v_rate
        FROM general_schema.exchange_rate er
        WHERE er.from_currency_id = p_to_currency_id
          AND er.to_currency_id   = p_from_currency_id
          AND er.effective_date   <= p_date
        ORDER BY er.effective_date DESC
        LIMIT 1;
    END IF;

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'No exchange rate found for currency % -> % on or before %',
            p_from_currency_id, p_to_currency_id, p_date;
    END IF;

    RETURN ROUND(p_amount * v_rate, 3);
END;
$$;

COMMENT ON FUNCTION general_schema.convert_currency IS
    'Converts an amount between currencies using the most recent rate on or before the given date. Tries inverse rate if direct not found.';

-- -----------------------------------------------------------------
-- 5. update_product_cost_on_receipt() — called from backend
--    Weighted average cost formula:
--    new_avg = (current_stock * current_avg + received_qty * new_cost) / (current_stock + received_qty)
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION general_schema.update_product_cost_on_receipt(
    p_tenant_id          UUID,
    p_product_variant_id UUID,
    p_purchase_order_id  UUID,
    p_quantity           INTEGER,
    p_unit_cost          NUMERIC(12,3),
    p_currency_id        INTEGER DEFAULT NULL,
    p_exchange_rate_val  NUMERIC(12,6) DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_current_stock INTEGER;
    v_current_avg   NUMERIC(12,3);
    v_new_avg       NUMERIC(12,3);
    v_cost_converted NUMERIC(12,3);
BEGIN
    -- Determine converted cost (if exchange rate provided)
    IF p_exchange_rate_val IS NOT NULL AND p_exchange_rate_val > 0 THEN
        v_cost_converted := ROUND(p_unit_cost * p_exchange_rate_val, 3);
    ELSE
        v_cost_converted := p_unit_cost;
    END IF;

    -- Get current stock from inventory (sum across all warehouses)
    SELECT COALESCE(SUM(i.stock), 0) INTO v_current_stock
    FROM inventory_schema.inventory i
    WHERE i.tenant_id = p_tenant_id
      AND i.product_variant_id = p_product_variant_id;

    -- Get current weighted average cost
    SELECT COALESCE(pv.weighted_avg_cost, 0) INTO v_current_avg
    FROM general_schema.product_variant pv
    WHERE pv.tenant_id = p_tenant_id
      AND pv.product_variant_id = p_product_variant_id;

    -- Calculate new weighted average
    IF (v_current_stock + p_quantity) > 0 THEN
        v_new_avg := ROUND(
            (v_current_stock * v_current_avg + p_quantity * v_cost_converted)
            / (v_current_stock + p_quantity),
            3
        );
    ELSE
        v_new_avg := v_cost_converted;
    END IF;

    -- Update product_variant with new costs
    UPDATE general_schema.product_variant
    SET cost_price = v_cost_converted,
        weighted_avg_cost = v_new_avg,
        last_purchase_date = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE tenant_id = p_tenant_id
      AND product_variant_id = p_product_variant_id;

    -- Insert cost history record
    INSERT INTO general_schema.product_cost_history (
        tenant_id, product_variant_id, purchase_order_id,
        unit_cost, currency_id, exchange_rate, unit_cost_converted,
        quantity, effective_date
    ) VALUES (
        p_tenant_id, p_product_variant_id, p_purchase_order_id,
        p_unit_cost, p_currency_id, p_exchange_rate_val, v_cost_converted,
        p_quantity, CURRENT_TIMESTAMP
    );
END;
$$;

COMMENT ON FUNCTION general_schema.update_product_cost_on_receipt IS
    'Updates cost_price and weighted_avg_cost on product_variant when stock is received from a purchase. Also inserts a cost history record.';

COMMIT;
