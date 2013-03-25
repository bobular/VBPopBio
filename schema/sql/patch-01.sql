-- apply this to chado straight from the trunk
ALTER TABLE dbxref ALTER COLUMN accession TYPE character varying(1024);
ALTER TABLE cvterm DROP CONSTRAINT cvterm_c1;
