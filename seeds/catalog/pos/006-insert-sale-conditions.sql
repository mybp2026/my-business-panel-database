INSERT INTO pos_schema.sale_condition (condition_code, condition_desc) VALUES
  ('01', 'Contado'),
  ('02', 'Credito'),
  ('03', 'Consignacion'),
  ('04', 'Apartado'),
  ('05', 'Arrendamiento con opcion de compra'),
  ('06', 'Arrendamiento en funcion financiera'),
  ('07', 'Cobro a favor de un tercero'),
  ('08', 'Servicios prestados al estado a credito'),
  ('09', 'Pago del servicio prestado al estado'),
  ('10', 'Venta a credito hasta 90 dias'),
  ('11', 'Pago de venta a credito en IVA hasta 90 dias'),
  ('99', 'Otros') 
ON CONFLICT DO NOTHING;