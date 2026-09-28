#!/usr/bin/env python3
"""Herdr-specific TOML visual merge and preservation helpers."""
from __future__ import annotations

import json
import re
import tomllib
from typing import Any


class HerdrError(RuntimeError):
    """A Herdr visual merge cannot be performed safely."""


_HEADER = re.compile(r"^\s*\[(?!\[)(.+)\]\s*(?:#.*)?$")
_ARRAY_HEADER = re.compile(r"^\s*\[\[(.+)\]\]\s*(?:#.*)?$")
_ASSIGN = re.compile(r"^(?P<indent>[ \t]*)(?P<key>[A-Za-z0-9_-]+|\"[^\"]+\"|'[^']+')[ \t]*=")
_VISUAL_SECTIONS = (
    ("theme", ("theme",)),
    ("theme.custom", ("theme", "custom")),
    ("ui", ("ui",)),
)


def _parse_toml(data: bytes, label: str) -> dict[str, Any]:
    try:
        value = tomllib.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, tomllib.TOMLDecodeError) as exc:
        raise HerdrError(f"malformed TOML: {label}") from exc
    if not isinstance(value, dict):
        raise HerdrError(f"TOML root must be a table: {label}")
    return value


def _tables(text: str) -> tuple[dict[str, int], list[tuple[int, str, bool]]]:
    headers: dict[str, int] = {}
    ordered: list[tuple[int, str, bool]] = []
    for index, line in enumerate(text.splitlines()):
        match = _HEADER.match(line)
        is_array = False
        if match is None:
            match = _ARRAY_HEADER.match(line)
            is_array = match is not None
        if match:
            name = match.group(1)
            if not is_array:
                if name in headers:
                    raise HerdrError(f"duplicate TOML table: {name}")
                headers[name] = index
            ordered.append((index, name, is_array))
    return headers, ordered


def _has(data: dict[str, Any], path: tuple[str, ...]) -> bool:
    value: Any = data
    for key in path:
        if not isinstance(value, dict) or key not in value:
            return False
        value = value[key]
    return True


def _visual_values(source: dict[str, Any]) -> dict[str, dict[str, Any]]:
    theme, ui = source.get("theme"), source.get("ui")
    if (
        not isinstance(theme, dict)
        or not isinstance(ui, dict)
        or not isinstance(theme.get("custom"), dict)
        or not {"name", "auto_switch"} <= theme.keys()
        or "accent" not in ui
    ):
        raise HerdrError("source Herdr config lacks approved visual keys")
    return {
        "theme": {"name": theme["name"], "auto_switch": theme["auto_switch"]},
        "theme.custom": dict(theme["custom"]),
        "ui": {"accent": ui["accent"]},
    }


def _visual_equal(data: dict[str, Any], values: dict[str, dict[str, Any]]) -> bool:
    theme, ui = data.get("theme"), data.get("ui")
    custom = theme.get("custom") if isinstance(theme, dict) else None
    return (
        isinstance(theme, dict)
        and isinstance(custom, dict)
        and isinstance(ui, dict)
        and theme.get("name") == values["theme"]["name"]
        and theme.get("auto_switch") == values["theme"]["auto_switch"]
        and ui.get("accent") == values["ui"]["accent"]
        and all(custom.get(key) == value for key, value in values["theme.custom"].items())
    )


def _literal(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (int, float)):
        return str(value).lower()
    if isinstance(value, list):
        return "[" + ", ".join(_literal(item) for item in value) + "]"
    raise HerdrError("unsupported Herdr visual TOML value")


def _comment_start(text: str, start: int) -> int | None:
    index = start
    while index < len(text):
        if text[index] == "#":
            return index
        if text.startswith('"""', index) or text.startswith("'''", index):
            raise ValueError("multiline string")
        if text[index] == '"':
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                    continue
                if text[index] == '"':
                    index += 1
                    break
                index += 1
            else:
                raise ValueError("unterminated string")
            continue
        if text[index] == "'":
            index += 1
            while index < len(text) and text[index] != "'":
                index += 1
            if index == len(text):
                raise ValueError("unterminated string")
            index += 1
            continue
        index += 1
    return None


def _visual_value_span(content: str, match: re.Match[str], section: str, key: str) -> tuple[int, int]:
    value_start = match.end()
    while value_start < len(content) and content[value_start] in " \t":
        value_start += 1
    try:
        comment = _comment_start(content, value_start)
        value_end = len(content) if comment is None else comment
        while value_end > value_start and content[value_end - 1] in " \t":
            value_end -= 1
        if value_start == value_end:
            raise ValueError("missing value")
        tomllib.loads("[check]\n" + content)
    except (tomllib.TOMLDecodeError, ValueError) as exc:
        raise HerdrError(f"unsupported multiline TOML visual key: {section}.{key}") from exc
    return value_start, value_end


def _contains_multiline_string(text: str) -> bool:
    index = 0
    while index < len(text):
        if text[index] == "#":
            newline = text.find("\n", index)
            index = len(text) if newline < 0 else newline + 1
            continue
        if text.startswith('"""', index) or text.startswith("'''", index):
            return True
        if text[index] == '"':
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                    continue
                if text[index] == '"':
                    index += 1
                    break
                index += 1
            continue
        if text[index] == "'":
            index += 1
            while index < len(text) and text[index] != "'":
                index += 1
            if index < len(text):
                index += 1
            continue
        index += 1
    return False


def _ensure_mergeable_tables(data: dict[str, Any], text: str) -> None:
    if _contains_multiline_string(text):
        raise HerdrError("unsupported multiline TOML visual key: ambiguous TOML construct")
    headers, ordered = _tables(text)
    visual_sections = tuple(section for section, _ in _VISUAL_SECTIONS)
    for _, name, is_array in ordered:
        if is_array and any(
            name == section or name.startswith(section + ".")
            for section in visual_sections
        ):
            raise HerdrError(f"unsupported visual array-of-tables: {name}")
    for section, path in _VISUAL_SECTIONS:
        if section not in headers and _has(data, path) and not any(
            name.startswith(section + ".") for _, name, _ in ordered
        ):
            raise HerdrError(f"unsupported inline or dotted Herdr table: {section}")


def _merge_toml(text: str, values: dict[str, dict[str, Any]]) -> str:
    lines = text.splitlines(keepends=True)
    eol = next(
        ("\r\n" if line.endswith("\r\n") else "\n" for line in lines if line.endswith(("\n", "\r\n"))),
        "\n",
    )
    headers, ordered = _tables(text)
    additions: dict[int, list[str]] = {}
    replacements: dict[int, str] = {}

    def section_end(start: int) -> int:
        return next((index for index, _, _ in ordered if index > start), len(lines))

    def first_child(name: str) -> int | None:
        return next((index for index, section, _ in ordered if section.startswith(name + ".")), None)

    for section, wanted in values.items():
        start = headers.get(section)
        if start is None:
            insertion = first_child(section)
            insertion = len(lines) if insertion is None else insertion
            block = [f"[{section}]{eol}"]
            block.extend(f"{key} = {_literal(value)}{eol}" for key, value in wanted.items())
            if insertion == len(lines) and lines and not lines[-1].endswith(("\n", "\r")):
                block[0] = eol + block[0]
            additions.setdefault(insertion, []).extend(block)
            continue

        stop = section_end(start)
        found: set[str] = set()
        for index in range(start + 1, stop):
            content = lines[index].rstrip("\r\n")
            match = _ASSIGN.match(content)
            key = match.group("key").strip("\"'") if match else None
            if key not in wanted:
                continue
            value_start, value_end = _visual_value_span(content, match, section, key)
            replacements[index] = (
                content[:value_start]
                + _literal(wanted[key])
                + content[value_end:]
                + lines[index][len(content):]
            )
            found.add(key)

        missing = [key for key in wanted if key not in found]
        if missing:
            block = [f"{key} = {_literal(wanted[key])}{eol}" for key in missing]
            if stop == len(lines) and lines and not lines[-1].endswith(("\n", "\r")):
                block[0] = eol + block[0]
            additions.setdefault(stop, []).extend(block)

    return "".join(
        item
        for index in range(len(lines) + 1)
        for item in additions.get(index, [])
        + ([replacements.get(index, lines[index])] if index < len(lines) else [])
    )


def plan_visual_merge(
    source_data: bytes,
    target_data: bytes,
    *,
    source_label: str = "herdr/config.toml",
    target_label: str = ".config/herdr/config.toml",
) -> bytes:
    """Return target bytes with only approved Herdr visual values merged."""
    values = _visual_values(_parse_toml(source_data, source_label))
    current = _parse_toml(target_data, target_label)
    text = target_data.decode("utf-8")
    _ensure_mergeable_tables(current, text)
    if _visual_equal(current, values):
        return target_data

    planned = _merge_toml(text, values).encode("utf-8")
    if not _visual_equal(_parse_toml(planned, target_label), values):
        raise HerdrError("Herdr visual merge did not produce the requested values")
    return planned
