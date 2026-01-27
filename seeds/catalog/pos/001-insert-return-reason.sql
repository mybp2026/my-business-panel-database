SET SEARCH_PATH TO pos_schema;

INSERT INTO pos_schema.return_reason(reason_code, reason_name, description) VALUES
    ('DEFECT', 'Defecto de fábrica', 'El producto tiene un defecto de fabricación'),
    ('SIZE_CHANGE', 'Cambio de talla', 'El cliente requiere una talla diferente'),
    ('WRonG_PRODUCT', 'Producto equivocado', 'Se entregó un producto diferente al solicitado'),
    ('NOT_AS_DESCRIBED', 'No coincide con descripción', 'El producto no coincide con la descripción publicada'),
    ('DAMAGED', 'Producto dañado', 'El producto llegó dañado o roto'),
    ('EXPIRED', 'Producto vencido', 'El producto está vencido o caducado'),
    ('CUSTOMER_REGRET', 'Arrepentimiento', 'El cliente cambió de opinión'),
    ('OTHER', 'Otro motivo', 'Otro motivo no especificado')
ON CONFLICT DO NOTHING;