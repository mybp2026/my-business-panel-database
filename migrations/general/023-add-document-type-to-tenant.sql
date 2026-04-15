-- 023: Add document_type_id to tenant for e-invoice emisor identification type
-- Previously hardcoded as '02' (Cedula Juridica) in the e-invoice query

SET SEARCH_PATH TO general_schema;

ALTER TABLE tenant
  ADD COLUMN IF NOT EXISTS document_type_id INTEGER
    REFERENCES document_type(document_type_id) ON DELETE SET NULL;

-- Default existing tenants to '02' (Cedula Juridica) to preserve current behavior
UPDATE tenant
  SET document_type_id = (SELECT document_type_id FROM document_type WHERE ident_code = '02')
  WHERE document_type_id IS NULL;
