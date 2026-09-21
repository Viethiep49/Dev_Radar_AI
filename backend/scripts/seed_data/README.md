# Seed data

`repos.json` is read by `seed_repos()` in `scripts/seed.py` (`python -m scripts.seed`).

- ~30 real, well-known repositories (Flutter, Dart, AI/LLM, web, Python, devtools, database).
- **All numbers are approximate** (stars, forks, issues, dates, `stars_gained_30d`) and
  `github_id` values are **placeholders** (`9000000xx`), not the real GitHub ids.
- `readme` is a short hand-written summary (with an install/usage snippet), not the real README.
  It gives the AI summary feature something to work with offline.
- The seed also creates 30 days of synthetic star snapshots per repo (a straight line that gains
  `stars_gained_30d` stars and ends at `stars`), so the star chart and the "trending" sort work offline.

When the `fetch_trending` / `refresh_tracked` jobs run with Internet access, they overwrite these repos
with real GitHub data (matched by `full_name` because the ids differ). Running the seed again after that
keeps the real data and only adds missing snapshots.
