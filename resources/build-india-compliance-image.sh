#!/usr/bin/env bash
# Build a layered Frappe image with ERPNext and India Compliance baked in.
# Usage:
#   ./resources/build-india-compliance-image.sh           # version-16 (matches images/layered/Containerfile default)
#   ./resources/build-india-compliance-image.sh 15      # version-15
# Env overrides:
#   FRAPPE_BRANCH=version-16  IMAGE_TAG=ic:16  APPS_JSON=/path/to/apps.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VER="${1:-16}"
case "${VER}" in
  15 | 16) ;;
  *)
    echo "Usage: $0 [15|16]" >&2
    exit 1
    ;;
esac

FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-${VER}}"
APPS_JSON="${APPS_JSON:-${SCRIPT_DIR}/apps-india-compliance-v${VER}.json}"
IMAGE_TAG="${IMAGE_TAG:-india-compliance:${VER}}"

if [[ ! -f "${APPS_JSON}" ]]; then
  echo "Missing apps file: ${APPS_JSON}" >&2
  exit 1
fi

export APPS_JSON_BASE64
APPS_JSON_BASE64="$(base64 -w 0 "${APPS_JSON}")"

cd "${REPO_ROOT}"

echo "Building ${IMAGE_TAG} with FRAPPE_BRANCH=${FRAPPE_BRANCH} (apps: ${APPS_JSON})"

docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH="${FRAPPE_BRANCH}" \
  --build-arg=APPS_JSON_BASE64="${APPS_JSON_BASE64}" \
  --tag="${IMAGE_TAG}" \
  --file=images/layered/Containerfile \
  .

echo
echo "Image ${IMAGE_TAG} built. In your .env set for example:"
echo "  CUSTOM_IMAGE=$(echo "${IMAGE_TAG}" | cut -d: -f1)"
echo "  CUSTOM_TAG=$(echo "${IMAGE_TAG}" | cut -d: -f2-)"
echo "  PULL_POLICY=missing"
echo
echo "After the stack is up, create a site and install apps on it, e.g.:"
echo "  bench new-site ... --install-app erpnext"
echo "  bench --site <sitename> install-app india_compliance"
