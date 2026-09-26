"""Sessions, login, and the admin check."""
import logging
from functools import wraps

from flask import abort, session
from werkzeug.security import check_password_hash

from . import db

log = logging.getLogger(__name__)


def login_required(view):
    """Every route that shows invoices is wrapped in this."""
    @wraps(view)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            abort(401)
        return view(*args, **kwargs)
    return wrapped


def login(username, password):
    rows = db.run("SELECT id, password_hash FROM users WHERE username = %s", (username,))
    if not rows or not check_password_hash(rows[0][1], password):
        log.warning("login failed for %s", username)
        return None
    session["user_id"] = rows[0][0]
    return rows[0][0]


def is_admin(user_id):
    try:
        roles = db.run("SELECT role FROM roles WHERE user_id = %s", (user_id,))
    except db.DatabaseError:
        return False
    return any(role == "admin" for (role,) in roles)
