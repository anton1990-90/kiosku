-- Membuat tabel khusus CRM untuk melacak pesanan (lunas & belum lunas)
CREATE TABLE IF NOT EXISTS orders (
  order_id text primary key,
  source text not null default '',
  customer_name text not null default '',
  customer_email text not null default '',
  product_name text not null default '',
  price integer not null default 0,
  status text not null default 'pending', -- 'pending', 'paid', 'expired', etc.
  created_at text not null,
  updated_at text not null
);

CREATE INDEX IF NOT EXISTS orders_status_idx ON orders (status);
CREATE INDEX IF NOT EXISTS orders_source_idx ON orders (source);
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON orders (created_at);
