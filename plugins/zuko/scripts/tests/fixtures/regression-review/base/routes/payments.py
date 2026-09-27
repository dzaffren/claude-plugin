"""Payment routes."""
from flask import Blueprint

from invoice_api import payments
from invoice_api.auth import login_required

bp = Blueprint("payments", __name__)


@bp.get("/rates/<currency>")
@login_required
def currency_rate(currency):
    return {"rate": payments.fetch_rate(currency)}
