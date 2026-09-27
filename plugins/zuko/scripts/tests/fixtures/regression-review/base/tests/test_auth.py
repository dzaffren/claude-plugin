from invoice_api import auth


def test_is_admin_true_for_admin_role(monkeypatch):
    monkeypatch.setattr(auth.db, "run", lambda sql, params: [("admin",)])
    assert auth.is_admin(7)


def test_is_admin_false_for_other_roles(monkeypatch):
    monkeypatch.setattr(auth.db, "run", lambda sql, params: [("clerk",)])
    assert not auth.is_admin(7)
