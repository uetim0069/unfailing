-- Unfailing Veterinary & Pest Control Services
-- PostgreSQL schema for the store and the admin product section.
-- Run once:  psql "$DATABASE_URL" -f schema.sql

BEGIN;

-- ---------- users (sign in / sign up, and the admin role) ----------
CREATE TABLE IF NOT EXISTS users (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name      VARCHAR(120) NOT NULL CHECK (char_length(full_name) >= 2),
  email          VARCHAR(255) NOT NULL,
  phone          VARCHAR(30),
  password_hash  TEXT NOT NULL,                       -- bcrypt/argon2 hash, never the password
  role           VARCHAR(10) NOT NULL DEFAULT 'customer' CHECK (role IN ('customer','admin')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS users_email_uq ON users (lower(email));

-- ---------- newsletter ----------
CREATE TABLE IF NOT EXISTS newsletter_subscribers (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email       VARCHAR(255) NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS newsletter_email_uq ON newsletter_subscribers (lower(email));

-- ---------- categories ----------
CREATE TABLE IF NOT EXISTS categories (
  id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name  VARCHAR(80) NOT NULL UNIQUE,
  slug  VARCHAR(100) NOT NULL UNIQUE
);

-- ---------- products (uploaded by admins) ----------
CREATE TABLE IF NOT EXISTS products (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  category_id       BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  name              VARCHAR(160) NOT NULL CHECK (char_length(trim(name)) > 0),
  slug              VARCHAR(190) NOT NULL UNIQUE,
  description       TEXT NOT NULL DEFAULT '',
  price             NUMERIC(12,2) NOT NULL CHECK (price >= 0),            -- selling price, in naira
  compare_at_price  NUMERIC(12,2) CHECK (compare_at_price IS NULL OR compare_at_price >= price), -- old price shown struck through
  image_url         TEXT,                                                  -- path or URL of the uploaded photo
  stock_qty         INTEGER NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,                         -- FALSE hides it from the store
  created_by        BIGINT REFERENCES users(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS products_active_created_idx ON products (is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS products_category_idx       ON products (category_id);
CREATE INDEX IF NOT EXISTS products_name_idx           ON products (lower(name));

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS products_set_updated_at ON products;
CREATE TRIGGER products_set_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- seed data: the 8 products currently shown in the store ----------
INSERT INTO categories (name, slug) VALUES
  ('Veterinary drugs & supplements', 'veterinary-drugs-supplements'),
  ('Pet accessories',                'pet-accessories'),
  ('Poultry',                        'poultry'),
  ('Equipment & consumables',        'equipment-consumables')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO products (category_id, name, slug, description, price, compare_at_price, stock_qty)
SELECT c.id, v.name, v.slug, v.description, v.price, v.compare_at_price, v.stock_qty
FROM (VALUES
  ('pet-accessories',                'Medium Mouth Guard',            'medium-mouth-guard',      'Protective mouth guard for medium-sized dogs.',        800,  900, 50),
  ('pet-accessories',                'Kennel Chain Big',              'kennel-chain-big',        'Heavy-duty kennel chain for large dogs.',              6000, 6100, 20),
  ('poultry',                        'Davita Poultry 50g',            'davita-poultry-50g',      'Vitamin supplement for poultry, 50g sachet.',           700,  800, 100),
  ('poultry',                        'Davita Poultry',                'davita-poultry',          'Vitamin supplement for poultry.',                       900, 1000, 100),
  ('veterinary-drugs-supplements',   'Colla Puppy',                   'colla-puppy',             'Nutritional supplement for growing puppies.',           700,  800, 60),
  ('veterinary-drugs-supplements',   'Boosta Plus 1L',                'boosta-plus-1l',          'Multivitamin booster for livestock, 1 litre.',         1800, 1900, 40),
  ('equipment-consumables',          '20 G Needle (Hyperdermic) Rt.', '20g-needle-hypodermic',   '20 gauge hypodermic needles for injections.',          1100, 1200, 200),
  ('veterinary-drugs-supplements',   'KC Vit 200ml',                  'kc-vit-200ml',            'Vitamin tonic for animals, 200ml bottle.',             3100, 3200, 40)
) AS v(cat_slug, name, slug, description, price, compare_at_price, stock_qty)
JOIN categories c ON c.slug = v.cat_slug
ON CONFLICT (slug) DO NOTHING;

COMMIT;

-- ---------- make someone an admin (run after they have signed up) ----------
-- UPDATE users SET role = 'admin' WHERE lower(email) = lower('you@example.com');

-- ---------- queries the API uses ----------
-- Store (public):   SELECT id, name, description, price, compare_at_price, image_url, stock_qty, created_at
--                   FROM products WHERE is_active ORDER BY created_at DESC;
-- Admin list:       SELECT p.*, c.name AS category FROM products p LEFT JOIN categories c ON c.id = p.category_id ORDER BY p.created_at DESC;
-- Admin create:     INSERT INTO products (category_id, name, slug, description, price, compare_at_price, image_url, stock_qty, is_active, created_by)
--                   VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *;
-- Admin update:     UPDATE products SET category_id=$2, name=$3, description=$4, price=$5, compare_at_price=$6, image_url=$7, stock_qty=$8, is_active=$9 WHERE id=$1 RETURNING *;
-- Admin delete:     DELETE FROM products WHERE id = $1;
