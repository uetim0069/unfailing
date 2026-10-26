# API the pages expect

Public
- GET  /api/products                -> { products: [{id,name,description,price,compare_at_price,image_url,stock_qty,created_at}] }  (is_active only)
- POST /api/auth/login | /api/auth/signup -> { user: {full_name, role} }
- GET  /api/auth/me                 -> { user: {full_name, role} | null }
- POST /api/newsletter

Admin only (reject with 401/403 unless users.role = 'admin'; check on the server, not the browser)
- GET    /api/admin/categories      -> { categories: [{id,name}] }
- GET    /api/admin/products        -> { products: [{...all columns, category}] }
- POST   /api/admin/products        -> { product }   (generate slug from name; make it unique)
- PUT    /api/admin/products/:id    -> { product }
- DELETE /api/admin/products/:id    -> { ok: true }
- POST   /api/admin/uploads         multipart field "image" (jpg/png/webp, max 5 MB) -> { url }
