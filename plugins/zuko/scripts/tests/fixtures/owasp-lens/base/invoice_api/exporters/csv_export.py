"""CSV export of one customer's invoices."""
import csv
import io

from .. import db


def export_csv(customer):
    rows = db.run(
        "SELECT number, issued_at, total FROM invoices WHERE customer = %s ORDER BY issued_at",
        (customer,),
    )
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["number", "issued_at", "total"])
    writer.writerows(rows)
    return out.getvalue(), 200, {"Content-Type": "text/csv"}
