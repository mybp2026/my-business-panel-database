-- Seed: pos_schema.invoice_status
-- status_id values are fixed constants referenced in application code
--   1 = pendiente  → recién generada, aún no enviada o sin respuesta de Hacienda
--   2 = aceptada   → Hacienda confirmó la factura
--   3 = rechazada  → Hacienda rechazó la factura
--   4 = timeout    → agotó los reintentos del cron sin resolución

INSERT INTO pos_schema.invoice_status (status_id, description)
VALUES
  (1, 'pendiente'),
  (2, 'aceptada'),
  (3, 'rechazada'),
  (4, 'timeout')
ON CONFLICT (status_id) DO NOTHING;
