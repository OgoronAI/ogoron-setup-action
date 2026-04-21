#!/usr/bin/env bash
set -euo pipefail

minimum_supported_version="5.2.0"
version="${INPUT_CLI_VERSION#v}"
tag="v${version}"
asset_url="${INPUT_DOWNLOAD_URL:-}"
if [[ -z "${asset_url}" ]]; then
  asset_url="https://github.com/OgoronAI/releases/releases/download/${tag}/ogoron-linux-amd64.tar.gz"
fi

if [[ "$(printf '%s\n' "${minimum_supported_version}" "${version}" | sort -V | head -n1)" != "${minimum_supported_version}" ]]; then
  echo "Unsupported Ogoron CLI version: ${version}" >&2
  echo "This action supports Ogoron CLI versions >= ${minimum_supported_version}." >&2
  exit 1
fi

install_root="${RUNNER_TEMP}/ogoron"
archive_path="${RUNNER_TEMP}/ogoron-linux-amd64.tar.gz"

rm -rf "${install_root}"
mkdir -p "${install_root}"

curl --fail --location --silent --show-error "${asset_url}" --output "${archive_path}"
tar -xzf "${archive_path}" -C "${install_root}"

ogoron_bin="${install_root}/runtime/ogoron-nuitka"
chmod +x "${ogoron_bin}"
ln -sf "ogoron-nuitka" "${install_root}/runtime/ogoron"

{
  echo "${install_root}/runtime"
} >> "${GITHUB_PATH}"

{
  echo "ogoron-bin=${ogoron_bin}"
} >> "${GITHUB_OUTPUT}"
