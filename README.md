
# github-stats-transparent

Generate clean, transparent GitHub statistics cards for your profile README.

<div align="center">
  <img src="https://raw.githubusercontent.com/dynow/github-stats-transparent/generated/overview.svg" alt="Overview Stats" width="48%" />
  <img src="https://raw.githubusercontent.com/dynow/github-stats-transparent/generated/languages.svg" alt="Top Languages" width="48%" />
</div>

---

## Quick Start

1. **Create your repository:** [Use this template](https://github.com/dynow/github-stats-transparent/generate) to make your own copy.
2. **Generate a token:** Create a [Personal Access Token (classic)](https://github.com/settings/tokens) with `read:user` and `repo` scopes.
3. **Save secret:** Navigate to **Settings → Secrets and variables → Actions → New repository secret**, name it `ACCESS_TOKEN`, and paste your token value.
4. **Trigger generation:** Go to **Actions → Generate Stats Images → Run workflow** (runs automatically daily afterward).
5. **Embed in your README:** Add the following Markdown snippet (replace `[USERNAME]` with your GitHub username):

```markdown
<p align="center">
  <img src="https://raw.githubusercontent.com/[USERNAME]/github-stats-transparent/generated/overview.svg" alt="GitHub Overview Stats" />
  <img src="https://raw.githubusercontent.com/[USERNAME]/github-stats-transparent/generated/languages.svg" alt="Top Languages" />
</p>
```

---

## Metrics Breakdown

### Overview Card

| Metric | Source |
| --- | --- |
| **Stars** | Total stars across all owned repositories |
| **Forks** | Total forks across all owned repositories |
| **PRs Merged** | Pull requests authored by you that have been merged |
| **All-Time Contributions** | Combined total of commits, issues, PRs, and code reviews |
| **Repository Views** | Aggregate visitor views on your repositories over the past 14 days |
| **Active Repositories** | Distinct repositories you have contributed to (including third-party repos) |

### Languages Card

Visualizes language distribution by file size across all owned public repositories (forks are automatically excluded).

---

## Configuration

Customize generation behavior by adding optional **Repository Secrets** or **Variables** in your repository settings:

| Variable | Description | Example |
| --- | --- | --- |
| `EXCLUDE_REPOS` | Comma-separated list/globs of repositories to ignore | `user/stats, user/*-archive` |
| `EXCLUDE_LANGS` | Comma-separated list of languages to exclude (case-insensitive) | `HTML, CSS, SCSS` |
| `EXCLUDE_PRIVATE` | Omit private repository activity from data aggregation | `false` |
| `SILENT` | Suppress standard informational log output | `true` |

---

## CLI & Local Usage

Pre-compiled standalone binaries are available on the [Releases page](https://github.com/dynow/github-stats-transparent/releases/latest).

```bash
# Install binary (Linux x86_64)
sudo curl -Lo /usr/local/bin/github-stats https://github.com/dynow/github-stats-transparent/releases/latest/download/github-stats_x86_64-linux'
sudo chmod +x /usr/local/bin/github-stats

# Generate SVGs
github-stats --access-token YOUR_ACCESS_TOKEN

# Or generate SVGs and also export raw JSON data
github-stats --access-token YOUR_ACCESS_TOKEN --json-output-file stats.json

```

Run `github-stats --help` to inspect additional flags, custom SVG templates, and custom file output paths.

---

## License & Credits

* Forked from [jstrieb/github-stats](https://github.com/jstrieb/github-stats) by [Jacob Strieb](https://jstrieb.github.io).
* Distributed under the [GNU GPL v3 License](https://www.google.com/search?q=LICENSE).
