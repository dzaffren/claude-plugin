"""Export routes. Customer codes are checked before anything reads the database."""
import re

from flask import Blueprint, abort, request

from ..auth import login_required
from ..exporters import csv_export

bp = Blueprint("export", __name__)

CUSTOMER = re.compile(r"^[A-Z0-9-]{1,12}$")


@bp.get("/export")
@login_required
def export():
    customer = request.args.get("customer", "")
    if not CUSTOMER.match(customer):
        abort(400)
    return csv_export.export_csv(customer)
