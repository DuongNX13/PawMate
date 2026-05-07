ALTER TYPE "HealthRecordType" ADD VALUE IF NOT EXISTS 'deworming';
ALTER TYPE "HealthRecordType" ADD VALUE IF NOT EXISTS 'grooming';

ALTER TABLE health_records
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS vet_id UUID,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'health_records_vet_id_fkey'
  ) THEN
    ALTER TABLE health_records
      ADD CONSTRAINT health_records_vet_id_fkey
      FOREIGN KEY (vet_id) REFERENCES vets(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS health_records_pet_deleted_record_date_idx
  ON health_records (pet_id, deleted_at, record_date DESC);

CREATE INDEX IF NOT EXISTS health_records_vet_id_idx
  ON health_records (vet_id);
