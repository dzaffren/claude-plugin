"""Payment routes."""
from flask import Blueprint, abort, session

from invoice_api import payments
from invoice_api.auth import is_admin, login_required

bp = Blueprint("payments", __name__)


@bp.get("/rates/<currency>")
@login_required
def currency_rate(currency):
    return {"rate": payments.fetch_rate(currency)}


@bp.post("/invoices/<int:invoice_id>/refund")
@login_required
def refund_invoice(invoice_id):
    if not is_admin(session["user_id"]):
        abort(403)
    return {"refund": payments.refund(invoice_id)}
