# Ogoron Setup Action

Bootstrap or migrate Ogoron in a repository and deliver the result through a pull request.

This action is intentionally opinionated:
- downloads a released Linux Ogoron bundle;
- initializes `.ogoron/` when missing;
- upgrades existing Ogoron artifacts when present;
- runs `ogoron analyze business` by default;
- prepares the Ogoron UI workspace by default;
- creates or updates a pull request with the resulting changes.

Current scope:
- `ubuntu-*` runners only
- Linux release assets only
- intended for manual `workflow_dispatch` bootstrap or migration flows

## Required environment

Provide secrets via workflow `env`, not via action inputs.

- `GITHUB_TOKEN`
- `OGORON_REPO_TOKEN`
- `OGORON_LLM_API_KEY` when BYOK access is required

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `working-directory` | no | `.` | Repository directory where Ogoron runs. |
| `cli-version` | no | `5.2.0` | Ogoron CLI release version to download. Versions older than `5.2.0` are rejected. |
| `download-url` | no |  | Explicit Linux bundle URL override. Useful for prereleases or mirrors. |
| `analyze-business` | no | `true` | Run `ogoron analyze business` after init/upgrade. |
| `prepare-ui-workspace` | no | `true` | Prepare the Ogoron UI workspace after bootstrap. When analyze succeeds, this is treated as already included by the current CLI. |
| `create-pr` | no | `true` | Create or update a PR when changes are detected. |
| `pr-branch` | no | `ogoron/setup` | Branch used for bootstrap changes. |
| `pr-title` | no | `Set up Ogoron in this repository` | Pull request title. |
| `commit-message` | no | `Initialize or upgrade Ogoron repository artifacts` | Commit message used for the PR branch. |
| `author-name` | no | `ogoron-bot` | Git author name for the generated commit. |
| `author-email` | no | `agents@ogoron.com` | Git author email for the generated commit. |

## Outputs

| Output | Description |
| --- | --- |
| `ogoron-bin` | Absolute path to the downloaded Ogoron executable. |
| `changes-detected` | Whether Ogoron changed repository files. |
| `bootstrap-mode` | `initialized` or `upgraded`. |
| `analyze-status` | `success`, `failed`, or `skipped`. |
| `ui-workspace-status` | `success`, `failed`, `included-in-analyze`, or `skipped`. |
| `pr-body-path` | Path to the generated PR body file used by the action. |
| `pull-request-url` | URL of the created or updated pull request, if any. |
| `branch-name` | Branch name used for bootstrap changes. |

## Example

```yaml
name: Ogoron Setup

on:
  workflow_dispatch:

jobs:
  setup-ogoron:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Ogoron
        uses: OgoronAI/ogoron-setup-action@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          OGORON_REPO_TOKEN: ${{ secrets.OGORON_REPO_TOKEN }}
          OGORON_LLM_API_KEY: ${{ secrets.OGORON_LLM_API_KEY }}
```

## Notes

- This action is meant for repository bootstrap and migration, not for every CI run.
- It does not commit directly to the default branch.
- When no repository changes are produced, no PR is created.
- The current minimum supported Ogoron CLI version for this action is `5.2.0`.

## Related actions

- [`Ogoron Generate`](https://github.com/OgoronAI/ogoron-generate-action) to create unit, API, and UI artifacts after bootstrap
- [`Ogoron Run`](https://github.com/OgoronAI/ogoron-run-action) to execute generated or project tests in CI
- [`Ogoron Heal`](https://github.com/OgoronAI/ogoron-heal-action) to repair failing generated or project tests
- [`Ogoron Exec`](https://github.com/OgoronAI/ogoron-exec-action) as a low-level escape hatch for custom workflows

## Recommended flow

1. Run `setup` manually to bootstrap `.ogoron/` in the repository.
2. Review and merge the generated bootstrap PR.
3. Add `generate` for feature-scoped artifact creation.
4. Add `run` to CI for execution.
5. Add `heal` later for recovery workflows.
