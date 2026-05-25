INSERT INTO pos.sale 
(
    branch_id,
    currency_id,
    subtotal_amount,
    tax_amount,
    total_amount,
)
VALUES ($1, $2, $3, $4, $5) returning id;