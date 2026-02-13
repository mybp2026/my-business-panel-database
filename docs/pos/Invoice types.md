# Invoice Types — Digital & Electronic Invoices

This document describes the two invoice types in the POS system: the **digital sale invoice** (automatic, internal) and the **electronic sale invoice** (Hacienda-compliant, Costa Rica). It covers their structure, lifecycle, relationship to sales, and integration with the CABYS product catalog.

## Overview

| Aspect                | Digital Sale Invoice                                                         | Electronic Sale Invoice                            |
| --------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------- |
| **Table**             | `pos_schema.digital_sale_invoice`                                            | `pos_schema.electronic_sale_invoice`               |
| **Creation**          | Automatic (trigger on `sale.is_completed = true`)                            | Manual (application creates after digital invoice) |
| **Purpose**           | Internal sales record and payment audit trail                                | Tax compliance with Costa Rica Hacienda            |
| **Items table**       | `pos_schema.digital_sale_invoice_item`                                       | `pos_schema.electronic_sale_invoice_items`         |
| **CABYS integration** | Via `digital_sale_invoice_item` → `product_variant` → `product` → `tax_rate` | Direct FK to `general_schema.product(cabys_code)`  |
| **Sale flag**         | Always created on sale completion                                            | `sale.has_electronic_invoice = true` when created  |

## Digital Sale Invoice

### What it is

The `digital_sale_invoice` is an internal invoice record automatically generated when a sale is completed. It captures the financial summary of the transaction and links verified payments to the invoice for audit purposes.

### When it is created

A PostgreSQL trigger (`on_sale_completed_create_digital_sale_invoice`) fires when `pos_schema.sale.is_completed` transitions to `true`. The trigger function `pos_schema.create_digital_sale_invoice()` performs these actions:

1. Resolves `cash_register_id` from the active cash register session for the sale's branch.
2. Inserts a `digital_sale_invoice` row with aggregate totals.
3. Inserts `digital_sale_invoice_item` rows for each `sale_item`, resolving per-item tax from `product_variant` → `product` → `tax_rate`.
4. Recomputes the invoice’s `subtotal_amount`, `tax_amount`, and `total_amount` from the aggregated item totals.
5. Inserts `digital_sale_invoice_payment` rows for each verified `customer_payment`.

### Schema

```sql
pos_schema.electronic_sale_invoice
├── electronic_sale_invoice_id  UUID PK
├── tenant_customer_id          UUID FK → general_schema.tenant_customer
├── sale_id                     UUID FK → pos_schema.sale
├── currency_id                 INTEGER FK → general_schema.currency
├── key_number                  VARCHAR(50) (unique Hacienda ID)
├── consecutive_number          VARCHAR(20) (branch/terminal/type/seq number)
├── issue_date                  TIMESTAMP
├── issuer_name                 VARCHAR(150)
├── issuer_identification       VARCHAR(20)
├── issuer_identification_type  VARCHAR(2)
├── issuer_email                VARCHAR(200)
├── issuer_phone                VARCHAR(20)
├── receiver_name               VARCHAR(150)
├── receiver_identification     VARCHAR(20)
├── receiver_identification_type VARCHAR(2)
├── receiver_email              VARCHAR(200)
├── sale_condition              VARCHAR(2) (01=Cash, 02=Credit, etc.)
├── payment_method              VARCHAR(2) (01=Cash, 02=Card, etc.)
├── credit_days                 VARCHAR(10)
├── total_taxed_services        NUMERIC(18,5)
├── total_exempt_services       NUMERIC(18,5)
├── total_exonerated_services   NUMERIC(18,5)
├── total_taxed_goods           NUMERIC(18,5)
├── total_exempt_goods          NUMERIC(18,5)
├── total_exonerated_goods      NUMERIC(18,5)
├── total_taxable               NUMERIC(18,5)
├── total_exempt                NUMERIC(18,5)
├── total_exonerated            NUMERIC(18,5)
├── total_sale                  NUMERIC(18,5)
├── total_discounts             NUMERIC(18,5)
├── total_net_sale              NUMERIC(18,5)
├── total_tax                   NUMERIC(18,5)
├── total_voucher               NUMERIC(18,5)
├── xml_signed                  TEXT
├── hacienda_status             VARCHAR(20) (pending, accepted, rejected)
├── hacienda_response_xml       TEXT
├── hacienda_response_date      TIMESTAMP
├── created_at                  TIMESTAMP
└── updated_at                  TIMESTAMP

pos_schema.electronic_sale_invoice_items
├── electronic_sale_invoice_item_id  UUID PK
├── electronic_sale_invoice_id       UUID FK → electronic_sale_invoice
├── line_number                      INTEGER
├── cabys_code                       VARCHAR(13) FK → general_schema.product
├── description                      VARCHAR(200)
├── quantity                         NUMERIC(16,3)
├── unit_of_measure                  VARCHAR(20)
├── commercial_unit_of_measure       VARCHAR(20)
├── unit_price                       NUMERIC(18,5)
├── total_amount                     NUMERIC(18,5)
├── discount_amount                  NUMERIC(18,5)
├── discount_nature                  VARCHAR(80)
├── subtotal                         NUMERIC(18,5)
├── tax_code                         VARCHAR(2)
├── tax_rate_code                    VARCHAR(2)
├── tax_rate                         NUMERIC(5,2)
├── tax_amount                       NUMERIC(18,5)
├── tax_exemption_amount             NUMERIC(18,5)
├── exemption_document_type          VARCHAR(2)
├── exemption_document_number        VARCHAR(40)
├── exemption_institution            VARCHAR(160)
├── exemption_date                   TIMESTAMP
├── exemption_percentage             NUMERIC(3,0)
├── total_line_amount                NUMERIC(18,5)
├── created_at                       TIMESTAMP
└── updated_at                       TIMESTAMP
```

### Query examples

```sql
-- Retrieve digital invoice for a sale
SELECT * FROM pos_schema.digital_sale_invoice WHERE sale_id = '<sale_id>';

-- Retrieve the invoice with payment breakdown
SELECT * FROM pos_schema.get_digital_sale_invoice('<sale_id>');

-- List payments linked to an invoice
SELECT dsip.*, cp.payment_method_id, cp.payment_amount
FROM pos_schema.digital_sale_invoice_payment dsip
JOIN pos_schema.customer_payment cp ON dsip.customer_payment_id = cp.customer_payment_id
WHERE dsip.digital_sale_invoice_id = '<digital_sale_invoice_id>';
```

---

## Electronic Sale Invoice (Factura Electrónica)

### What it is

The `electronic_sale_invoice` is a structured invoice record compliant with Costa Rica's Ministerio de Hacienda requirements. It follows the XML schema defined by Hacienda for electronic billing (facturación electrónica), including the **key_number**, issuer/receiver identification, tax breakdown per CABYS code, and digital signature.

### When it is created

The electronic invoice is created by the application layer **after** the digital invoice exists. The application should:

1. Wait for `sale.is_completed = true` and the `digital_sale_invoice` to be created by the trigger.
2. Build the electronic invoice structure with Hacienda-required fields.
3. Insert the `electronic_sale_invoice` and its `electronic_sale_invoice_items`.
4. Set `sale.has_electronic_invoice = true`.
5. Generate the XML, sign it (XMLDSig), and store it in `xml_signed`.
6. Submit to Hacienda API and update `hacienda_status` with the response.

### Hacienda Compliance Fields

#### Key Number (50 digits)

The `key_number` is a unique 50-digit identifier with the structure:

| Position | Length | Description                                     |
| -------- | ------ | ----------------------------------------------- |
| 1-3      | 3      | Country code (506 = Costa Rica)                 |
| 4-5      | 2      | Day                                             |
| 6-7      | 2      | Month                                           |
| 8-9      | 2      | Year (last 2 digits)                            |
| 10-21    | 12     | Issuer identification (zero-padded)             |
| 22-41    | 20     | Consecutive number (20-digit sequence)          |
| 42       | 1      | Status (1=Normal, 2=Contingency, 3=No internet) |
| 43-50    | 8      | Security code                                   |

#### Consecutive Number (20 digits)

Format: `SSSPPPTTTDDDDDDDDDD` where:

- **SSS**: Branch (3 digits)
- **PPP**: Point of sale / terminal (3 digits)
- **TTT**: Document type (01=Invoice, 03=Credit note, 04=Receipt, etc.)
- **DDDDDDDDDD**: Sequential number (10 digits)

#### Issuer / Receiver

| Field                          | Description                                       |
| ------------------------------ | ------------------------------------------------- |
| `issuer_name`                  | Seller company name                               |
| `issuer_identification`        | Seller tax ID (cédula jurídica)                   |
| `issuer_identification_type`   | 01=Individual, 02=Legal Entity, 03=DIMEX, 04=NITE |
| `receiver_name`                | Buyer name                                        |
| `receiver_identification`      | Buyer tax ID                                      |
| `receiver_identification_type` | Same codes as issuer                              |

#### Sale Conditions and Payment Method

| Code | Condición de Venta | Code | Medio de Pago          |
| ---- | ------------------ | ---- | ---------------------- |
| 01   | Contado            | 01   | Efectivo               |
| 02   | Crédito            | 02   | Tarjeta                |
| 03   | Consignación       | 03   | Cheque                 |
|      |                    | 04   | Transferencia/depósito |

#### Invoice Summary

The `electronic_sale_invoice` stores aggregated totals broken down by tax status:

```
total_taxed_services          → Services with tax
total_exempt_services         → Exempt services
total_exonerated_services     → Exonerated services
total_taxed_goods             → Goods with tax
total_exempt_goods            → Exempt goods
total_exonerated_goods        → Exonerated goods
total_taxable                 → Total taxable
total_exempt                  → Total exempt
total_exonerated              → Total exonerated
total_sale                    → Total sale (before discounts)
total_discounts               → Total discounts
total_net_sale                → Net total (after discounts)
total_tax                     → Total tax (IVA)
total_voucher                 → Final total (net + tax)
```

### Electronic Sale Invoice Items

Each line item in the electronic invoice references a CABYS code directly, linking to `general_schema.product(cabys_code)`. This ensures every item on the Hacienda invoice has a valid CABYS classification.

#### Schema

```sql
pos_schema.electronic_sale_invoice_items
├── electronic_sale_invoice_item_id  UUID PK
├── electronic_sale_invoice_id       UUID FK → electronic_sale_invoice
├── tenant_id                        UUID NOT NULL
├── product_variant_id               UUID NOT NULL
├──   (tenant_id, product_variant_id) FK → general_schema.product_variant
├── line_number                      INTEGER (line number)
├── cabys_code                       VARCHAR(13) FK → general_schema.product
├── description                      VARCHAR(200) (product description)
├── quantity                         NUMERIC(16,3)
├── unit_of_measure                  VARCHAR(20) (default 'Unid')
├── unit_price                       NUMERIC(18,5)
├── total_amount                     NUMERIC(18,5) (qty × price)
├── discount_amount                  NUMERIC(18,5)
├── subtotal                         NUMERIC(18,5) (total_amount - discount_amount)
├── tax_code                         VARCHAR(2) (default '01' = IVA)
├── tax_rate_code                    VARCHAR(2) (default '08' = 13%)
├── tax_rate                         NUMERIC(5,2) (default 13.00)
├── tax_amount                       NUMERIC(18,5)
├── tax_exemption_amount             NUMERIC(18,5)
├── exemption_document_type          VARCHAR(2)
├── exemption_document_number        VARCHAR(40)
├── exemption_institution            VARCHAR(160)
├── exemption_date                   TIMESTAMP
├── exemption_percentage             NUMERIC(3,0)
└── total_line_amount                NUMERIC(18,5) (subtotal + tax_amount)
```

### Digital Sale Invoice Items

Each line item in the digital invoice is automatically created by the `create_digital_sale_invoice()` trigger. It resolves per-item tax dynamically via FK references to `general_schema.tax_rate`.

#### Schema

```sql
pos_schema.digital_sale_invoice_item
├── digital_sale_invoice_item_id  UUID PK
├── digital_sale_invoice_id       UUID FK → digital_sale_invoice (ON DELETE CASCADE)
├── sale_item_id                  UUID FK → sale_item (ON DELETE CASCADE)
├── tenant_id                     UUID NOT NULL
├── product_variant_id            UUID NOT NULL
├──   (tenant_id, product_variant_id) FK → general_schema.product_variant
├── cabys_code                    VARCHAR(13) FK → general_schema.product
├── tax_rate_id                   INTEGER FK → general_schema.tax_rate (nullable)
├── description                   VARCHAR(200) (resolved from product_variant.variant_name)
├── quantity                      INTEGER
├── unit_price                    NUMERIC(10,2)
├── subtotal                      NUMERIC(10,2) (quantity × unit_price)
├── tax_rate_percentage           NUMERIC(5,2) (resolved from tax_rate.rate_percentage; 0 if null)
├── tax_amount                    NUMERIC(10,2) (subtotal × tax_rate_percentage / 100)
├── total_price                   NUMERIC(10,2) (subtotal + tax_amount)
├── created_at                    TIMESTAMP
└── updated_at                    TIMESTAMP
```

**Key differences from `electronic_sale_invoice_items`:**

| Aspect               | `digital_sale_invoice_item`                    | `electronic_sale_invoice_items`               |
| -------------------- | ---------------------------------------------- | --------------------------------------------- |
| **Creation**         | Automatic (trigger)                            | Manual (application)                          |
| **Tax values**       | Dynamic FK to `tax_rate` table                 | Static values (copied at creation time)       |
| **Cascade behavior** | ON DELETE CASCADE from `sale_item` and invoice | No cascade                                    |
| **Product link**     | FK to `product_variant` + `product`            | FK to `product_variant` + direct `cabys_code` |

#### CABYS Resolution Flow

Items are resolved from the sale through the product catalog:

```
pos_schema.sale_item
    └── (tenant_id, product_variant_id)
        → general_schema.product_variant.cabys_code
            → general_schema.product.cabys_code (PK, used in electronic_sale_invoice_items FK)
            → general_schema.product.tax_rate_id
                → general_schema.tax_rate.rate_percentage (used for per-item tax in digital_sale_invoice_item)
```

This lookup chain ensures that:

- The `electronic_sale_invoice_items` reference the national CABYS catalog directly (static tax values).
- The `digital_sale_invoice_item` rows store resolved per-item tax rates from the `tax_rate` table (dynamic FK references).

---

## Lifecycle Flow

```
1. Sale created (is_completed = false, has_electronic_invoice = false)
   │
2. Customer payments registered and verified
   │
3. When verified payments ≥ sale.total_amount:
   │  sale.is_completed = true
   │
   ├─── TRIGGER: create_digital_sale_invoice()
   │    ├── INSERT digital_sale_invoice (initial totals from sale)
   │    ├── INSERT digital_sale_invoice_item (per sale_item, with per-item tax from product → tax_rate)
   │    ├── UPDATE digital_sale_invoice (recompute totals from item aggregates)
   │    └── INSERT digital_sale_invoice_payment (per verified payment)
   │
   ├─── TRIGGER: link_sale_to_session()
   │    └── INSERT cash_register_sale
   │
   └─── TRIGGER: award_points()
        └── INSERT score_transaction + UPDATE tenant_customer_score
   │
4. Application creates electronic_sale_invoice (if required)
   │  ├── INSERT electronic_sale_invoice (Hacienda fields)
   │  ├── INSERT electronic_sale_invoice_items (per CABYS line)
   │  ├── UPDATE sale SET has_electronic_invoice = true
   │  ├── Generate + sign XML → store in xml_signed
   │  └── Submit to Hacienda API → update hacienda_status
   │
5. Hacienda responds:
      accepted  → hacienda_status = 'accepted'
      rejected  → hacienda_status = 'rejected' + review xml response
```

## Hacienda Status Lifecycle

```
pending → accepted    (normal flow)
pending → rejected    (XML errors, invalid data, duplicate key_number)
```

When `hacienda_status = 'rejected'`, the application should:

1. Review `hacienda_response_xml` for error details.
2. Fix the data (e.g., correct CABYS code, fix amounts).
3. Generate a new key_number and consecutive_number.
4. Re-submit.

---

## Query Examples

### Check if a sale has both invoice types

```sql
SELECT
    s.sale_id,
    s.is_completed,
    s.has_electronic_invoice,
    dsi.digital_sale_invoice_id,
    esi.electronic_sale_invoice_id,
    esi.hacienda_status
FROM pos_schema.sale s
LEFT JOIN pos_schema.digital_sale_invoice dsi ON s.sale_id = dsi.sale_id
LEFT JOIN pos_schema.electronic_sale_invoice esi ON s.sale_id = esi.sale_id
WHERE s.sale_id = '<sale_id>';
```

### List electronic invoice items with CABYS product names

```sql
SELECT
    esi_items.line_number,
    esi_items.cabys_code,
    p.product_name AS cabys_product_name,
    esi_items.description,
    esi_items.quantity,
    esi_items.unit_price,
    esi_items.subtotal,
    esi_items.tax_rate,
    esi_items.tax_amount,
    esi_items.total_line_amount
FROM pos_schema.electronic_sale_invoice_items esi_items
JOIN general_schema.product p ON esi_items.cabys_code = p.cabys_code
WHERE esi_items.electronic_sale_invoice_id = '<electronic_sale_invoice_id>'
ORDER BY esi_items.line_number;
```

### List all electronic invoices for a tenant with Hacienda status

```sql
SELECT
    esi.key_number,
    esi.consecutive_number,
    esi.issue_date,
    esi.issuer_name,
    esi.receiver_name,
    esi.total_voucher,
    esi.hacienda_status,
    esi.hacienda_response_date
FROM pos_schema.electronic_sale_invoice esi
WHERE esi.tenant_id = '<tenant_id>'
ORDER BY esi.issue_date DESC;
```

---

## Common Troubleshooting

- **No digital invoice after payment**: Confirm `pos_schema.verify_customer_payment` set `sale.is_completed = true` and the `on_sale_completed_create_digital_sale_invoice` trigger exists on `pos_schema.sale`.
- **CABYS code rejected**: Verify the `cabys_code` in `electronic_sale_invoice_items` exists in `general_schema.product`. The FK constraint will prevent insertion of invalid codes.
- **Hacienda rejects invoice**: Check `hacienda_response_xml` for the detailed error. Common causes: duplicate `key_number`, invalid `issuer_identification`, or mismatched totals in `ResumenFactura`.
- **Totals mismatch**: Ensure `total_voucher = total_net_sale + total_tax` and that the sum of all item `total_line_amount` equals `total_voucher`.
- **Missing `has_electronic_invoice`**: The application must explicitly `UPDATE pos_schema.sale SET has_electronic_invoice = true` after creating the electronic invoice — this is not automated by a trigger.

## Notes for Integrators / Developers

- The digital sale invoice is **always** created automatically. The electronic invoice is **optional** and depends on whether the tenant is required to submit electronic invoices to Hacienda.
- Never create an electronic invoice without a completed sale and an existing digital invoice. The digital invoice is the source of truth for payment audit.
- CABYS codes must exist in `general_schema.product` before inserting `electronic_sale_invoice_items`. Pre-populate the CABYS catalog from Hacienda's official list.
- The `xml_signed` field should contain the complete XML document with XMLDSig digital signature. Do not store partial or unsigned XML.
- Use `NUMERIC(18,5)` precision for all Hacienda monetary fields. This matches the 5-decimal precision required by the Hacienda XML schema.
- Tests demonstrating the full flow are available in [`test/pos/testInvoiceTypes.sql`](../../test/pos/testInvoiceTypes.sql).
