#!/usr/bin/env python3
import json
import pathlib
import re
import sys

CATALOG_PATH = pathlib.Path(__file__).parents[1] / "Wiseish" / "WiseishShared" / "quotes.json"
MOODS = {"quiet", "foggy", "thinking"}
TAGS = {"work", "information", "rest", "relationship", "money", "creative", "daily"}
VOICE_MARKERS = ("じゃ", "かの", "わし", "たぶん", "知らん", "ぬ", "おる", "がの")


def fail(message: str) -> None:
    print(f"catalog error: {message}", file=sys.stderr)
    raise SystemExit(1)


with CATALOG_PATH.open(encoding="utf-8") as file:
    catalog = json.load(file)

if catalog.get("schemaVersion") != 1:
    fail("schemaVersion must be 1")
if not re.fullmatch(r"\d{4}-\d{2}-\d{2}\.\d+", catalog.get("catalogVersion", "")):
    fail("catalogVersion must use YYYY-MM-DD.N format")

quotes = catalog.get("quotes")
if not isinstance(quotes, list) or not 1 <= len(quotes) <= 500:
    fail("quotes must contain between 1 and 500 items")

ids: set[str] = set()
unknown_keys = set()
required = {"id", "mood", "text", "reflection", "theme", "aside", "tags", "isPremium"}
for index, quote in enumerate(quotes):
    missing = required - quote.keys()
    if missing:
        fail(f"item {index} is missing {sorted(missing)}")

    quote_id = quote["id"]
    if quote_id in ids:
        fail(f"duplicate id: {quote_id}")
    ids.add(quote_id)

    if quote["mood"] not in MOODS:
        fail(f"{quote_id}: unknown mood {quote['mood']}")
    if not quote["tags"] or not set(quote["tags"]) <= TAGS:
        fail(f"{quote_id}: invalid tags")
    if not isinstance(quote["isPremium"], bool):
        fail(f"{quote_id}: isPremium must be boolean")

    text = quote["text"]
    compact_length = len("".join(text.split()))
    line_count = len(text.splitlines())
    if not 12 <= compact_length <= 80:
        fail(f"{quote_id}: text length must be 12...80")
    if not 2 <= line_count <= 3:
        fail(f"{quote_id}: text must have 2...3 lines")
    if "." in text or "," in text:
        fail(f"{quote_id}: use Japanese punctuation")
    if not any(marker in text + quote["aside"] for marker in VOICE_MARKERS):
        fail(f"{quote_id}: Ish voice marker is missing")
    for field in ("reflection", "theme", "aside"):
        if not isinstance(quote[field], str) or not quote[field].strip():
            fail(f"{quote_id}: {field} is required")

unknown_keys = set().union(*(set(quote.keys()) - required for quote in quotes))
if unknown_keys:
    fail(f"unknown quote fields: {sorted(unknown_keys)}")

unknown_rate = sum("知らんけどの。" in quote["text"] + quote["aside"] for quote in quotes) / len(quotes)
if unknown_rate > 0.2:
    fail("『知らんけどの。』must stay at or below 20%")

for mood in MOODS:
    if not any(quote["mood"] == mood for quote in quotes):
        fail(f"no quotes for mood: {mood}")

print(f"catalog ok: {len(quotes)} quotes, version {catalog['catalogVersion']}")
