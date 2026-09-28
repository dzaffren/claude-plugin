"""Refunds and currency conversion against the payment gateway."""
import logging

from . import db, gateway

log = logging.getLogger(__name__)

REFUND_FEE = 500


def fetch_rate(currency):
    return gateway.rate(currency, "MYR")


def refund(invoice_id):
    rows = db.run("SELECT customer, total, currency FROM invoices WHERE id = %s", (invoice_id,))
    customer, total, currency = rows[0]
    gateway.void(invoice_id)
    gateway.charge(customer, REFUND_FEE)
    result = gateway.refund(invoice_id)
    return {"amount": round(total * fetch_rate(currency)), "gateway": result}
