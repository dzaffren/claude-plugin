"""invoice-api: finance staff export customer invoices."""
from flask import Flask

from . import settings
from .routes.export import bp as export_bp


def create_app():
    app = Flask(__name__)
    app.secret_key = settings.SECRET_KEY
    app.register_blueprint(export_bp)
    return app
