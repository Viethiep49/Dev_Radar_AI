import pytest

from app.services.numbers import spell_number, spell_text


@pytest.mark.parametrize(
    "value,expected",
    [
        (0, "không"),
        (5, "năm"),
        (10, "mười"),
        (15, "mười lăm"),
        (21, "hai mươi mốt"),
        (25, "hai mươi lăm"),
        (100, "một trăm"),
        (101, "một trăm lẻ một"),
        (115, "một trăm mười lăm"),
        (1000, "một nghìn"),
        (1234, "một nghìn hai trăm ba mươi tư"),
        (1_000_000, "một triệu"),
        (-3, "âm ba"),
    ],
)
def test_spell_number(value, expected):
    assert spell_number(value) == expected


def test_spell_number_handles_decimals():
    assert spell_number(5.5) == "năm phẩy năm"
    assert spell_number(0.25) == "không phẩy hai mươi lăm"


def test_spell_text_replaces_numeric_tokens_and_percent():
    assert spell_text("Bạn đã hoàn thành 12 repo") == "Bạn đã hoàn thành mười hai repo"
    assert spell_text("Tăng 45%") == "Tăng bốn mươi lăm phần trăm"


def test_spell_text_treats_dot_before_three_digits_as_thousands_separator():
    assert spell_text("1.234 sao") == "một nghìn hai trăm ba mươi tư sao"


def test_spell_text_treats_comma_with_non_three_digits_as_decimal():
    assert spell_text("5,5 giờ") == "năm phẩy năm giờ"


def test_spell_text_leaves_non_numeric_text_untouched():
    assert spell_text("Lộ trình của tôi") == "Lộ trình của tôi"
