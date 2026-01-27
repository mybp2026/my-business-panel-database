SET SEARCH_PATH TO purchase_schema;

INSERT INTO purchase_schema.purchase_order_payment_alert_type(payment_alert_type_name, description) VALUES
    ('Upcoming Due Date', 'Alert for upcoming payment due date'),
    ('Urgent Payment', 'Alert for urgent payments'),
    ('Overdue Payment', 'Alert for overdue payments'),
    ('Reconciliation Mismatch', 'Alert for payment reconciliation issues')
ON CONFLICT DO NOTHING;