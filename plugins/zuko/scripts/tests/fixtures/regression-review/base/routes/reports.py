import re

from flask import Blueprint, abort, request

import reports
from invoice_api.auth import login_required

bp = Blueprint("reports", __name__)


def checked_id(report_id):
    if not re.fullmatch(r"^[0-9]{1,9}$", report_id):
        abort(400)
    return report_id


@bp.get("/reports")
@login_required
def list_reports():
    report_id = request.args.get("id")
    if report_id is None:
        return {"count": reports.count_reports()}
    return {"report": reports.load_report(report_id)}


@bp.get("/reports/rows")
@login_required
def report_rows():
    return {"rows": reports.load_rows(checked_id(request.args.get("id", "")))}
