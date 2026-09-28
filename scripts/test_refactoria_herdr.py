#!/usr/bin/env python3
"""Focused tests for the Herdr TOML visual merge slice."""
from __future__ import annotations

import tomllib
from pathlib import Path

import refactoria_herdr as herdr

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "herdr/config.toml").read_bytes()
PROFILE = (ROOT / "herdr/profiles/refactoria.toml").read_bytes()
COMPLEX_TARGET = b"""# Preserve this non-theme comment and every unrelated setting.
onboarding = true

[keys]
prefix = "keep-key"

[remote]
endpoint = "keep-remote"
roles = ["remote-only"]

[ui.toast]
delivery = "terminal"

[ui]
sidebar_width = 37
accent = "#000000"

[theme]
name = "old-theme"
auto_switch = true

[theme.custom]
panel_bg = "old-panel"
remote_only = "keep-role"
"""

ARRAY_TARGET = b"""[theme]
name = "terminal" # keep comment
auto_switch = false
[[remote]]
name = "unrelated"
[theme.custom]
panel_bg = "black"
[ui]
accent = "blue"
"""

SPACED_COMMENT_TARGET = b"""[theme]
  name   =   "terminal#literal"   # keep name
auto_switch\t=\tfalse\t# keep switch
[theme.custom]
panel_bg   =   "#000000#literal" # keep panel
[ui]
accent\t=\t"#000000#literal"\t# keep accent
"""

CUSTOM_ARRAY_TARGET = b"""[theme]
name = "terminal"
auto_switch = false
[theme.custom]
panel_bg = "black"
[[remote]]
name = "unrelated"
[ui]
accent = "blue"
"""


def expect_error(source: bytes, target: bytes, text: str) -> None:
    try:
        herdr.plan_visual_merge(source, target)
    except herdr.HerdrError as exc:
        assert text in str(exc), str(exc)
    else:
        raise AssertionError(f"expected HerdrError containing {text!r}")


def test_portable_profile_matches_mac_visual_roles() -> None:
    assert herdr.plan_visual_merge(
        PROFILE, COMPLEX_TARGET, source_label="herdr/profiles/refactoria.toml"
    ) == herdr.plan_visual_merge(SOURCE, COMPLEX_TARGET)


def test_complex_target_preservation_and_idempotency() -> None:
    planned = herdr.plan_visual_merge(SOURCE, COMPLEX_TARGET)
    parsed = tomllib.loads(planned.decode("utf-8"))
    source = tomllib.loads(SOURCE.decode("utf-8"))

    assert parsed["onboarding"] is True
    assert parsed["keys"]["prefix"] == "keep-key"
    assert parsed["remote"] == {"endpoint": "keep-remote", "roles": ["remote-only"]}
    assert parsed["ui"]["toast"]["delivery"] == "terminal"
    assert parsed["ui"]["sidebar_width"] == 37
    assert parsed["theme"]["custom"]["remote_only"] == "keep-role"
    assert parsed["theme"]["name"] == source["theme"]["name"]
    assert parsed["theme"]["auto_switch"] == source["theme"]["auto_switch"]
    assert parsed["theme"]["custom"]["panel_bg"] == source["theme"]["custom"]["panel_bg"]
    assert b"# Preserve this non-theme comment" in planned
    assert b'endpoint = "keep-remote"' in planned
    assert b'delivery = "terminal"' in planned

    assert herdr.plan_visual_merge(SOURCE, planned) == planned


def test_array_headers_boundaries_and_comments_are_preserved() -> None:
    planned = herdr.plan_visual_merge(SOURCE, ARRAY_TARGET)
    parsed = tomllib.loads(planned.decode("utf-8"))

    assert parsed["remote"] == [{"name": "unrelated"}]
    assert b'[[remote]]\nname = "unrelated"\n' in planned
    assert b'name = "one-dark" # keep comment\n' in planned


def test_visual_value_spacing_and_quoted_hashes_are_preserved() -> None:
    planned = herdr.plan_visual_merge(SOURCE, SPACED_COMMENT_TARGET)

    assert b'  name   =   "one-dark"   # keep name\n' in planned
    assert b"auto_switch\t=\tfalse\t# keep switch\n" in planned
    assert b'panel_bg   =   "#0B0714" # keep panel\n' in planned
    assert b'accent\t=\t"#7127FF"\t# keep accent\n' in planned


def test_missing_custom_roles_are_inserted_before_following_array() -> None:
    planned = herdr.plan_visual_merge(SOURCE, CUSTOM_ARRAY_TARGET)
    parsed = tomllib.loads(planned.decode("utf-8"))
    array_start = planned.index(b"[[remote]]")

    for key in tomllib.loads(SOURCE.decode("utf-8"))["theme"]["custom"]:
        assert planned.index(f"{key} = ".encode("utf-8")) < array_start
    assert parsed["remote"] == [{"name": "unrelated"}]


def test_visual_array_tables_and_multiline_values_fail_closed() -> None:
    for target in (
        b'[[theme]]\nname = "old-theme"\nauto_switch = true\n',
        b'[theme]\nname = "old-theme"\nauto_switch = true\n[[theme.custom]]\npanel_bg = "old"\n',
        b'[theme]\nname = "old-theme"\nauto_switch = true\n[theme.custom]\npanel_bg = "old"\n[[ui]]\naccent = "#000"\n',
    ):
        expect_error(SOURCE, target, "unsupported visual array-of-tables")

    expect_error(
        SOURCE,
        b'[theme]\nname = """old-theme\ncontinued"""\nauto_switch = true\n',
        "unsupported multiline TOML visual key",
    )


def test_malformed_inline_and_dotted_inputs_fail_closed() -> None:
    expect_error(b"[theme\n", COMPLEX_TARGET, "malformed TOML: herdr/config.toml")
    expect_error(SOURCE, b"[theme\n", "malformed TOML: .config/herdr/config.toml")
    expect_error(
        SOURCE,
        b'theme = {name = "old-theme", auto_switch = true, custom = {panel_bg = "old"}}\nui = {accent = "#000000"}\n',
        "unsupported inline or dotted Herdr table: theme",
    )
    expect_error(
        SOURCE,
        b'theme.name = "old-theme"\ntheme.auto_switch = true\ntheme.custom.panel_bg = "old"\nui.accent = "#000000"\n',
        "unsupported inline or dotted Herdr table: theme",
    )
    expect_error(
        SOURCE,
        b'[theme]\nname = "old-theme"\nauto_switch = true\ncustom.panel_bg = "old"\n[ui]\naccent = "#000000"\n',
        "unsupported inline or dotted Herdr table: theme.custom",
    )


def test_source_visual_keys_are_required() -> None:
    expect_error(
        b'[theme]\nname = "only-name"\n[theme.custom]\npanel_bg = "#000"\n',
        COMPLEX_TARGET,
        "source Herdr config lacks approved visual keys",
    )


def main() -> None:
    test_portable_profile_matches_mac_visual_roles()
    test_complex_target_preservation_and_idempotency()
    test_array_headers_boundaries_and_comments_are_preserved()
    test_visual_value_spacing_and_quoted_hashes_are_preserved()
    test_missing_custom_roles_are_inserted_before_following_array()
    test_visual_array_tables_and_multiline_values_fail_closed()
    test_malformed_inline_and_dotted_inputs_fail_closed()
    test_source_visual_keys_are_required()
    print("PASS RefactorIA Herdr merge tests")


if __name__ == "__main__":
    main()
