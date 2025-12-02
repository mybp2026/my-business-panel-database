# Automatic Supplier Invoice Generation

## Overview

The `supplies_module` provides **two methods** for creating supplier invoices:

### Method 1: Automatic Invoice Generation (Trigger-Based)

When an `account_payable` is fully paid, a trigger automatically creates the invoice:

1. All payments for a supply order are verified and the total matches the `amount_due`
2. The `account_payable.account_status` automatically changes to `3` (Paid)
3. The `create_supplier_invoice` trigger fires on status change
4. A `supplier_invoice` record is created with tax calculated dynamically based on the tenant's region
5. All items from `supply_order_item` are copied to `supplier_invoice_item`
6. The invoice is ready for three-way matching (Purchase Order → Goods Receipt → Invoice)

### Method 2: Manual Invoice Generation (Procedure-Based)

For orders with `has_invoice = true`, you can create invoices immediately using the `create_supplier_invoice()` procedure:

1. Call `create_supplier_invoice(supply_order_id, tenant_id, subtotal_amount, payment_condition)`
2. The procedure creates the invoice with tax calculation
3. Items are copied from `supply_order_item` to `supplier_invoice_item`
4. The `account_payable.has_invoice` flag can be set to `true` to track invoice existence

This document provides step-by-step guides with SQL examples demonstrating both invoice creation workflows.

---

## Prerequisites

Before invoices can be generated, ensure:

- A `supply_order` exists with items in `supply_order_item`
- An `account_payable` is created for the order (happens automatically via `create_supply_order()`)

**For Automatic Invoice Generation (Trigger-Based):**

- At least one `supply_order_payment` is registered and verified
- Total verified payments equal the `amount_due` (triggers status change to "Paid")

**For Manual Invoice Generation (Procedure-Based):**

- The `supply_order_id`, `tenant_id`, and `subtotal_amount` are available
- Optional: Set `payment_condition` ('CREDIT' or 'IN_FULL')

**For Both Methods:**

- The tenant has a valid `region_id` with an associated `tax_rate` in `core.tax_rate`
- If no regional tax rate exists, defaults to 13%

---

## How It Works: Invoice Generation Methods

---

### Method 1: Automatic Invoice Generation (Trigger-Based)

This method creates invoices automatically when an order is fully paid.

#### Trigger Flow Diagram

```
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
```

---

### Method 2: Manual Invoice Generation (Procedure-Based)

This method creates invoices immediately using the `create_supplier_invoice()` procedure.

#### Procedure Call Flow

```
CALL create_supplier_invoice(
    supply_order_id,
    tenant_id,
    subtotal_amount,
    payment_condition
)
    ↓
Validate supply_order exists
    ↓
Check if invoice already exists (skip if true)
    ↓
Retrieve tenant → branch → region
    ↓
Lookup tax_rate from core.tax_rate
    ↓
Calculate subtotal and tax:
  subtotal = amount / (1 + tax_rate)
  tax = amount - subtotal
    ↓
INSERT supplier_invoice
  - invoice_number: 'INV-YYYYMMDD-HHMMSS-{order_id_prefix}'
  - subtotal_amount, tax_amount (generated)
  - total_amount (generated = subtotal + tax)
    ↓
FOR EACH supply_order_item:
  INSERT supplier_invoice_item
    ↓
✅ Invoice created with all items copied
```

**Key Differences:**

| Aspect       | Automatic (Trigger)               | Manual (Procedure)                              |
| ------------ | --------------------------------- | ----------------------------------------------- |
| **Timing**   | After full payment                | Immediately on call                             |
| **Trigger**  | account_status = 3                | CALL statement                                  |
| **Use Case** | Payment-first workflow            | Invoice-first workflow                          |
| **Input**    | account_payable_id (from trigger) | supply_order_id, tenant_id, subtotal, condition |

---

## Workflow Examples

---

### Example 1: Automatic Invoice Generation (Payment-First)

This example demonstrates the trigger-based automatic invoice creation after full payment.

#### Step 1: Starting Point - Order with Pending Payment

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

---

### Example 2: Manual Invoice Generation (Invoice-First)

This example demonstrates creating an invoice immediately using the procedure, before full payment.

#### Step 1: Create Supply Order WITHOUT Invoice

Create the order with `has_invoice = false` to skip automatic invoice generation:

```sql
-- Create supply order (no automatic invoice)
SELECT supplies_module.create_supply_order(
    'supplier-uuid-123'::uuid,
    'warehouse-uuid-456'::uuid,
    (current_date + interval '7 days')::date,
    '[
        {"product_id": "prod-uuid-001", "quantity_ordered": 10, "unit_price": 25.50},
        {"product_id": "prod-uuid-002", "quantity_ordered": 5, "unit_price": 120.00}
    ]'::jsonb,
    false,      -- has_invoice = false (no automatic invoice)
    'CREDIT'
) AS supply_order_id;
```

**Expected Result:**

```
supply_order_id: 'order-uuid-abc123'
```

#### Step 2: Manually Create Invoice Using Procedure

Call the `create_supplier_invoice()` procedure to generate the invoice:

```sql
-- Get the account_payable details
SELECT
    ap.account_payable_id,
    ap.subtotal_amount,
    so.supply_order_id,
    b.tenant_id
FROM supplies_module.account_payable ap
JOIN supplies_module.supply_order so ON ap.supply_order_id = so.supply_order_id
JOIN supplies_module.supplier s ON so.supplier_id = s.supplier_id
JOIN core.branch b ON s.branch_id = b.branch_id
WHERE so.supply_order_id = 'order-uuid-abc123'::uuid;

-- Call procedure to create invoice
CALL supplies_module.create_supplier_invoice(
    'order-uuid-abc123'::uuid,  -- supply_order_id
    'tenant-uuid-xyz'::uuid,     -- tenant_id
    1030.00,                     -- subtotal_amount (from account_payable)
    'CREDIT'                     -- payment_condition
);
```

**Console Output:**

```
NOTICE: ✅ Created supplier invoice invoice-uuid-789 for supply order order-uuid-abc123
NOTICE: ✅ Copied 2 items to supplier invoice
```

#### Step 3: Update Account Payable Flag (Optional)

Mark that the account_payable has an invoice:

```sql
UPDATE supplies_module.account_payable
SET has_invoice = true
WHERE supply_order_id = 'order-uuid-abc123'::uuid;
```

#### Step 4: Verify Invoice Was Created

Query the invoice:

```sql
SELECT
    si.supplier_invoice_id,
    si.invoice_number,
    si.invoice_date,
    si.subtotal_amount,
    si.tax_amount,
    si.total_amount,
    si.paid
FROM supplies_module.supplier_invoice si
WHERE si.supply_order_id = 'order-uuid-abc123'::uuid;
```

**Expected Result:**
| supplier_invoice_id | invoice_number | invoice_date | subtotal_amount | tax_amount | total_amount | paid |
|--------------------|----------------|--------------|-----------------|------------|--------------|------|
| invoice-uuid-789 | INV-20251202-063045-order-ab | 2025-12-02 06:30:45 | 911.504 | 118.496 | 1030.000 | false |

#### Step 5: Pay Invoice Later (Optional)

Payments can be made after invoice creation:

```sql
-- Register payment
INSERT INTO supplies_module.supply_order_payment(
    tenant_id,
    account_payable_id,
    amount_paid,
    payment_method_id,
    payment_reference,
    verified
) VALUES (
    'tenant-uuid-xyz'::uuid,
    'payable-uuid-123'::uuid,
    1030.00,
    1,  -- cash
    'PAYMENT-001',
    false
) RETURNING payment_id;

-- Verify payment
CALL supplies_module.verify_supply_order_payment('payment-uuid-001'::uuid);
```

**Result:**

- `account_payable.account_status` → 3 (Paid)
- `supplier_invoice.paid` → true (via `update_invoice_paid_status` trigger)

---

## Comparison: When to Use Each Method

| Scenario                       | Recommended Method  | Reason                                      |
| ------------------------------ | ------------------- | ------------------------------------------- |
| **Pay first, invoice later**   | Automatic (Trigger) | Invoice generated only when fully paid      |
| **Invoice upfront, pay later** | Manual (Procedure)  | Create invoice immediately for customer     |
| **Credit terms (NET30)**       | Manual (Procedure)  | Invoice needed before payment               |
| **COD (Cash on Delivery)**     | Automatic (Trigger) | Payment and invoice together                |
| **Partial payments**           | Automatic (Trigger) | Invoice created after all payments verified |
| **Immediate billing**          | Manual (Procedure)  | Invoice required at order placement         |

---

## Tax Calculation Logic

Both methods use the same tax calculation:

1. **Retrieve tenant's region** from `core.tenant.region_id`
2. **Lookup tax rate** from `core.tax_rate` where `region_id` matches
3. **Calculate amounts**:
   ```
   subtotal = total_amount / (1 + tax_rate)
   tax = total_amount - subtotal
   ```
4. **Fallback**: If no regional tax rate found, default to **13%**

**Example:**

```
Total Amount: $1,030.00
Tax Rate: 13% (0.13)
Subtotal: 1030.00 / 1.13 = $911.504
Tax: 1030.00 - 911.504 = $118.496
```

---

## Important Notes

### Duplicate Prevention

Both methods check if an invoice already exists for a `supply_order_id` before creating a new one.

### Trigger Timing

The automatic trigger fires on **UPDATE of `account_status`** to value `3` (Paid). It will NOT fire if:

- Status changes from 3 → 3 (already paid)
- Invoice already exists for the supply order

### Procedure Idempotency

The `create_supplier_invoice()` procedure checks for existing invoices and skips creation with a notice:

```
NOTICE: ⚠️ Supplier invoice already exists for supply order {uuid}
```

### Invoice Number Format

Both methods generate invoice numbers as:

```
INV-YYYYMMDD-HHMMSS-{first_8_chars_of_supply_order_id}
```

Example: `INV-20251202-143022-abc12345`

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
