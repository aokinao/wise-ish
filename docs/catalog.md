# Quote catalog operations

The single source of truth is `Wiseish/WiseishShared/quotes.json`.

## Add or remove a quote

1. Edit `quotes.json` on a branch.
2. Increase the sortable `catalogVersion`, for example from `2026-08-24.1` to `2026-08-24.2`.
3. Run `python3 scripts/validate_catalog.py`.
4. Open a pull request and merge it into `main` after review.
5. GitHub Actions publishes the validated file to GitHub Pages.

The app checks `https://aokinao.github.io/wise-ish/quotes.json` at most once per day. A valid new version is saved in the App Group container and shared with the widget. If the network or validation fails, the last valid cache or bundled catalog remains active.

## First-time GitHub setup

In the repository settings, open **Pages** and set **Source** to **GitHub Actions**. No API key is required.

## Safety limits

- Schema version must be `1`.
- Catalog size is capped at 500 quotes and 512 KB.
- IDs must be unique.
- Only known moods and tags are accepted.
- Seasonal quotes can use `activeMonths` with month numbers from `1` through `12`.
- Text is data only; executable code and remote prompt instructions are not supported.
