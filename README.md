# github-stats

Generate GitHub statistics SVGs for your profile README — transparent background,
no light/dark mode hacks needed.

<div align="center">
  <img src="https://github.com/jstrieb/github-stats/blob/generated/overview.svg" />
  <img src="https://github.com/jstrieb/github-stats/blob/generated/languages.svg" />
</div>

## Quick Start

1. **Use this template** — [click here](https://github.com/jstrieb/github-stats/generate) to create your own copy.

2. **Create a personal access token (classic)** with `read:user` and `repo` scopes:
   [github.com/settings/tokens](https://github.com/settings/tokens)

3. **Add the token** as a repository secret named `ACCESS_TOKEN`:
   `Settings → Secrets and variables → Actions → New repository secret`

4. **Run the workflow** — go to `Actions → Generate Stats Images → Run workflow`

5. **Embed in your profile README** (replace `[USERNAME]`):
   ```markdown
   ![](https://github.com/[USERNAME]/github-stats/blob/generated/overview.svg)
   ![](https://github.com/[USERNAME]/github-stats/blob/generated/languages.svg)
   ```

   Images auto-refresh daily via GitHub Actions.

## What the SVGs Show

### Overview card
| Field | Description |
|-------|-------------|
| **Stars** | Total stars across all repos you own |
| **Forks** | Total forks across all repos you own |
| **PRs merged** | Total number of pull requests you authored that have been merged |
| **All-time contributions** | Sum of commits, issues, PRs, and reviews across your account history |
| **Repository views** | Total views on your repos over the past two weeks |
| **Repositories with contributions** | Number of distinct repositories you've contributed to (including repos you don't own) |

### Languages card
Shows language breakdown by file size across your owned repositories. Forks are excluded.

## Optional Configuration

Set these as repository secrets or variables:

| Secret/Variable | Purpose |
|-----------------|---------|
| `EXCLUDE_REPOS` | Comma-separated repos to exclude. Supports globs (e.g. `user/*`). Add your stats repo to hide it from results. |
| `EXCLUDE_LANGS` | Comma-separated languages to exclude (case-insensitive, e.g. `CSS, HTML`). |
| `EXCLUDE_PRIVATE` | Set to `true` to omit private repos from results. |
| `SILENT` | Set to `true` to suppress non-error log output. |

## Local Use

Download the binary from [releases](https://github.com/jstrieb/github-stats/releases/latest):

```bash
# Linux
sudo curl -Lo /usr/local/bin/github-stats \
  'https://github.com/jstrieb/github-stats/releases/latest/download/github-stats_x86_64-linux'
sudo chmod +x /usr/local/bin/github-stats

# Generate SVGs
github-stats --access-token YOUR_TOKEN

# Dump raw JSON for analysis
github-stats --access-token YOUR_TOKEN --json-output-file stats.json
```

Run `github-stats --help` for all options, including custom templates and output paths.

## License & Attribution

This project is a fork of [jstrieb/github-stats](https://github.com/jstrieb/github-stats) by [Jacob Strieb](https://jstrieb.github.io). Licensed under [GNU GPL v3](LICENSE).