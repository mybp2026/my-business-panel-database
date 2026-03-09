-- Seed: pos_schema.invoice_status
-- status_id values are fixed constants referenced in application code
--   1 = pendiente  → recién generada, aún no enviada o sin respuesta de Hacienda
--   2 = aceptada   → Hacienda confirmó la factura
--   3 = rechazada  → Hacienda rechazó la factura

INSERT INTO pos_schema.invoice_status (status_id, description)
VALUES
  (1, 'pendiente'),
  (2, 'aceptada'),
  (3, 'rechazada')
ON CONFLICT (status_id) DO NOTHING;
