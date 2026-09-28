from invoice_api import payments


def test_refund_converts_the_total(monkeypatch):
    monkeypatch.setattr(payments.db, "run", lambda sql, params: [("ACME-01", 1000, "USD")])
    monkeypatch.setattr(payments.gateway, "void", lambda invoice_id: None)
    monkeypatch.setattr(payments.gateway, "charge", lambda customer, amount: None)
    monkeypatch.setattr(payments.gateway, "refund", lambda invoice_id: {"id": "r1"})
    monkeypatch.setattr(payments.gateway, "rate", lambda source, target: 4.5)
    assert payments.refund(9) == {"amount": 4500, "gateway": {"id": "r1"}}
