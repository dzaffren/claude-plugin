import os

DATABASE_URL = os.environ.get("INVOICE_DB_URL", "postgresql://localhost/invoices")
GATEWAY_URL = os.environ.get("GATEWAY_URL", "https://pay.example.com/v1")
