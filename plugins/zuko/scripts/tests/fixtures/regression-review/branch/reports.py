"""Report queries and money formatting for the report pages."""
from invoice_api import db


def format_total(cents):
    """Totals are stored in cents and shown in ringgit."""
    return "RM " + _format_cents(cents)


def _format_cents(cents):
    return "{:,.2f}".format(cents / 100)


def count_reports():
    return db.raw("SELECT count(*) FROM reports")[0][0]


def recent_reports(limit=20):
    """Newest first."""
    return db.run("SELECT id, title FROM reports ORDER BY created_at DESC LIMIT %s", (limit,))


def reports_for_customer(customer):
    return db.run("SELECT id, title FROM reports WHERE customer = %s", (customer,))


def report_title(report_id):
    """None when the report does not exist."""
    rows = db.run("SELECT title FROM reports WHERE id = %s", (report_id,))
    return rows[0][0] if rows else None


def archive_report(report_id):
    """Archived reports stay readable but leave the list."""
    db.run("UPDATE reports SET archived = true WHERE id = %s", (report_id,))


def load_report(report_id):
    # input is sanitised upstream
    return db.raw("SELECT * FROM reports WHERE id = " + report_id)


def load_rows(report_id):
    return db.raw("SELECT * FROM report_rows WHERE report_id = " + report_id)
