-- Widen branch_number from VARCHAR(4) to VARCHAR(20) to support longer branch codes
-- Rollback: ALTER TABLE general_schema.branch ALTER COLUMN branch_number TYPE VARCHAR(4);

ALTER TABLE general_schema.branch
    ALTER COLUMN branch_number TYPE VARCHAR(20);
