-- ======================================================
-- MIGRATION: pos/009-invoice-product-tax-linkage.sql
-- ======================================================
-- Author: David
-- Date: 2026-02-12
-- Description: Links product variants and per-item tax rates to invoices:
--   1. Adds tenant_id + product_variant_id to electronic_sale_invoice_items
--   2. Replaces terminal_name with cash_register_id FK in digital_sale_invoice
--   3. Adds register_name to cash_register for display on invoices
--   4. Modifies general_schema.tax_rate for CABYS-compatible tax rates
--   5. Creates digital_sale_invoice_item with FKs to product_variant and tax_rate
--   6. Updates create_digital_sale_invoice() to generate items with per-item tax
--   7. Updates update_on_return() to recalculate tax from per-item rates
--
-- Dependencies: 008-invoice-system-overhaul.sql
-- Breaking Changes: YES
--   - terminal_name column removed from digital_sale_invoice (replaced by cash_register_id FK)
--   - digital_sale_invoice tax_amount now computed from per-item product tax rates
--   - update_on_return() uses per-item tax instead of regional tax
--   - electronic_sale_invoice_items now requires tenant_id + product_variant_id
-- Rollback: See bottom of file
-- ======================================================

BEGIN;

ALTER TABLE general_schema.tax_rate
    DROP CONSTRAINT IF EXISTS tax_rate_region_key;

ALTER TABLE general_schema.tax_rate
    ALTER COLUMN region DROP NOT NULL;

ALTER TABLE general_schema.tax_rate
    ADD COLUMN IF NOT EXISTS rate_code VARCHAR(10),
    ADD COLUMN IF NOT EXISTS rate_name VARCHAR(100);

COMMENT ON TABLE general_schema.tax_rate IS
    'Stores tax rate entries for both regional taxes and CABYS product-level IVA rates.
     - Regional rates: region + region_id populated.
     - CABYS IVA rates: rate_code + rate_name populated, region nullable.';

ALTER TABLE pos_schema.cash_register
    ADD COLUMN IF NOT EXISTS register_name VARCHAR(100);

ALTER TABLE pos_schema.digital_sale_invoice
    ADD COLUMN IF NOT EXISTS cash_register_id UUID
        REFERENCES pos_schema.cash_register(cash_register_id) ON DELETE SET NULL;

UPDATE pos_schema.digital_sale_invoice dsi
SET cash_register_id = cr.cash_register_id
FROM pos_schema.cash_register_sale crs
JOIN pos_schema.cash_register_session crss ON crs.cash_register_session_id = crss.cash_register_session_id
JOIN pos_schema.cash_register cr ON crss.cash_register_id = cr.cash_register_id
WHERE crs.sale_id = dsi.sale_id
AND dsi.cash_register_id IS NULL;

ALTER TABLE pos_schema.digital_sale_invoice
    DROP COLUMN IF EXISTS terminal_name;

CREATE INDEX IF NOT EXISTS idx_digital_sale_invoice_cash_register
    ON pos_schema.digital_sale_invoice(cash_register_id);

ALTER TABLE pos_schema.electronic_sale_invoice_items
    ADD COLUMN IF NOT EXISTS tenant_id UUID,
    ADD COLUMN IF NOT EXISTS product_variant_id UUID;

UPDATE pos_schema.electronic_sale_invoice_items esi
SET
    tenant_id = matched.tenant_id,
    product_variant_id = matched.product_variant_id
FROM (
    SELECT DISTINCT ON (esi_sub.electronic_sale_invoice_item_id)
        esi_sub.electronic_sale_invoice_item_id,
        si.tenant_id,
        si.product_variant_id
    FROM pos_schema.electronic_sale_invoice_items esi_sub
    JOIN pos_schema.electronic_sale_invoice esv
        ON esi_sub.electronic_sale_invoice_id = esv.electronic_sale_invoice_id
    JOIN pos_schema.sale_item si
        ON esv.sale_id = si.sale_id
    JOIN general_schema.product_variant pv
        ON si.tenant_id = pv.tenant_id
        AND si.product_variant_id = pv.product_variant_id
    WHERE pv.cabys_code = esi_sub.cabys_code
    AND esi_sub.tenant_id IS NULL
) matched
WHERE esi.electronic_sale_invoice_item_id = matched.electronic_sale_invoice_item_id;

ALTER TABLE pos_schema.electronic_sale_invoice_items
    ALTER COLUMN tenant_id SET NOT NULL,
    ALTER COLUMN product_variant_id SET NOT NULL;

ALTER TABLE pos_schema.electronic_sale_invoice_items
    ADD CONSTRAINT fk_electronic_item_product_variant
    FOREIGN KEY (tenant_id, product_variant_id)
    REFERENCES general_schema.product_variant(tenant_id, product_variant_id)
    ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_electronic_invoice_items_variant
    ON pos_schema.electronic_sale_invoice_items(tenant_id, product_variant_id);

-- ======================================================
-- STEP 5: Create digital_sale_invoice_item table
-- ======================================================
-- Itemized detail for digital invoices with dynamic FK references
-- to product_variant and tax_rate (resolved from product → tax_rate).

CREATE TABLE IF NOT EXISTS pos_schema.digital_sale_invoice_item (
    digital_sale_invoice_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    digital_sale_invoice_id UUID NOT NULL
        REFERENCES pos_schema.digital_sale_invoice(digital_sale_invoice_id) ON DELETE CASCADE,
    sale_item_id UUID NOT NULL
        REFERENCES pos_schema.sale_item(sale_item_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,
    cabys_code VARCHAR(13)
        REFERENCES general_schema.product(cabys_code) ON DELETE SET NULL,
    tax_rate_id INTEGER
        REFERENCES general_schema.tax_rate(tax_rate_id) ON DELETE SET NULL,
    description VARCHAR(255),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10,2) NOT NULL,
    tax_rate_percentage NUMERIC(5,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_price NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (tenant_id, product_variant_id)
        REFERENCES general_schema.product_variant(tenant_id, product_variant_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_digital_invoice_item_invoice
    ON pos_schema.digital_sale_invoice_item(digital_sale_invoice_id);
CREATE INDEX IF NOT EXISTS idx_digital_invoice_item_sale_item
    ON pos_schema.digital_sale_invoice_item(sale_item_id);
CREATE INDEX IF NOT EXISTS idx_digital_invoice_item_variant
    ON pos_schema.digital_sale_invoice_item(tenant_id, product_variant_id);
CREATE INDEX IF NOT EXISTS idx_digital_invoice_item_tax_rate
    ON pos_schema.digital_sale_invoice_item(tax_rate_id);

-- Backfill digital_sale_invoice_item for existing digital invoices
INSERT INTO pos_schema.digital_sale_invoice_item (
    digital_sale_invoice_id,
    sale_item_id,
    tenant_id,
    product_variant_id,
    cabys_code,
    tax_rate_id,
    description,
    quantity,
    unit_price,
    subtotal,
    tax_rate_percentage,
    tax_amount,
    total_price
)
SELECT
    dsi.digital_sale_invoice_id,
    si.sale_item_id,
    si.tenant_id,
    si.product_variant_id,
    pv.cabys_code,
    p.tax_rate_id,
    COALESCE(pv.variant_name, p.product_name, 'Product'),
    si.quantity,
    si.unit_price,
    si.total_price,
    COALESCE(tr.rate_percentage, 0),
    ROUND(si.total_price * COALESCE(tr.rate_percentage, 0) / 100, 2),
    si.total_price + ROUND(si.total_price * COALESCE(tr.rate_percentage, 0) / 100, 2)
FROM pos_schema.digital_sale_invoice dsi
JOIN pos_schema.sale_item si ON dsi.sale_id = si.sale_id
JOIN general_schema.product_variant pv
    ON si.tenant_id = pv.tenant_id AND si.product_variant_id = pv.product_variant_id
LEFT JOIN general_schema.product p ON pv.cabys_code = p.cabys_code
LEFT JOIN general_schema.tax_rate tr ON p.tax_rate_id = tr.tax_rate_id
WHERE NOT EXISTS (
    SELECT 1 FROM pos_schema.digital_sale_invoice_item dsii
    WHERE dsii.digital_sale_invoice_id = dsi.digital_sale_invoice_id
    AND dsii.sale_item_id = si.sale_item_id
);

-- Timestamp trigger for digital_sale_invoice_item
CREATE TRIGGER update_digital_sale_invoice_item_timestamp
    BEFORE UPDATE ON pos_schema.digital_sale_invoice_item
    FOR EACH ROW EXECUTE FUNCTION general_schema.update_timestamp();

-- ======================================================
-- STEP 6: Update create_digital_sale_invoice() function
-- ======================================================
-- Now creates digital_sale_invoice_item rows with per-item tax
-- and resolves cash_register_id from the active session.

CREATE OR REPLACE FUNCTION create_digital_sale_invoice()
returns trigger as $$
declare
    _digital_sale_invoice_id uuid;
    _tenant_customer_id uuid;
    _tenant_id uuid;
    _currency_id INTEGER;
    _subtotal numeric(10,2);
    _tax numeric(10,2);
    _total numeric(10,2);
    _payment_ids uuid[];
    _cash_register_id uuid;
    _items_count int;
BEGIN
        raise notice 'Creating digital sale invoice for sale: %', new.sale_id;

        if exists(
            select 1 from pos_schema.digital_sale_invoice
            where sale_id = new.sale_id
        ) then
            raise notice 'Digital sale invoice already exists for sale: %', new.sale_id;
            return new;
        end if;

        _tenant_customer_id := (
            select tenant_customer_id
            from pos_schema.customer_payment
            where sale_id = new.sale_id
            limit 1
        );

        select tenant_id into _tenant_id
        from general_schema.tenant_customer
        where tenant_customer_id = _tenant_customer_id;

        _currency_id := new.currency_id;

        -- Resolve cash register from active session in the branch
        SELECT cr.cash_register_id INTO _cash_register_id
        FROM pos_schema.cash_register_session crs
        JOIN pos_schema.cash_register cr ON crs.cash_register_id = cr.cash_register_id
        WHERE cr.branch_id = new.branch_id
        AND crs.is_active = true
        LIMIT 1;

        -- Insert invoice with placeholder totals (will be updated from items)
        INSERT INTO pos_schema.digital_sale_invoice (
            sale_id,
            tenant_customer_id,
            currency_id,
            subtotal_amount,
            tax_amount,
            total_amount,
            cash_register_id
        ) VALUES (
            new.sale_id,
            _tenant_customer_id,
            _currency_id,
            0,
            0,
            0,
            _cash_register_id
        ) returning digital_sale_invoice_id into _digital_sale_invoice_id;

        raise notice '   Digital sale invoice created: %', _digital_sale_invoice_id;
        raise notice '   Cash Register: %', _cash_register_id;

        -- Create digital sale invoice items with per-item tax
        INSERT INTO pos_schema.digital_sale_invoice_item (
            digital_sale_invoice_id,
            sale_item_id,
            tenant_id,
            product_variant_id,
            cabys_code,
            tax_rate_id,
            description,
            quantity,
            unit_price,
            subtotal,
            tax_rate_percentage,
            tax_amount,
            total_price
        )
        SELECT
            _digital_sale_invoice_id,
            si.sale_item_id,
            si.tenant_id,
            si.product_variant_id,
            pv.cabys_code,
            p.tax_rate_id,
            COALESCE(pv.variant_name, p.product_name, 'Product'),
            si.quantity,
            si.unit_price,
            si.total_price,
            COALESCE(tr.rate_percentage, 0),
            ROUND(si.total_price * COALESCE(tr.rate_percentage, 0) / 100, 2),
            si.total_price + ROUND(si.total_price * COALESCE(tr.rate_percentage, 0) / 100, 2)
        FROM pos_schema.sale_item si
        JOIN general_schema.product_variant pv
            ON si.tenant_id = pv.tenant_id AND si.product_variant_id = pv.product_variant_id
        LEFT JOIN general_schema.product p ON pv.cabys_code = p.cabys_code
        LEFT JOIN general_schema.tax_rate tr ON p.tax_rate_id = tr.tax_rate_id
        WHERE si.sale_id = new.sale_id;

        GET DIAGNOSTICS _items_count = ROW_COUNT;
        raise notice '   % invoice item(s) created', _items_count;

        -- Update invoice totals from items (per-item tax)
        SELECT
            COALESCE(SUM(dsii.subtotal), 0),
            COALESCE(SUM(dsii.tax_amount), 0)
        INTO _subtotal, _tax
        FROM pos_schema.digital_sale_invoice_item dsii
        WHERE dsii.digital_sale_invoice_id = _digital_sale_invoice_id;

        _total := _subtotal + _tax;

        UPDATE pos_schema.digital_sale_invoice
        SET subtotal_amount = _subtotal,
            tax_amount = _tax,
            total_amount = _total
        WHERE digital_sale_invoice_id = _digital_sale_invoice_id;

        raise notice '   Subtotal: $%', _subtotal;
        raise notice '   Tax (per-item): $%', _tax;
        raise notice '   Total: $%', _total;

        -- Link verified payments
        select array_agg(customer_payment_id) into _payment_ids
        from pos_schema.customer_payment
        where sale_id = new.sale_id
        and verified = true;

        INSERT INTO pos_schema.digital_sale_invoice_payment(
            digital_sale_invoice_id, customer_payment_id, payment_amount
        )
        select
            _digital_sale_invoice_id,
            customer_payment_id,
            payment_amount
        from pos_schema.customer_payment
        where customer_payment_id = any(_payment_ids);

        raise notice '   % payment(s) linked to digital sale invoice', array_length(_payment_ids, 1);
        raise notice '';
        raise notice 'Digital sale invoice creation completed successfully';
        raise notice '   Invoice ID: %', _digital_sale_invoice_id;
        raise notice '   Sale ID: %', new.sale_id;

        return new;

    exception
        when others then
            raise notice 'Error creating digital sale invoice: %', sqlerrm;
            return new;
end;
$$ language plpgsql;

-- ======================================================
-- STEP 7: Update update_on_return() function
-- ======================================================
-- Tax recalculation now uses per-item tax rates from
-- digital_sale_invoice_item instead of a flat regional rate.

CREATE OR REPLACE FUNCTION update_on_return()
returns trigger as $$
declare
    _sale_item_record record;
    _digital_sale_invoice_id uuid;
    _sale_id uuid;
    _total_returned numeric(10,2) := 0;
    _new_subtotal numeric(10,2);
    _new_tax numeric(10,2);
    _new_total numeric(10,2);
    _quantity_remaining INTEGER;
    _sale_subtotal_after numeric(10,2);
    _sale_tax_after numeric(10,2);
BEGIN
    select
        si.sale_item_id,
        si.sale_id,
        si.quantity,
        si.unit_price,
        si.total_price,
        si.product_variant_id,
        si.tenant_id
    into _sale_item_record
    from pos_schema.sale_item si
    where si.sale_item_id = new.sale_item_id;

    if not found then
        raise exception 'Sale item not found: %', new.sale_item_id;
    end if;

    _sale_id := _sale_item_record.sale_id;

    -- get digital sale invoice for sale
    select digital_sale_invoice_id into _digital_sale_invoice_id
    from pos_schema.digital_sale_invoice where sale_id = _sale_id limit 1;
    if _digital_sale_invoice_id is null then
        raise exception 'Digital sale invoice not found for sale: %', _sale_id;
    end if;

    raise notice 'Digital Sale Invoice ID: %', _digital_sale_invoice_id;
    raise notice 'Original sale item: qty=% unit=$% total=$%',
        _sale_item_record.quantity, _sale_item_record.unit_price, _sale_item_record.total_price;

    if new.quantity > _sale_item_record.quantity then
        raise exception 'Cannot return more items than purchased. Purchased: %, Attempting to return: %',
            _sale_item_record.quantity, new.quantity;
    end if;

    _quantity_remaining := _sale_item_record.quantity - new.quantity;
    raise notice 'Return quantity: %  Remaining qty: %', new.quantity, _quantity_remaining;

    -- Update or remove sale_item (CASCADE deletes digital_sale_invoice_item if qty = 0)
    if _quantity_remaining = 0 then
        delete from pos_schema.sale_item where sale_item_id = _sale_item_record.sale_item_id;
        raise notice 'Sale item removed (quantity = 0)';
    else
        update pos_schema.sale_item
        set quantity = _quantity_remaining,
            total_price = _quantity_remaining * unit_price,
            updated_at = current_timestamp
        where sale_item_id = _sale_item_record.sale_item_id;
        raise notice 'Sale item quantity updated from % to %', _sale_item_record.quantity, _quantity_remaining;

        -- Update corresponding digital_sale_invoice_item
        update pos_schema.digital_sale_invoice_item
        set quantity = _quantity_remaining,
            subtotal = _quantity_remaining * unit_price,
            tax_amount = ROUND((_quantity_remaining * unit_price) * tax_rate_percentage / 100, 2),
            total_price = (_quantity_remaining * unit_price)
                + ROUND((_quantity_remaining * unit_price) * tax_rate_percentage / 100, 2),
            updated_at = current_timestamp
        where digital_sale_invoice_id = _digital_sale_invoice_id
        and sale_item_id = _sale_item_record.sale_item_id;
    end if;

    -- Recalculate digital sale invoice totals from remaining items
    SELECT
        COALESCE(SUM(dsii.subtotal), 0),
        COALESCE(SUM(dsii.tax_amount), 0),
        COALESCE(SUM(dsii.total_price), 0)
    INTO _new_subtotal, _new_tax, _new_total
    FROM pos_schema.digital_sale_invoice_item dsii
    WHERE dsii.digital_sale_invoice_id = _digital_sale_invoice_id;

    update pos_schema.digital_sale_invoice
    set subtotal_amount = _new_subtotal,
        tax_amount = _new_tax,
        total_amount = _new_total,
        updated_at = current_timestamp
    where digital_sale_invoice_id = _digital_sale_invoice_id;

    raise notice 'Digital sale invoice updated: subtotal $% tax $% total $%',
        _new_subtotal, _new_tax, _new_total;

    -- Recalculate sale totals from remaining sale_items with per-item tax
    SELECT
        COALESCE(SUM(si.total_price), 0),
        COALESCE(SUM(ROUND(si.total_price * COALESCE(tr.rate_percentage, 0) / 100, 2)), 0)
    INTO _sale_subtotal_after, _sale_tax_after
    FROM pos_schema.sale_item si
    JOIN general_schema.product_variant pv
        ON si.tenant_id = pv.tenant_id AND si.product_variant_id = pv.product_variant_id
    LEFT JOIN general_schema.product p ON pv.cabys_code = p.cabys_code
    LEFT JOIN general_schema.tax_rate tr ON p.tax_rate_id = tr.tax_rate_id
    WHERE si.sale_id = _sale_id;

    _new_total := _sale_subtotal_after + _sale_tax_after;

    update pos_schema.sale
    set subtotal_amount = _sale_subtotal_after,
        tax_amount = _sale_tax_after,
        total_amount = _new_total,
        updated_at = current_timestamp
    where sale_id = _sale_id;

    raise notice 'Sale updated: subtotal $% tax $% total $%',
        _sale_subtotal_after, _sale_tax_after, _new_total;

    return new;
end;
$$ language plpgsql;

COMMIT;

-- ======================================================
-- ROLLBACK (run manually if needed):
-- ======================================================
-- BEGIN;
--
-- SET SEARCH_PATH TO pos_schema;
--
-- -- Remove digital_sale_invoice_item table
-- DROP TRIGGER IF EXISTS update_digital_sale_invoice_item_timestamp
--     ON pos_schema.digital_sale_invoice_item;
-- DROP TABLE IF EXISTS pos_schema.digital_sale_invoice_item CASCADE;
--
-- -- Remove product_variant columns from electronic_sale_invoice_items
-- ALTER TABLE pos_schema.electronic_sale_invoice_items
--     DROP CONSTRAINT IF EXISTS fk_electronic_item_product_variant;
-- DROP INDEX IF EXISTS idx_electronic_invoice_items_variant;
-- ALTER TABLE pos_schema.electronic_sale_invoice_items
--     DROP COLUMN IF EXISTS tenant_id,
--     DROP COLUMN IF EXISTS product_variant_id;
--
-- -- Restore terminal_name in digital_sale_invoice
-- ALTER TABLE pos_schema.digital_sale_invoice
--     ADD COLUMN IF NOT EXISTS terminal_name VARCHAR(100);
-- DROP INDEX IF EXISTS idx_digital_sale_invoice_cash_register;
-- ALTER TABLE pos_schema.digital_sale_invoice
--     DROP COLUMN IF EXISTS cash_register_id;
--
-- -- Remove register_name from cash_register
-- ALTER TABLE pos_schema.cash_register
--     DROP COLUMN IF EXISTS register_name;
--
-- -- Restore general_schema.tax_rate constraints
-- ALTER TABLE general_schema.tax_rate
--     DROP COLUMN IF EXISTS rate_code,
--     DROP COLUMN IF EXISTS rate_name;
-- ALTER TABLE general_schema.tax_rate
--     ALTER COLUMN region SET NOT NULL;
-- ALTER TABLE general_schema.tax_rate
--     ADD CONSTRAINT tax_rate_region_key UNIQUE (region);
--
-- -- NOTE: Functions create_digital_sale_invoice() and update_on_return()
-- -- must be restored from the pre-migration version in pos_functions.sql.
-- -- Re-run the original function definitions from the backup.
--
-- COMMIT;
