-- 0002_photos: photo_assets and photo_export_consents.
--
-- photo_assets deliberately has NO column for a GPS position, a capture location, a street or
-- mailing detail, or a key into the metadata-bearing original file. The original (EXIF-intact)
-- photo is retained only in the uploading user's own private device library per GROUPEVENTS-03 --
-- the server never receives it and has nothing to point at. Adding such a column in a future
-- migration is a boundary change requiring its own review, not an incremental addition (T-04.1-21).
--
-- shared_object_key points at the object-storage tier that holds ONLY output from
-- internal/photo.StripAndReencode (internal/photo/objectstore.go's PutShared accepts no other
-- input, by type). No plaintext-original tier is referenced from this table at all.

CREATE TABLE photo_assets (
    id                uuid PRIMARY KEY,
    owner_user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    shared_object_key text NOT NULL,
    content_type      text NOT NULL,
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX photo_assets_owner_user_id_idx ON photo_assets(owner_user_id);

-- photo_export_consents records that subject_user_id (a person identifiable in the photo, distinct
-- from the uploader) has granted consent for this asset to be used in an export (e.g. a digital
-- certificate) -- a future plan's concern; this migration only lays down the table shape.
CREATE TABLE photo_export_consents (
    photo_asset_id  uuid NOT NULL REFERENCES photo_assets(id) ON DELETE CASCADE,
    subject_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    granted_at      timestamptz,
    PRIMARY KEY (photo_asset_id, subject_user_id)
);
