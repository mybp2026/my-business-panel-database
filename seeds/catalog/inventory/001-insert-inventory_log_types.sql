INSERT INTO inventory_log_type(inventory_log_type_name, inventory_log_type_description) VALUES
    ('IN', 'inventory added to inventory_module'),
    ('OUT', 'inventory removed from inventory_module')
ON CONFLICT DO NOTHING;