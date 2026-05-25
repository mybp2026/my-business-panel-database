SET SEARCH_PATH TO inventory_schema;

INSERT INTO inventory_schema.inventory_log_type(inventory_log_type_name, inventory_log_type_description) VALUES
    ('IN', 'inventory added to inventory_schema'),
    ('OUT', 'inventory removed from inventory_schema')
ON CONFLICT DO NOTHING;