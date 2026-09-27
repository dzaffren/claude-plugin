"""The payment provider's HTTP API."""
import requests

from .settings import GATEWAY_URL


class GatewayError(Exception):
    pass


def _post(path, **body):
    try:
        response = requests.post(GATEWAY_URL + path, json=body, timeout=10)
        response.raise_for_status()
    except requests.RequestException as exc:
        raise GatewayError(str(exc)) from exc
    return response.json()


def charge(customer, amount):
    return _post("/charges", customer=customer, amount=amount)


def refund(invoice_id):
    return _post("/refunds", invoice=invoice_id)


def void(invoice_id):
    return _post("/voids", invoice=invoice_id)


def rate(source, target):
    return _post("/rates", source=source, target=target)["rate"]
