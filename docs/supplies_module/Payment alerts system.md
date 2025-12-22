# Payment alerts system

## Purpose

Automatically generate and manage payment alerts for accounts payable based on configurable deadlines. Allows businesses to proactively manage supplier payments and avoid late fees or overdue accounts.

## Scope

Covers:

- Configuring alert thresholds per tenant (warning days, urgent days)
- Automatically generating alerts for pending/partial payments
- Categorizing alerts (Upcoming Due Date, Urgent Payment, Overdue Payment, Reconciliation Mismatch)
- Auto-resolving alerts when accounts are fully paid
- Querying pending alerts and statistics
- Manual alert resolution

## Prerequisites

- Schemas: `supplies_module`, `core`
- Core data: tenant, branch, supplier, account_payable
- Tables:
  - `supplies_module.supply_order_payment_alert_type` (pre-populated with 4 alert types)
  - `supplies_module.supply_order_payment_alert` (stores individual alerts)
  - `supplies_module.supply_order_payment_alert_config` (tenant-specific configuration)
- Installed functions/triggers:
  - `supplies_module.initialize_payment_alert_config(...)` (setup tenant config)
  - `supplies_module.generate_payment_alerts()` (scans and creates alerts)
  - `supplies_module.get_pending_payment_alerts(tenant_id)` (query alerts)
  - `supplies_module.get_payment_alert_stats(tenant_id)` (summary statistics)
  - `supplies_module.resolve_payment_alert(alert_id)` (manual resolution)
  - `supplies_module.auto_resolve_payment_alerts()` (trigger on account_payable.account_status update)

## Alert Types

The system supports four alert types defined in `supply_order_payment_alert_type`:

1. **Upcoming Due Date** (Type 1): Payment due within warning threshold (configurable, default: 7 days)
2. **Urgent Payment** (Type 2): Payment due within urgent threshold (configurable, default: 3 days)
3. **Overdue Payment** (Type 3): Payment past due date (negative days until due)
4. **Reconciliation Mismatch** (Type 4): Reserved for payment reconciliation issues (future use)

## Expected automated behaviors

- **initialize_payment_alert_config()**:

  - Creates or updates alert configuration for a tenant
  - Sets warning_days_before_due and urgent_days_before_due thresholds
  - Enables/disables email and SMS notifications
  - Uses `ON CONFLICT` for idempotent upserts

- **generate_payment_alerts()**:

  - Iterates through all tenants with alert configuration
  - Finds accounts payable with status Pending (1) or Partial Paid (2)
  - Calculates days_until_due (due_date - current_date)
  - Determines appropriate alert type based on thresholds
  - Creates alert only if one doesn't already exist (idempotent)
  - Skips accounts with balance_remaining = 0

- **auto_resolve_payment_alerts()** (trigger):
  - Fires when account_payable.account_status changes to Paid (3)
  - Sets is_resolved = true for all unresolved alerts on that account
  - Updates alert timestamp

## Step-by-step flow

1. **Configure tenant alert settings** (one-time setup)

   - Call initialize_payment_alert_config() with desired thresholds:

     ```sql
     SELECT supplies_module.initialize_payment_alert_config(
       '<tenant-uuid>'::uuid,
       7,      -- warning_days_before_due
       3,      -- urgent_days_before_due
       true,   -- email_notifications_enabled
       false   -- sms_notifications_enabled
     );
     ```

   - Result: Row inserted/updated in supply_order_payment_alert_config

2. **Create supply orders and accounts payable**

   - Follow standard supplier purchase flow
   - Each account_payable has a due_date
   - Accounts with status Pending (1) or Partial Paid (2) are candidates for alerts

3. **Generate alerts** (scheduled job, typically daily)

   - Execute:

     ```sql
     SELECT supplies_module.generate_payment_alerts();
     ```

   - Function scans all configured tenants
   - For each tenant, finds eligible accounts payable
   - Creates alerts based on days_until_due:
     - If overdue (< 0 days): Type 3 (Overdue Payment)
     - If <= urgent_days: Type 2 (Urgent Payment)
     - If <= warning_days: Type 1 (Upcoming Due Date)
     - Else: no alert needed yet
   - Avoids duplicates (checks if alert already exists for same account + type)

4. **Query pending alerts**

   - Application calls get_pending_payment_alerts():

     ```sql
     SELECT * FROM supplies_module.get_pending_payment_alerts('<tenant-uuid>');
     ```

   - Returns all unresolved alerts for the tenant, ordered by due_date ascending
   - Includes supplier_name, invoice_number, alert_type, days_until_due, balance_remaining

5. **View alert statistics**

   - Application calls get_payment_alert_stats():

     ```sql
     SELECT * FROM supplies_module.get_payment_alert_stats('<tenant-uuid>');
     ```

   - Returns summary: total_alerts, overdue_count, urgent_count, warning_count, total_amount_at_risk

6. **Make payments**

   - Follow standard payment flow:

     ```sql
     INSERT INTO supplies_module.supply_order_payment(...);
     CALL supplies_module.verify_supply_order_payment('<payment-id>');
     ```

   - When account becomes Paid (account_status = 3), trigger auto-resolves all alerts

7. **Manual alert resolution** (optional)

   - Dismiss an alert without payment:

     ```sql
     SELECT supplies_module.resolve_payment_alert('<alert-uuid>');
     ```

   - Sets is_resolved = true

## Configuration

### Initialize/update tenant configuration

```sql
-- Create or update alert config
SELECT supplies_module.initialize_payment_alert_config(
  p_tenant_id := '<tenant-uuid>'::uuid,
  p_warning_days := 10,
  p_urgent_days := 5,
  p_email_enabled := true,
  p_sms_enabled := true
);
```

### Query existing configuration

```sql
SELECT *
FROM supplies_module.supply_order_payment_alert_config
WHERE tenant_id = '<tenant-uuid>';
```

### Update configuration directly

```sql
UPDATE supplies_module.supply_order_payment_alert_config
SET warning_days_before_due = 14,
    urgent_days_before_due = 7,
    email_notifications_enabled = true
WHERE tenant_id = '<tenant-uuid>';
```

## Validation queries

### Check pending alerts for a tenant

```sql
SELECT *
FROM supplies_module.get_pending_payment_alerts('<tenant-uuid>');
```

### Check all alerts (including resolved)

```sql
SELECT
  spa.*,
  spat.payment_alert_type_name,
  ap.due_date,
  ap.balance_remaining,
  s.supplier_name
FROM supplies_module.supply_order_payment_alert spa
JOIN supplies_module.supply_order_payment_alert_type spat USING (payment_alert_type_id)
JOIN supplies_module.account_payable ap USING (account_payable_id)
JOIN supplies_module.supply_order so ON ap.supply_order_id = so.supply_order_id
JOIN supplies_module.supplier s USING (supplier_id)
JOIN supplies_module.supplier_branch sb USING (supplier_id)
JOIN core.branch b USING (branch_id)
WHERE b.tenant_id = '<tenant-uuid>'
ORDER BY spa.created_at DESC;
```

### Alert statistics

```sql
SELECT *
FROM supplies_module.get_payment_alert_stats('<tenant-uuid>');
```

### Accounts payable eligible for alerts

```sql
-- Find accounts that should generate alerts
SELECT
  ap.account_payable_id,
  ap.due_date,
  (ap.due_date - current_date) AS days_until_due,
  ap.balance_remaining,
  ap.account_status,
  s.supplier_name
FROM supplies_module.account_payable ap
JOIN supplies_module.supply_order so ON ap.supply_order_id = so.supply_order_id
JOIN supplies_module.supplier s ON so.supplier_id = s.supplier_id
JOIN supplies_module.supplier_branch sb ON s.supplier_id = sb.supplier_id
JOIN core.branch b ON sb.branch_id = b.branch_id
WHERE b.tenant_id = '<tenant-uuid>'
AND ap.account_status IN (1, 2)  -- Pending or Partial Paid
AND ap.balance_remaining > 0
ORDER BY ap.due_date;
```

## Common failure modes & troubleshooting

### Alerts not being created

- Check config exists: Verify tenant has row in supply_order_payment_alert_config

```sql
SELECT * FROM supplies_module.supply_order_payment_alert_config WHERE tenant_id = '<tenant-uuid>';
```

- Check eligible accounts: Ensure accounts have status Pending (1) or Partial Paid (2) and balance_remaining > 0

- Check days_until_due: Verify due_date falls within threshold ranges

- Run generate_payment_alerts(): Alerts are not created automatically; must call function

## References

- Schema: supplies_module (supply_order_payment_alert, supply_order_payment_alert_config, supply_order_payment_alert_type)

- Related docs: Supplier Purchase, Account Payable Management

- Functions: supplies_module.\* (see repository functions folder)
