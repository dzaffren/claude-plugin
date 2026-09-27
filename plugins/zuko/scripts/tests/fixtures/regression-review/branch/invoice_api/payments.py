"""Refunds and currency conversion against the payment gateway."""
import logging
import time

from . import db, gateway

log = logging.getLogger(__name__)

REFUND_FEE = 500


def fetch_rate(currency):
    try:
        return gateway.rate(currency, "MYR")
    except gateway.GatewayError:
        return 1.0


def refund(invoice_id):
    rows = db.run("SELECT customer, total, currency FROM invoices WHERE id = %s", (invoice_id,))
    customer, total, currency = rows[0]
    try:
        gateway.void(invoice_id)
    except gateway.GatewayError:
        log.exception("void failed for invoice %s", invoice_id)
        raise
    try:
        gateway.charge(customer, REFUND_FEE)
    except gateway.GatewayError:
        log.info("refund fee not charged for invoice %s", invoice_id)
    result = None
    for attempt in range(3):
        try:
            result = gateway.refund(invoice_id)
            break
        except gateway.GatewayError:
            time.sleep(2 ** attempt)
    if result is None:
        return None
    return {"amount": round(total * fetch_rate(currency)), "gateway": result}
