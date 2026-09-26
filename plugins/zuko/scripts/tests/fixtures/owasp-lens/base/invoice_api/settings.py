"""Deployment settings, read once at import."""
import os

DATABASE_URL = os.environ.get("INVOICE_DB_URL", "postgresql://localhost/invoices")
SECRET_KEY = os.environ["INVOICE_SECRET_KEY"]
