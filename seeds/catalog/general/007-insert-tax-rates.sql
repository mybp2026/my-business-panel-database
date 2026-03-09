SET SEARCH_PATH TO general_schema;

-- Tasas IVA Costa Rica según DGT-R-48-2016 (CodigoTarifa v4.4)
-- rate_code = CodigoTarifa requerido por Hacienda en <Impuesto><CodigoTarifa>
INSERT INTO general_schema.tax_rate (region, region_id, rate_percentage, rate_code, rate_name) VALUES
('CR Exento',   (SELECT region_id FROM general_schema.region WHERE region_name = 'Costa Rica'), 0.00,  '01', 'Exento'),
('CR IVA 1%',   (SELECT region_id FROM general_schema.region WHERE region_name = 'Costa Rica'), 1.00,  '05', 'IVA 1%'),
('CR IVA 2%',   (SELECT region_id FROM general_schema.region WHERE region_name = 'Costa Rica'), 2.00,  '06', 'IVA 2%'),
('CR IVA 4%',   (SELECT region_id FROM general_schema.region WHERE region_name = 'Costa Rica'), 4.00,  '07', 'IVA 4% - Servicios de Salud'),
('CR Standard', (SELECT region_id FROM general_schema.region WHERE region_name = 'Costa Rica'), 13.00, '08', 'IVA General 13%'),
('PA Standard', (SELECT region_id FROM general_schema.region WHERE region_name = 'Panama'),     7.00,  NULL, NULL),
('US Federal',  (SELECT region_id FROM general_schema.region WHERE region_name = 'United States'), 10.00, NULL, NULL),
('EU Standard', NULL,                                                                            20.00, NULL, NULL),
('UK Standard', (SELECT region_id FROM general_schema.region WHERE region_name = 'United Kingdom'), 20.00, NULL, NULL),
('JP Standard', (SELECT region_id FROM general_schema.region WHERE region_name = 'Japan'),      8.00,  NULL, NULL)
ON CONFLICT (region, rate_percentage) DO UPDATE
  SET rate_code = EXCLUDED.rate_code,
      rate_name = EXCLUDED.rate_name;
