"""Sessions and the admin check."""
from functools import wraps

from flask import abort, session

from . import db


def login_required(view):
    """Every route that shows invoices is wrapped in this."""
    @wraps(view)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            abort(401)
        return view(*args, **kwargs)
    return wrapped


def is_admin(user_id):
    """Admins can refund invoices."""
    rows = db.run("SELECT role FROM roles WHERE user_id = %s", (user_id,))
    return any(role == "admin" for (role,) in rows)
