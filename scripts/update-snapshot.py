#!/usr/bin/env python3
"""Refresh Shared/rates-snapshot.json, the rates Pocket ships with.

Run it before tagging a release so a fresh install starts with recent rates:

    python3 scripts/update-snapshot.py

It downloads today's USD table from fawazahmed0/currency-api (CC0), keeps only
the currencies listed in Shared/CurrencyCatalog.swift, and writes Pocket's
snapshot format. Standard library only.
"""
import datetime
import json
import pathlib
import re
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Shared" / "CurrencyCatalog.swift"
SNAPSHOT = ROOT / "Shared" / "rates-snapshot.json"
URLS = [
    "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json",
    "https://latest.currency-api.pages.dev/v1/currencies/usd.min.json",
]


def fetch():
    last = None
    for url in URLS:
        try:
            with urllib.request.urlopen(url, timeout=20) as response:
                return json.load(response)
        except Exception as error:  # try the mirror
            last = error
    raise SystemExit(f"Could not download rates: {last}")


def main():
    codes = set(re.findall(r'code: "([A-Z]{3})"', CATALOG.read_text()))
    payload = fetch()
    rates = {k.upper(): v for k, v in payload["usd"].items() if k.upper() in codes and v > 0}
    rates["USD"] = 1.0
    missing = sorted(codes - rates.keys())
    snapshot = {
        "base": "USD",
        "date": payload["date"],
        "fetchedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": "fawazahmed0/currency-api",
        "rates": dict(sorted(rates.items())),
    }
    SNAPSHOT.write_text(json.dumps(snapshot, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {len(rates)} rates for {payload['date']} to {SNAPSHOT.relative_to(ROOT)}")
    if missing:
        print(f"Not in today's table (kept out of the snapshot): {', '.join(missing)}")


if __name__ == "__main__":
    main()
