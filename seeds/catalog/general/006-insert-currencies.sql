INSERT INTO currency(currency_code, currency_name, symbol) VALUES
('CRC', 'Costa Rican Colón', '₡'),
('USD', 'US Dollar', '$'),
('EUR', 'Euro', '€'),
('GBP', 'British Pound', '£'),
('JPY', 'Japanese Yen', '¥')
ON CONFLICT DO NOTHING;