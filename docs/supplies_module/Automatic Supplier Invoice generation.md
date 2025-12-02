# Automatic Supplier Invoice Generation

## Overview

The automatic invoice generation workflow in the `supplies_module` is triggered when an `account_payable` is fully paid. This seamless integration ensures that:

1. When all payments for a supply order are verified and the total matches the `amount_due`
2. The `account_payable.account_status` automatically changes to `3` (Paid)
3. A trigger fires and creates a `supplier_invoice` record
4. The invoice calculates tax dynamically based on the tenant's region
5. All items from `supply_order_item` are copied to `supplier_invoice_item`
6. The invoice is ready for three-way matching (Purchase Order → Goods Receipt → Invoice)

This document provides a step-by-step guide with SQL examples demonstrating the automatic invoice creation process.

---

## Prerequisites

Before invoices can be generated automatically, ensure:

- A `supply_order` exists with items in `supply_order_item`
- An `account_payable` is created for the order (happens automatically via `create_supply_order()`)
- At least one `supply_order_payment` is registered and verified
- The tenant has a valid `region_id` with an associated `tax_rate` in `core.tax_rate`

---

## How It Works: The Trigger Chain

### Trigger Flow Diagram

supply_order_payment INSERT
↓
[verified = false by default]
↓
verify_supply_order_payment() called
↓
UPDATE verified = true
↓
recalc_account_payable_on_payment_trigger FIRES
↓
check_account_payable_completion() executes
↓
SUM all verified payments
↓
IF total_payments ≈ amount_due (±0.01)
↓
UPDATE account_payable.account_status = 3 (Paid)
↓
create_supplier_invoice TRIGGER FIRES
↓
create_supplier_invoice() function executes
↓
✅ supplier_invoice created
✅ supplier_invoice_item records created

---

## Step-by-Step Workflow

### Step 1: Starting Point - Order with Pending Payment

Assume we already have a supply order created from the previous workflow:

**Existing State:**

```sql
-- Query existing order
SELECT
    so.supply_order_id,
    ap.account_payable_id,
    ap.amount_due,
    ap.amount_paid,
    ap.balance_remaining,
    aps.status_name
FROM supplies_module.supply_order so
JOIN supplies_module.account_payable ap ON ap.supply_order_id = so.supply_order_id
JOIN supplies_module.account_payable_status aps ON aps.status_id = ap.account_status
WHERE so.supply_order_id = 'order-uuid-abc123'::uuid;
```

Expected result:

```sql
payment_id: 'payment-uuid-001'
```

Verify the payment:

```sql
CALL supplies_module.verify_supply_order_payment('payment-uuid-001'::uuid);
```

Verify account status changed to "Partially Paid":

```sql
SELECT
    account_payable_id,
    amount_paid,
    balance_remaining,
    aps.status_name
FROM supplies_module.account_payable ap
JOIN supplies_module.account_payable_status aps ON aps.status_id = ap.account_status
WHERE account_payable_id = 'payable-uuid-xyz789'::uuid;
```

Expected result:
account_payable_id | amount_paid | balance_remaining | status_name
--------------------|-------------|-------------------|-------------
payable-uuid-xyz789 | 515.00 | 515.00 | Partially Paid

Verify no invoice created yet:

```sql
SELECT COUNT(*) as invoice_count
FROM supplies_module.supplier_invoice
WHERE supply_order_id = 'order-uuid-abc123'::uuid;
```

Expected result:
invoice_count: 0

### Step 3: Register and Verify Final Payment

Complete the payment with the remaining balance.

**SQL Example:**

```sql
-- Register final payment
INSERT INTO supplies_module.supply_order_payment(
    tenant_id,
    account_payable_id,
    amount_paid,
    payment_method,
    payment_reference
) VALUES (
    'a685d8c2-acba-469f-bd16-3200ab7e8b6d'::uuid,
    'payable-uuid-xyz789'::uuid,
    515.00,  -- Remaining 50%
    5,       -- Bank Transfer
    'WIRE-FINAL-PAYMENT-20251201'
) RETURNING payment_id;
```

Expected result:

```sql
payment_id: 'payment-uuid-002'
```

Verify the final payment:

````sql
CALL supplies_module.verify_supply_order_payment('payment-uuid-002'::uuid);```
````

supply_order_payment INSERT
↓
[verified = false by default]
↓
verify_supply_order_payment() called
↓
UPDATE verified = true
↓
recalc_account_payable_on_payment_trigger FIRES
↓
check_account_payable_completion() executes
↓
SUM all verified payments
↓
IF total_payments ≈ amount_due (±0.01)
↓
UPDATE account_payable.account_status = 3 (Paid)
↓
create_supplier_invoice TRIGGER FIRES
↓
create_supplier_invoice() function executes
↓
✅ supplier_invoice created
✅ supplier_invoice_item records created

Expected Result:

Verify no invoice exists yet:

Expected Result:

Step 2: Register and Verify First Payment (Partial)
Register a partial payment (50% of total).

SQL Example:

Expected Response:

Verify the payment:

Console Output:

Verify account status changed to "Partially Paid":

Expected Result:

Verify no invoice created yet:

Expected Result:

Step 3: Register and Verify Final Payment
Complete the payment with the remaining balance.

SQL Example:

Expected Response:

Verify the final payment:

Console Output (Key Events):

What Happened Internally:

1. ✅ Payment marked as verified = true
2. ✅ recalc_account_payable_on_payment_trigger fired
3. ✅ check_account_payable_completion() calculated total = $1,030
4. ✅ account_payable.account_status updated to 3 (Paid)
5. ✅ create_supplier_invoice trigger fired (because status changed to 3)
6. ✅ create_supplier_invoice() function executed:
   - Retrieved tenant's region tax rate
   - Calculated subtotal and tax amounts
   - Created supplier_invoice record
   - Copied all items from supply_order_item to supplier_invoice_item

### Step 4: Verify Invoice Creation

Query the automatically generated invoice.

**SQL Example:**

```sql
SELECT
    si.supplier_invoice_id,
    si.supply_order_id,
    si.invoice_number,
    si.invoice_date,
    si.due_date,
    si.subtotal_amount,
    si.tax_amount,
    (si.subtotal_amount + si.tax_amount) as total_amount
FROM supplies_module.supplier_invoice si
WHERE si.supply_order_id = 'order-uuid-abc123'::uuid;
```

Expected result:
supplier_invoice_id | supply_order_id | invoice_number | invoice_date | due_date | subtotal_amount | tax_amount | total_amount
--------------------|-------------------|---------------------------|----------------------|------------|-----------------|------------|-------------
invoice-uuid-123 | order-uuid-abc123 | INV-20251201-143022-abc1 | 2025-12-01 14:30:22 | 2025-12-31 | 911.504 | 118.496 | 1030.000

**Breakdown:**

- subtotal_amount = 1030.00 / 1.13 = 911.504 (assuming 13% tax rate)
- tax_amount = 1030.00 - 911.504 = 118.496
- invoice_number format: INV-YYYYMMDD-HHMMSS-{first_8_chars_of_order_id}

### Step 5: Verify Invoice Items

Query the items copied to the invoice.

**SQL Example:**

```sql
SELECT
    p.product_name,
    sii.quantity_billed,
    sii.unit_price,
    (sii.quantity_billed * sii.unit_price) as line_total
FROM supplies_module.supplier_invoice_item sii
JOIN supplies_module.supplier_invoice si ON si.supplier_invoice_id = sii.supplier_invoice_id
JOIN core.product p ON p.tenant_id = sii.tenant_id AND p.product_id = sii.product_id
WHERE si.supply_order_id = 'order-uuid-abc123'::uuid
ORDER BY sii.created_at;
```

Expected result:
product_name | quantity_billed | unit_price | line_total
----------------------|-----------------|------------|------------
Laptop Dell XPS 15 | 10 | 25.500 | 255.000
Wireless Mouse | 5 | 120.000 | 600.000
USB-C Cable 2m | 20 | 8.750 | 175.000

Total: 255.00 + 600.00 + 175.00 = **$1,030.00**

###Step 6: Complete Payment History
View all payments that triggered the invoice creation.

**SQL Example:**

```sql
SELECT
    sop.payment_id,
    sop.payment_date,
    sop.amount_paid,
    pm.name as payment_method,
    sop.payment_reference,
    sop.verified
FROM supplies_module.supply_order_payment sop
JOIN core.payment_method pm ON pm.payment_method_id = sop.payment_method
WHERE sop.account_payable_id = 'payable-uuid-xyz789'::uuid
ORDER BY sop.payment_date;
```

Expected result:
payment_id | payment_date | amount_paid | payment_method | payment_reference | verified
------------------|--------------------------|-------------|----------------|---------------------------|----------
payment-uuid-001 | 2025-12-01 10:15:00 | 515.000 | cash | CASH-DOWN-PAYMENT-001 | true
payment-uuid-002 | 2025-12-01 14:30:00 | 515.000 | wire_transfer | WIRE-FINAL-PAYMENT-20251201| true
