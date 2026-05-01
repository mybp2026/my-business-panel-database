-- Migration inventory-032: Add transfer requests
BEGIN;

-- Drop tables in dependency order to allow re-running this migration
DROP TABLE IF EXISTS inventory_schema.inventory_transfer_request_product CASCADE;
DROP TABLE IF EXISTS inventory_schema.inventory_transfer_request CASCADE;
DROP TABLE IF EXISTS inventory_schema.inventory_transfer_request_status CASCADE;

CREATE TABLE IF NOT EXISTS inventory_schema.inventory_transfer_request_status (
        inventory_transfer_request_status_id SERIAL PRIMARY KEY,
        status_name VARCHAR(50) NOT NULL UNIQUE,
        status_description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO inventory_schema.inventory_transfer_request_status (inventory_transfer_request_status_id, status_name, status_description) VALUES
(1, 'pending', 'Solicitud pendiente de aprobación'),
(2, 'approved', 'Solicitud aprobada y transferencia ejecutada'),
(3, 'rejected', 'Solicitud rechazada'),
(4, 'cancelled', 'Solicitud cancelada')
ON CONFLICT (inventory_transfer_request_status_id) DO UPDATE SET
        status_name = EXCLUDED.status_name,
        status_description = EXCLUDED.status_description;

CREATE TABLE IF NOT EXISTS inventory_schema.inventory_transfer_request (
        inventory_transfer_request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        tenant_id uuid NOT NULL,
        from_warehouse_id uuid NOT NULL REFERENCES inventory_schema.warehouse(warehouse_id) ON DELETE CASCADE,
        to_warehouse_id uuid NOT NULL REFERENCES inventory_schema.warehouse(warehouse_id) ON DELETE CASCADE,
        inventory_transfer_request_status_id INTEGER NOT NULL REFERENCES inventory_schema.inventory_transfer_request_status(inventory_transfer_request_status_id),
        requested_by_user_id uuid,
        approved_by_user_id uuid,
        rejection_reason TEXT,
        inventory_transfer_id uuid REFERENCES inventory_schema.inventory_transfer(inventory_transfer_id) ON DELETE SET NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS inventory_schema.inventory_transfer_request_product (
        inventory_transfer_request_product_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        inventory_transfer_request_id uuid NOT NULL REFERENCES inventory_schema.inventory_transfer_request(inventory_transfer_request_id) ON DELETE CASCADE,
        tenant_id uuid NOT NULL,
        product_variant_id uuid NOT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

        FOREIGN KEY (tenant_id, product_variant_id)
                REFERENCES general_schema.product_variant(tenant_id, product_variant_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_transfer_request_tenant ON inventory_schema.inventory_transfer_request(tenant_id);
CREATE INDEX IF NOT EXISTS idx_transfer_request_from_warehouse ON inventory_schema.inventory_transfer_request(from_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_transfer_request_to_warehouse ON inventory_schema.inventory_transfer_request(to_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_transfer_request_product_request ON inventory_schema.inventory_transfer_request_product(inventory_transfer_request_id);
CREATE INDEX IF NOT EXISTS idx_transfer_request_product_variant ON inventory_schema.inventory_transfer_request_product(tenant_id, product_variant_id);

COMMIT;
