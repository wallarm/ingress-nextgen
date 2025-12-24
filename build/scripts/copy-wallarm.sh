#!/bin/sh
set -eu

TARGETS_MODULES="/usr/lib/nginx/modules"
TARGETS_PAGES="/usr/share/nginx/html"
TMP_TARGET_DIR="/tmp/opt/wallarm"

# New: Dynamically pick the proper module using the pick-module.sh script.
echo "Running dynamic module selection via pick-module.sh"
# Filter output so only valid module paths (starting with "modules/") are captured.
MODULE_REL_PATH=$(${TMP_TARGET_DIR}/pick-module.sh | grep '^modules/' | tail -n 1)
if [ -z "${MODULE_REL_PATH}" ]; then
  echo "Error: pick-module.sh did not return a module path." >&2
  exit 1
fi
MODULE_FULL_PATH="${TMP_TARGET_DIR}/${MODULE_REL_PATH}"
echo "Dynamic module selected: ${MODULE_FULL_PATH}"

mkdir -p "${TARGETS_MODULES}/libwallarm"
echo "Copying dynamic nginx module"
cp "${MODULE_FULL_PATH}" "${TARGETS_MODULES}/ngx_http_wallarm_module.so"
echo "Copying libwallarm"
ls -la ${TMP_TARGET_DIR}/modules/
cp -a ${TMP_TARGET_DIR}/modules/libwallarm.so* /usr/lib
cp -a ${TMP_TARGET_DIR}/modules/libwallarm.so* "${TARGETS_MODULES}/libwallarm"

mkdir -p "${TARGETS_PAGES}"
echo "Copy wallarm_blocked.html page"
cp "${TMP_TARGET_DIR}/usr/share/nginx/html/wallarm_blocked.html" "${TARGETS_PAGES}/wallarm_blocked.html"

# making sure signatures of nginx binary and our module match to avoid shipping broken installs, logic from AiO
NGX_VER=$(nginx -v 2>&1 | grep -o '[0-9.]*$')
NGX_SIG=$(grep -E -ao '.,.,.,[01]{33}' /usr/sbin/nginx)
MOD_VER=$(grep -ao -P '(nginx|openresty)\/\K\d+(\.\d+){2,}(?=( \(.*\)$|$))' "${TARGETS_MODULES}/ngx_http_wallarm_module.so")
MOD_SIG=$(grep -E -ao '.,.,.,[01]{33}' "${TARGETS_MODULES}/ngx_http_wallarm_module.so")
if [ "${NGX_VER}" == "${MOD_VER}" ] && [ "${NGX_SIG}" == "${MOD_SIG}" ]; then
  echo "OK! Version and signature of nginx module match expectations from version and signature of nginx binary found in the base image"
else
  echo "Failure! Version and signature of module: ${MOD_VER} / ${MOD_SIG}. Found in nginx binary: ${NGX_VER} / ${NGX_SIG}"
  exit 1
fi
