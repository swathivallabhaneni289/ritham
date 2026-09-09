-- Reverses 0001_identity.up.sql. Tables are dropped in reverse dependency order: sessions
-- references users via a foreign key, so it must go first.

DROP TABLE sessions;
DROP TABLE users;
