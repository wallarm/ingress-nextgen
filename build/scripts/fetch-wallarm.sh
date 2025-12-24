#!/bin/bash

set -e
set -x

TMP_TARGET_DIR="/tmp/opt/wallarm"
AIO_BASE=$(cat AIO_BASE)

# Use pre-set variable (e.g. from upstream), or rely on the version from text file instead when not set
AIO_VERSION=${AIO_VERSION:-$AIO_BASE}
[ "${TARGETARCH}" == "amd64" ] && AIO_ARCH=x86_64 || AIO_ARCH=aarch64
AIO_FILE="wallarm-${AIO_VERSION}.${AIO_ARCH}-musl.sh"
AIO_URL="https://storage.googleapis.com/meganode_storage/${AIO_VERSION%.*}/${AIO_FILE}"

if ! test -f "${AIO_FILE}"; then
  echo "Downloading AIO archive (${TARGETARCH}/${AIO_ARCH})"
  curl -L -C - -o "${AIO_FILE}" "${AIO_URL}"
  chmod +x "${AIO_FILE}"
fi

echo "Extracting AIO to (${TMP_TARGET_DIR})"
sh -c "./${AIO_FILE} --noexec --target ${TMP_TARGET_DIR}"

echo "Overriding pick-module.sh with custom version from repository"
mv pick-module.sh "${TMP_TARGET_DIR}/pick-module.sh"
chmod +x "${TMP_TARGET_DIR}/pick-module.sh"
