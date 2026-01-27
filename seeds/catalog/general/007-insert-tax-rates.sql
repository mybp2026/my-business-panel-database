INSERT INTO general.tax_rate(region, region_id, rate_percentage) VALUES
('CR Standard', (select region_id from general.region where region_name = 'Costa Rica'), 13.00),
('PA Standard', (select region_id from general.region where region_name = 'Panama'), 7.00),
('US Federal', (select region_id from general.region where region_name = 'United States'), 10.00),
('EU Standard', null, 20.00),
('UK Standard', (select region_id from general.region where region_name = 'United Kingdom'), 20.00),
('JP Standard', (select region_id from general.region where region_name = 'Japan'), 8.00)
ON CONFLICT DO NOTHING;