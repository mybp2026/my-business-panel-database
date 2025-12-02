# Creating Supply Orders

## Overview

The supply order creation workflow in the `supplies_module` is designed to handle the complete lifecycle of purchasing goods from suppliers. When a supply order is created, the system automatically:

1. Inserts the order record with basic information (supplier, warehouse, delivery date)
2. Adds all ordered items (products, quantities, unit prices)
3. Calculates the total amount due using `calculate_supply_order_total()`
4. Creates an associated `account_payable` record with `amount_paid = 0`
5. Enables multiple payment methods and installment payments through `supply_order_payment`

This document provides a step-by-step guide with SQL examples for each stage of the process.

---

## Prerequisites

Before creating a supply order, ensure you have:

- A valid `supplier_id` (from `supplies_module.supplier`)
- A valid `warehouse_id` (from `inventory_module.warehouse`)
- At least one `product_id` (from `core.product`)
- Valid `payment_method_id` entries (from `core.payment_method`)

---

## Step-by-Step Workflow

### Step 1: Create a Supplier (if not exists)

First, ensure you have a supplier registered in the system.

**SQL Example:**

```sql
INSERT INTO supplies_module.supplier(
    branch_id,
    supplier_name,
    supplier_contact_info
) VALUES (
    'a685d8c2-acba-469f-bd16-3200ab7e8b6d'::uuid,  -- your branch_id
    'Tech Supplies Inc.',
    'contact@techsupplies.com | +1-555-0123'
) RETURNING supplier_id;
```

Expected result:

```sql
supplier_id: '123e4567-e89b-12d3-a456-426614174000'
```

---

### Step 2: Create a Supply Order with items

Call the create_supply_order() function with a JSON array of items.

**SQL Example:**

```sql
SELECT supplies_module.create_supply_order(
    '123e4567-e89b-12d3-a456-426614174000'::uuid,  -- p_supplier_id
    '789e4567-e89b-12d3-a456-426614174001'::uuid,  -- p_warehouse_id
    '2025-12-15'::date,                             -- p_expected_delivery_date
    '[
        {
            "product_id": "prod-uuid-001",
            "quantity_ordered": 10,
            "unit_price": 25.50
        },
        {
            "product_id": "prod-uuid-002",
            "quantity_ordered": 5,
            "unit_price": 120.00
        },
        {
            "product_id": "prod-uuid-003",
            "quantity_ordered": 20,
            "unit_price": 8.75
        }
    ]'::jsonb
);
```

What happens internally:

1. Order Creation: A new row is inserted into supply_order with status Pending (status_id = 1)

2. Items Insertion: Three rows are inserted into supply_order_item

3. Total Calculation: calculate_supply_order_total() computes:

- Item 1: 10 × $25.50 = $255.00
- Item 2: 5 × $120.00 = $600.00
- Item 3: 20 × $8.75 = $175.00
- **Total: $1,030.00**

4. Account Payable Creation: A new record is created in account_payable:

- amount_due = 1030.00
- amount_paid = 0
- balance_remaining = 1030.00
- account_status = 1 (Pending)
- due_date = current_date + 30 days

Expected result:

```sql
supply_order_id: 'order-uuid-abc123'
```

### Step 3: Verify the created order

Query the created order and its items.

**SQL Example:**

```sql
-- Get order details
SELECT
    so.supply_order_id,
    so.supply_order_date,
    so.expected_delivery_date,
    sos.status_name,
    s.supplier_name
FROM supplies_module.supply_order so
JOIN supplies_module.supplier s ON s.supplier_id = so.supplier_id
JOIN supplies_module.supply_order_status sos ON sos.status_id = so.supply_order_status_id
WHERE so.supply_order_id = 'order-uuid-abc123'::uuid;
```

Expected result:
supply_order_id | supply_order_date | expected_delivery_date | status_name | supplier_name
----------------------|-------------------|------------------------|-------------|------------------
order-uuid-abc123 | 2025-12-01 | 2025-12-15 | Pending | Tech Supplies Inc.

```sql
-- Get order items
SELECT
    p.product_name,
    soi.quantity_ordered,
    soi.unit_price,
    (soi.quantity_ordered * soi.unit_price) AS total_price
FROM supplies_module.supply_order_item soi
JOIN core.product p ON p.product_id = soi.product_id
WHERE soi.supply_order_id = 'order-uuid-abc123'::uuid;
```

Expected result:
product_name | quantity_ordered | unit_price | total_price
----------------------|------------------|------------|------------
Laptop Dell XPS 15 | 10 | 25.50 | 255.00
Wireless Mouse | 5 | 120.00 | 600.00
USB-C Cable 2m | 20 | 8.75 | 175.00

```sql
-- Get account payable
SELECT
    account_payable_id,
    amount_due,
    amount_paid,
    balance_remaining,
    due_date,
    aps.status_name
FROM supplies_module.account_payable ap
JOIN supplies_module.account_payable_status aps ON aps.status_id = ap.account_status
WHERE ap.supply_order_id = 'order-uuid-abc123'::uuid;
```

Expected result:
account_payable_id | amount_due | amount_paid | balance_remaining | due_date | status_name
----------------------|------------|-------------|-------------------|------------|------------
payable-uuid-xyz789 | 1030.00 | 0.00 | 1030.00 | 2025-12-31 | Pending

### Step 4: Register a payment (Partial or Full)

The system supports multiple payment methods and installments. Let's register a partial payment.

**SQL Example - First Payment (Cash, 50% down payment):**

```sql
INSERT INTO supplies_module.supply_order_payment(
    tenant_id,
    account_payable_id,
    amount_paid,
    payment_method,
    payment_reference,
) VALUES (
    'a685d8c2-acba-469f-bd16-3200ab7e8b6d'::uuid,  -- your tenant_id
    'payable-uuid-xyz789'::uuid,                    -- account_payable_id from Step 3
    515.00,                                          -- 50% of $1,030
    1,                                               -- payment_method_id (1 = Cash)
    'CASH-RECEIPT-001',                              -- reference number
) RETURNING payment_id;
```

No need to declare the field _verified_ from the supply_order_payment table since it has it's own constraint that automatically labels new payments as false on initial insert.

Expected result:

```sql
payment_id: 'payment-uuid-001'
```

### Step 5: Verify the Payment

Call the verify_supply_order_payment() procedure to confirm the payment.

**SQL Example:**

```sql
CALL supplies_module.verify_supply_order_payment('payment-uuid-001'::uuid);
```

This procedure should be called automatically from the API once the payment processing service validation.

What happens internally:

1. The payment was marked as verified = true
2. The recalc_account_payable_on_payment_trigger fired
3. check_account_payable_completion() was called
4. The account_payable was updated:
   - amount_paid = 515.00
   - balance_remaining = 515.00
   - account_status = 2 (Partial Paid)

### Step 6: Register Additional Payments (Multiple Methods)

Let's pay the remaining balance using a different payment method.

**SQL Example - Second Payment (Bank Transfer):**

```sql
INSERT INTO supplies_module.supply_order_payment(
    tenant_id,
    account_payable_id,
    amount_paid,
    payment_method,
    payment_reference,
    verified
) VALUES (
    'a685d8c2-acba-469f-bd16-3200ab7e8b6d'::uuid,
    'payable-uuid-xyz789'::uuid,
    515.00,
    5,                                               -- payment_method_id (5 = Bank Transfer)
    'WIRE-TX-20251201-1234',                         -- bank reference
    false
) RETURNING payment_id;
```

Expected result:

```sql
payment_id: 'payment-uuid-002'
```

### Step 7: Verify Final Payment

Verify the second payment to complete the account.

**SQL Example:**

```sql
CALL supplies_module.verify_supply_order_payment('payment-uuid-002'::uuid);
```

**Final State of account_payable:**

```sql
SELECT
    account_payable_id,
    amount_due,
    amount_paid,
    balance_remaining,
    aps.status_name
FROM supplies_module.account_payable ap
JOIN supplies_module.account_payable_status aps ON aps.status_id = ap.account_status
WHERE ap.account_payable_id = 'payable-uuid-xyz789'::uuid;
```

Expected result:
account_payable_id | amount_due | amount_paid | balance_remaining | status_name
----------------------|------------|-------------|-------------------|------------
payable-uuid-xyz789 | 1030.00 | 1030.00 | 0.00 | Paid

### Step 8: Query All Payments for an Account

View the complete payment history.

**SQL Example:**

```sql
SELECT
    sop.payment_id,
    sop.payment_date,
    sop.amount_paid,
    pm.name AS payment_method,
    sop.payment_reference,
    sop.verified
FROM supplies_module.supply_order_payment sop
JOIN core.payment_method pm ON pm.payment_method_id = sop.payment_method
WHERE sop.account_payable_id = 'payable-uuid-xyz789'::uuid
ORDER BY sop.payment_date;
```

Expected result:
payment_id | payment_date | amount_paid | payment_method | payment_reference | verified
------------------|--------------------------|-------------|----------------|------------------------|----------
payment-uuid-001 | 2025-12-01 10:30:00 | 515.00 | cash | CASH-RECEIPT-001 | true
payment-uuid-002 | 2025-12-01 14:45:00 | 515.00 | wire_transfer | WIRE-TX-20251201-1234 | true
