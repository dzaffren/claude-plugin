"""The invoice-api Flask app."""
from flask import Flask


def create_app():
    from routes import export, payments, reports

    app = Flask(__name__)
    app.register_blueprint(export.bp)
    app.register_blueprint(reports.bp)
    app.register_blueprint(payments.bp)
    return app
