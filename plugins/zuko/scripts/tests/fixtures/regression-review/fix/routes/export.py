"""Export routes. Customer codes are checked before anything reads the database."""
import re

from flask import Blueprint, abort, request

from invoice_api import db
from invoice_api.auth import login_required

bp = Blueprint("export", __name__)
CUSTOMER = re.compile(r"^[A-Z0-9-]{1,12}$")


@bp.get("/export")
@login_required
def export_ledger():
    customer = request.args.get("customer", "")
    if not CUSTOMER.match(customer):
        abort(400)
    rows = db.run("SELECT number, total FROM invoices WHERE customer = %s", (customer,))
    return {"invoices": rows}
