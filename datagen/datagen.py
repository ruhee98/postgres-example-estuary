import os
import psycopg2
import time
import random
from datetime import datetime
from faker import Faker
import sys
from dotenv import load_dotenv


# --- OpenAI (optional) ---
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
try:
   # Newer SDK style
   from openai import OpenAI
   oi_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None
except Exception:
   oi_client = None


# --- DB connection params ---
load_dotenv()


PG_DSN = os.getenv("PG_DSN")


fake = Faker()


# ---------------------------
# OpenAI review generator
# ---------------------------
def generate_review_text(product_name):
   try:
       # 80/20 positive/negative blend
       sentiment = random.choices(["positive", "negative"], weights=[0.8, 0.2], k=1)[0]
       prompt = (
           f"Write a short, realistic, specific customer review for a product called "
           f"'{product_name}'. Sentiment: {sentiment}. 1-3 sentences. No emojis."
       )


       if not oi_client:
           # Fallback if no API client/key
           return "Great quality and exactly as described. Would buy again."


       resp = oi_client.responses.create(
           model="gpt-4.1-mini",
           input=prompt,
           max_output_tokens=120,
       )
       txt = (resp.output_text or "").strip()
       return txt if txt else "Great quality and exactly as described. Would buy again."
   except Exception as e:
       print("Error generating review:", e)
       return "Great quality and exactly as described. Would buy again."


# ---------------------------
# DB helpers
# ---------------------------
def get_db_connection():
   return psycopg2.connect(PG_DSN)


def get_products(conn):
   cur = conn.cursor()
   cur.execute("SELECT product_id, name FROM retail.products")
   rows = cur.fetchall()
   cur.close()
   product_ids = [r[0] for r in rows]
   product_names = {r[0]: r[1] for r in rows}
   return product_ids, product_names


def get_customer_ids(conn):
   cur = conn.cursor()
   cur.execute("SELECT customer_id FROM retail.customers")
   rows = cur.fetchall()
   cur.close()
   return [r[0] for r in rows]


# ---------------------------
# Insert one customer
# ---------------------------
def insert_customer(conn):
   cur = conn.cursor()
   first = fake.first_name()
   last = fake.last_name()
   email = fake.unique.email()
   phone = fake.phone_number()
   dob = fake.date_of_birth(minimum_age=18, maximum_age=85)
   addr = fake.street_address()
   city = fake.city()
   state = fake.state_abbr()
   postal = fake.postcode()
   country = "USA"


   # customer_id is INT (not serial), so make one: next = COALESCE(MAX,0)+1
   cur.execute("SELECT COALESCE(MAX(customer_id),0)+1 FROM retail.customers")
   next_id = cur.fetchone()[0]


   cur.execute(
       """
       INSERT INTO retail.customers (
         customer_id, first_name, last_name, email, phone_number, date_of_birth,
         address, city, state, postal_code, country
       )
       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
       """,
       (next_id, first, last, email, phone, dob, addr, city, state, postal, country),
   )
   conn.commit()
   cur.close()
   print(f"Inserted customer {next_id} ({first} {last})")


# ---------------------------
# Insert one order (+ items)
# ---------------------------
def insert_order_with_items(conn, customer_ids, product_ids, product_names):
   if not customer_ids or not product_ids:
       return


   cur = conn.cursor()


   # order_id is INT PK (not serial) → generate next
   cur.execute("SELECT COALESCE(MAX(order_id),0)+1 FROM retail.orders")
   order_id = cur.fetchone()[0]


   customer_id = random.choice(customer_ids)
   order_ts = fake.date_time_this_year()
   status = random.choice(["placed", "paid", "packed", "shipped", "delivered", "cancelled"])
   payment_method = random.choice(["credit_card", "debit_card", "paypal", "apple_pay", "bank_transfer"])
   shipping_address = f"{fake.street_address()}, {fake.city()}, {fake.state_abbr()} {fake.postcode()}"
   num_items = random.randint(1, 4)


   # Build items + compute total
   items = []
   total_amount = 0.0
   for _ in range(num_items):
       pid = random.choice(product_ids)
       name = product_names[pid]
       quantity = random.randint(1, 4)
       price = round(random.uniform(5.0, 150.0), 2)  # random if products table has no price
       discount = round(random.uniform(0, 10.0), 2) if random.random() < 0.25 else 0.0
       line_total = max(price * quantity - discount, 0.0)
       total_amount += line_total
       items.append((pid, name, quantity, price, discount))


   # Insert order
   cur.execute(
       """
       INSERT INTO retail.orders (
         order_id, order_detail_id, customer_id, total_amount, order_ts,
         status, payment_method, shipping_address
       )
       VALUES (%s, NULL, %s, %s, %s, %s, %s, %s)
       """,
       (order_id, customer_id, round(total_amount, 2), order_ts, status, payment_method, shipping_address),
   )


   # Insert order_detail rows (order_detail_id is SERIAL → DB assigns)
   for (pid, name, qty, price, disc) in items:
       cur.execute(
           """
           INSERT INTO retail.order_detail (
             order_id, product_id, name, quantity, price, discount_amount
           ) VALUES (%s,%s,%s,%s,%s,%s)
           """,
           (order_id, pid, name, qty, price, disc),
       )


   conn.commit()
   cur.close()
   print(f"Inserted order {order_id} with {len(items)} item(s) for customer {customer_id}")


# ---------------------------
# Insert one review
# ---------------------------
def insert_review(conn, customer_ids, product_ids, product_names):
   if not customer_ids or not product_ids:
       return


   cur = conn.cursor()
   user_id = random.choice(customer_ids)
   product_id = random.choice(product_ids)
   rating = random.randint(1, 5)
   review_time = fake.date_time_this_year()
   review_text = generate_review_text(product_names[product_id])


   cur.execute(
       """
       INSERT INTO retail.reviews (user_id, product_id, rating, review_text, review_time)
       VALUES (%s,%s,%s,%s,%s)
       """,
       (user_id, product_id, rating, review_text, review_time),
   )
   conn.commit()
   cur.close()
   print(f"Inserted review for product {product_id} by user {user_id} (rating {rating})")




def main():
   if not PG_DSN:
       print("❌ PG_DSN not set. Please set PG_DSN in your environment.")
       sys.exit(1)
   conn = None
   try:
       conn = get_db_connection()
       print("PostgreSQL connected successfully")
   except Exception as e:
       print(f"PostgreSQL connection failed at startup: {e}")


   try:
       while True:
           product_ids, product_names = get_products(conn)
           customer_ids = get_customer_ids(conn)


           # Choose an action with simple weights
           action = random.choices(
               ["insert_customer", "insert_order", "insert_review"],
               weights=[0.15, 0.55, 0.30], k=1
           )[0]


           if action == "insert_customer":
               insert_customer(conn)
           elif action == "insert_order":
               insert_order_with_items(conn, customer_ids, product_ids, product_names)
           else:
               insert_review(conn, customer_ids, product_ids, product_names)


           time.sleep(1)  # 1 second tick


   finally:
       if conn:
           try:
               conn.close()
           except:
               pass
       print("👋 Exited cleanly.")


if __name__ == "__main__":
   main()