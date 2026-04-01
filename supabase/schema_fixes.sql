-- Apply this after your base schema script.
-- It fixes policy logic, enables required RLS tables, and keeps updated_at accurate.

-- 1) Enable RLS on tables where you created policies.
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- 2) Recreate policies that map auth.users -> public.users correctly.
DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
CREATE POLICY "Users can view their own orders"
  ON orders FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM users u
      WHERE u.id = orders.user_id
        AND u.auth_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can view their own cart" ON carts;
CREATE POLICY "Users can view their own cart"
  ON carts FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM users u
      WHERE u.id = carts.user_id
        AND u.auth_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can view their own wishlist" ON wishlists;
CREATE POLICY "Users can view their own wishlist"
  ON wishlists FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM users u
      WHERE u.id = wishlists.user_id
        AND u.auth_id = auth.uid()
    )
  );

-- 3) Allow admin users to insert/update products.
DROP POLICY IF EXISTS "Admin can manage products" ON products;
CREATE POLICY "Admin can manage products"
  ON products FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM admin_users a
      WHERE a.auth_id = auth.uid()
        AND a.is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM admin_users a
      WHERE a.auth_id = auth.uid()
        AND a.is_active = true
    )
  );

DROP POLICY IF EXISTS "Admin can manage product metals" ON product_metals;
ALTER TABLE product_metals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin can manage product metals"
  ON product_metals FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM admin_users a
      WHERE a.auth_id = auth.uid()
        AND a.is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM admin_users a
      WHERE a.auth_id = auth.uid()
        AND a.is_active = true
    )
  );

-- 4) Keep updated_at columns current automatically.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_admin_users_updated_at ON admin_users;
CREATE TRIGGER trg_admin_users_updated_at
BEFORE UPDATE ON admin_users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_categories_updated_at ON categories;
CREATE TRIGGER trg_categories_updated_at
BEFORE UPDATE ON categories
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_collections_updated_at ON collections;
CREATE TRIGGER trg_collections_updated_at
BEFORE UPDATE ON collections
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_carts_updated_at ON carts;
CREATE TRIGGER trg_carts_updated_at
BEFORE UPDATE ON carts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_reviews_updated_at ON reviews;
CREATE TRIGGER trg_reviews_updated_at
BEFORE UPDATE ON reviews
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_product_variants_updated_at ON product_variants;
CREATE TRIGGER trg_product_variants_updated_at
BEFORE UPDATE ON product_variants
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_coupons_updated_at ON coupons;
CREATE TRIGGER trg_coupons_updated_at
BEFORE UPDATE ON coupons
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
