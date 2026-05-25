SET SEARCH_PATH TO hr_schema;

INSERT INTO hr_schema.paysheet_status(status_description) VALUES
('Pending'),
('Completed'),
('Canceled')
ON CONFLICT DO NOTHING;