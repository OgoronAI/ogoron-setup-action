#!/usr/bin/env bash
set -euo pipefail

git config user.name "${INPUT_AUTHOR_NAME:-ogoron-bot}"
git config user.email "${INPUT_AUTHOR_EMAIL:-agents@ogoron.com}"

committed_changes="false"

commit_if_changes() {
  local message="$1"
  if [[ -z "$(git status --porcelain)" ]]; then
    return 1
  fi

  git add -A
  git commit -m "${message}" >/dev/null
  committed_changes="true"
  return 0
}

run_best_effort() {
  local status_var="$1"
  local log_var="$2"
  shift 2

  local log_file
  log_file="$(mktemp "${RUNNER_TEMP:-/tmp}/ogoron-setup-phase-XXXXXX.log")"
  local exit_code=0

  set +e
  "$@" 2>&1 | tee "${log_file}"
  exit_code=${PIPESTATUS[0]}
  set -e

  printf -v "${log_var}" '%s' "${log_file}"
  if [[ ${exit_code} -eq 0 ]]; then
    printf -v "${status_var}" '%s' "success"
  else
    printf -v "${status_var}" '%s' "failed"
  fi
}

render_status_line() {
  local label="$1"
  local status="$2"
  case "${status}" in
    success) echo "- ${label}: success" ;;
    failed) echo "- ${label}: failed (kept as partial success)" ;;
    included-in-analyze) echo "- ${label}: included in \`ogoron analyze business\`" ;;
    skipped) echo "- ${label}: skipped" ;;
    *)
      echo "- ${label}: ${status}"
      ;;
  esac
}

render_failure_excerpt() {
  local title="$1"
  local status="$2"
  local log_file="$3"

  if [[ "${status}" != "failed" || -z "${log_file}" || ! -f "${log_file}" ]]; then
    return
  fi

  echo
  echo "### ${title} failure excerpt"
  echo
  echo '```text'
  tail -n 20 "${log_file}"
  echo '```'
}

bootstrap_mode="upgraded"
if [[ ! -d ".ogoron" && ! -d ".ai-agents" ]]; then
  bootstrap_mode="initialized"
  "${OGORON_BIN}" init --target-repo-path .
  commit_if_changes "Initialize Ogoron repository artifacts" || true
else
  "${OGORON_BIN}" upgrade --target-repo-path .
  commit_if_changes "Upgrade Ogoron repository artifacts" || true
fi

analyze_business="${INPUT_ANALYZE_BUSINESS:-true}"
prepare_ui_workspace="${INPUT_PREPARE_UI_WORKSPACE:-true}"
analyze_status="skipped"
ui_workspace_status="skipped"
analyze_log_file=""
ui_workspace_log_file=""

if [[ "${analyze_business}" == "true" ]]; then
  run_best_effort analyze_status analyze_log_file "${OGORON_BIN}" analyze business
  if commit_if_changes "Add Ogoron business analysis artifacts"; then
    :
  fi
fi

if [[ "${prepare_ui_workspace}" == "true" ]]; then
  if [[ "${analyze_business}" == "true" && "${analyze_status}" == "success" ]]; then
    ui_workspace_status="included-in-analyze"
  else
    run_best_effort \
      ui_workspace_status \
      ui_workspace_log_file \
      "${OGORON_BIN}" \
      prepare \
      ui-workspace \
      --bootstrap-runtime \
      --smoke-check
    if commit_if_changes "Add Ogoron UI workspace scaffold"; then
      :
    fi
  fi
fi

pr_body_path="${RUNNER_TEMP:-/tmp}/ogoron-setup-pr-body.md"
cat > "${pr_body_path}" <<EOF
## What Ogoron changed

This PR bootstraps Ogoron in this repository so future Ogoron workflows can run against committed repository artifacts instead of ephemeral CI state.

The action ran:

$(if [[ "${bootstrap_mode}" == "initialized" ]]; then echo "- \`ogoron init --target-repo-path .\`"; else echo "- \`ogoron upgrade --target-repo-path .\`"; fi)
$(if [[ "${analyze_business}" == "true" ]]; then echo "- \`ogoron analyze business\`"; fi)
$(if [[ "${prepare_ui_workspace}" == "true" && "${ui_workspace_status}" != "included-in-analyze" ]]; then echo "- \`ogoron prepare ui-workspace --bootstrap-runtime --smoke-check\`"; fi)

## Phase status

$(render_status_line "Bootstrap" "success")
$(render_status_line "Analyze business" "${analyze_status}")
$(render_status_line "Prepare UI workspace" "${ui_workspace_status}")

## What was generated or updated

- \`.ogoron/\`: Ogoron repository state and generated artifacts
- \`.ogoron/configs/config.yml\`: repository-specific Ogoron configuration
- \`.ogoron/configs/test_execution.yml\`: test execution commands and profiles
- \`.ogoron/configs/version.yml\`: Ogoron artifact schema/version tracking
- \`.ogoron/.gitignore\`: ignore rules for generated internal Ogoron files
- \`.ogoronignore\`: repository paths Ogoron should ignore while analyzing and generating
$(if [[ "${analyze_business}" == "true" ]]; then echo "- \`.ogoron/for-human/\`: generated business/domain analysis artifacts"; fi)
$(if [[ "${prepare_ui_workspace}" == "true" ]]; then cat <<'WORKSPACE'
- `.ogoron/tests/`: Python UI workspace scaffold managed by Ogoron
  - `conftest.py`
  - `ogoron_ui/...`
  - `tests/ui/...`
WORKSPACE
fi)

## What you should review before merge

Please review and adapt these files to your repository:

1. \`.ogoron/configs/config.yml\`
   - repository-specific paths
   - stack and runtime assumptions
   - generation and repository behavior toggles
2. \`.ogoron/configs/test_execution.yml\`
   - test commands
   - execution profiles
   - CI/runtime expectations
3. \`.ogoronignore\`
   - repository-specific ignore rules for Ogoron processing
$(if [[ "${analyze_business}" == "true" ]]; then cat <<'ANALYZE'
4. `.ogoron/for-human/`
   - review the generated business understanding before building more flows on top of it
ANALYZE
fi)
$(if [[ "${prepare_ui_workspace}" == "true" ]]; then cat <<'UI'
5. `.ogoron/tests/`
   - verify the generated UI workspace scaffold matches your stack and runtime expectations
   - adjust env/bootstrap assumptions before extending generated UI flows
UI
fi)

## What to configure after merge

1. Configure \`OGORON_REPO_TOKEN\` in GitHub Actions and in any local shell where you run Ogoron.
2. If your organization uses BYOK access, also configure \`OGORON_LLM_API_KEY\`.
3. Adjust \`.ogoron/configs/config.yml\`, \`.ogoron/configs/test_execution.yml\`, and \`.ogoronignore\` to match this repository.
4. After merge, start with a narrow workflow such as setup refinement, targeted test execution, or feature-scoped generation.

## Documentation to read next

- Installation: https://docs.ogoron.ai/getting-started/installation/
- Quickstart: https://docs.ogoron.ai/getting-started/quickstart/
- CLI overview: https://docs.ogoron.ai/cli/overview/
- \`ogoron init\`: https://docs.ogoron.ai/cli/init/
- \`ogoron upgrade\`: https://docs.ogoron.ai/cli/upgrade/
- Configuration overview: https://docs.ogoron.ai/configuration/overview/
$(render_failure_excerpt "Analyze business" "${analyze_status}" "${analyze_log_file}")
$(render_failure_excerpt "Prepare UI workspace" "${ui_workspace_status}" "${ui_workspace_log_file}")
EOF

changes_detected="false"
if [[ "${committed_changes}" == "true" || -n "$(git status --porcelain)" ]]; then
  changes_detected="true"
fi

{
  echo "bootstrap-mode=${bootstrap_mode}"
  echo "changes-detected=${changes_detected}"
  echo "analyze-status=${analyze_status}"
  echo "ui-workspace-status=${ui_workspace_status}"
  echo "pr-body-path=${pr_body_path}"
} >> "${GITHUB_OUTPUT}"
