--Connect to your instance and create a new user and password:
CREATE USER flow_capture WITH PASSWORD 'secret' REPLICATION;

--Assign the appropriate role.
GRANT pg_read_all_data TO flow_capture;

--Create the watermarks table, grant privileges, and create publication:

CREATE TABLE IF NOT EXISTS public.flow_watermarks (slot TEXT PRIMARY KEY, watermark TEXT);
GRANT ALL PRIVILEGES ON TABLE public.flow_watermarks TO flow_capture;
CREATE PUBLICATION flow_publication;
ALTER PUBLICATION flow_publication SET (publish_via_partition_root = true);
ALTER PUBLICATION flow_publication ADD TABLE public.flow_watermarks, <other_tables>;
--Set WAL level to logical:
ALTER SYSTEM SET wal_level = logical;

CREATE SCHEMA IF NOT EXISTS retail;

CREATE TABLE IF NOT EXISTS retail.products (
  product_id   SERIAL PRIMARY KEY,
  sku          VARCHAR(32) UNIQUE NOT NULL,
  name         VARCHAR(120) NOT NULL,
  category     VARCHAR(60)  NOT NULL,
  gender       VARCHAR(12)  NOT NULL,
  color        VARCHAR(40)  NOT NULL,
  size_label   VARCHAR(12)  NOT NULL,
  price        NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO retail.products (sku, name, category, gender, color, size_label, price)
VALUES
('TSH-0001','Classic Cotton T-Shirt','Tops','Unisex','White','M',19.99),
('TSH-0002','Classic Cotton T-Shirt','Tops','Unisex','Black','L',19.99),
('TSH-0003','Classic Cotton T-Shirt','Tops','Unisex','Navy','S',19.99),
('TSH-0004','Graphic Tee','Tops','Unisex','Grey','M',24.99),
('TSH-0005','Oversized Tee','Tops','Unisex','Beige','L',24.99),

('BLU-0006','Linen Blouse','Tops','Women','White','M',39.99),
('SWP-0007','Fleece Sweatshirt','Tops','Unisex','Olive','M',49.99),
('CRD-0008','Knit Cardigan','Tops','Women','Navy','S',59.99),
('PLS-0009','Polo Shirt','Tops','Men','Blue','L',34.99),
('TNK-0010','Ribbed Tank Top','Tops','Women','Black','M',14.99),

('JNS-0011','Slim Fit Jeans','Bottoms','Men','Blue','32',49.99),
('JNS-0012','High-Rise Jeans','Bottoms','Women','Black','28',59.99),
('CHN-0013','Chino Pants','Bottoms','Men','Beige','34',44.99),
('SKT-0014','A-Line Skirt','Bottoms','Women','Navy','M',39.99),
('SRT-0015','Casual Shorts','Bottoms','Unisex','Khaki','M',29.99),

('DRS-0016','Floral Summer Dress','Dresses','Women','Red','M',69.99),
('DRS-0017','Wrap Midi Dress','Dresses','Women','Green','S',79.99),
('DRS-0018','Slip Dress','Dresses','Women','Black','M',74.99),
('DRS-0019','Shirt Dress','Dresses','Women','Blue','L',64.99),
('JMP-0020','Denim Jumpsuit','Dresses','Women','Blue','M',89.99),

('JKT-0021','Denim Jacket','Outerwear','Unisex','Blue','L',79.99),
('COA-0022','Light Puffer Jacket','Outerwear','Unisex','Black','M',99.99),
('TRN-0023','Trench Coat','Outerwear','Women','Beige','M',129.99),
('BLZ-0024','Tailored Blazer','Outerwear','Men','Navy','L',119.99),
('RNC-0025','Raincoat','Outerwear','Unisex','Olive','M',89.99),

('SNK-0026','Running Sneakers','Footwear','Unisex','Black','9',89.99),
('SNK-0027','Running Sneakers','Footwear','Unisex','White','8',89.99),
('LOF-0028','Leather Loafers','Footwear','Men','Brown','10',129.99),
('BTN-0029','Chelsea Boots','Footwear','Unisex','Black','9',149.99),
('SDL-0030','Strappy Sandals','Footwear','Women','Beige','7',69.99),

('BLT-0031','Leather Belt','Accessories','Unisex','Brown','M',24.99),
('SCF-0032','Wool Scarf','Accessories','Unisex','Grey','L',29.99),
('CAP-0033','Cotton Cap','Accessories','Unisex','Navy','M',19.99),
('TTE-0034','Canvas Tote Bag','Accessories','Unisex','Natural','L',24.99),
('BNI-0035','Knit Beanie','Accessories','Unisex','Black','M',14.99),

('HOD-0036','Fleece Hoodie','Tops','Unisex','Charcoal','L',49.99),
('RGN-0037','Raglan Tee','Tops','Men','White','M',22.99),
('BTN-0038','Button-Down Shirt','Tops','Men','Light Blue','L',44.99),
('BLS-0039','Silk Blend Blouse','Tops','Women','Ivory','M',64.99),
('CRO-0040','Cropped Tee','Tops','Women','Pink','S',21.99),

('LGS-0041','High-Waist Leggings','Bottoms','Women','Black','M',39.99),
('TRK-0042','Track Pants','Bottoms','Unisex','Grey','M',34.99),
('SHR-0043','Biker Shorts','Bottoms','Women','Black','S',24.99),
('CAR-0044','Cargo Pants','Bottoms','Men','Olive','34',59.99),
('WDE-0045','Wide-Leg Trousers','Bottoms','Women','Beige','M',69.99),

('CRD-0046','Corduroy Jacket','Outerwear','Men','Tan','L',99.99),
('PRK-0047','Parka Jacket','Outerwear','Unisex','Navy','M',129.99),
('GIL-0048','Lightweight Gilet','Outerwear','Unisex','Black','M',69.99),
('HIK-0049','Hiking Boots','Footwear','Unisex','Brown','10',139.99),
('SLP-0050','Slip-On Sneakers','Footwear','Unisex','White','9',74.99);


-- =========================================
--  Customers table
-- =========================================
CREATE TABLE IF NOT EXISTS retail.customers (
    customer_id     INT PRIMARY KEY,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    email           VARCHAR(255) UNIQUE NOT NULL,
    phone_number    VARCHAR(50),
    date_of_birth   DATE,
    address         VARCHAR(255),
    city            VARCHAR(100),
    state           VARCHAR(50),
    postal_code     VARCHAR(20),
    country         VARCHAR(50) DEFAULT 'USA',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
--  Orders table
-- =========================================
CREATE TABLE IF NOT EXISTS retail.orders (
    order_id           INT PRIMARY KEY,
    order_detail_id    INT,
    customer_id        INT REFERENCES retail.customers(customer_id),
    total_amount       NUMERIC(12,2),
    order_ts           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status             VARCHAR(50),
    payment_method     VARCHAR(50),
    shipping_address   VARCHAR(255),
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS retail.order_detail (
    order_detail_id  SERIAL PRIMARY KEY,
    order_id         INT REFERENCES retail.orders(order_id) ON DELETE CASCADE,
    product_id       INT REFERENCES retail.products(product_id),
    name             VARCHAR(255),
    quantity         INT CHECK (quantity > 0),
    price            NUMERIC(10,2) CHECK (price >= 0),
    discount_amount  NUMERIC(10,2) DEFAULT 0 CHECK (discount_amount >= 0),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
--  Reviews table
-- =========================================
CREATE TABLE IF NOT EXISTS retail.reviews (
    review_id     SERIAL PRIMARY KEY,
    user_id       INT REFERENCES retail.customers(customer_id),
    product_id    INT REFERENCES retail.products(product_id),
    rating        INT CHECK (rating BETWEEN 1 AND 5),
    review_text   TEXT,
    review_time   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
