import reports


def test_format_total_shows_ringgit_with_separators():
    assert reports.format_total(123456) == "RM 1,234.56"
