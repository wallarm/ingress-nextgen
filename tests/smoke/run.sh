#!/bin/bash

if [[ -n "${DEBUG}" ]]; then
  set -x
  KIND_LOG_LEVEL="6"
  HELM_DEBUG="--debug"
fi

export KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-ingress-smoke-test}
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/kind-config-$KIND_CLUSTER_NAME}"
export KIND_LOG_LEVEL=${KIND_LOG_LEVEL:-1}

export WALLARM_API_HOST="${WALLARM_API_HOST:-api.wallarm.com}"
export WALLARM_API_CA_VERIFY="${WALLARM_API_CA_VERIFY:-true}"
export SMOKE_IMAGE_NAME="${SMOKE_IMAGE_NAME:-dkr.wallarm.com/tests/smoke-tests}"
export SMOKE_IMAGE_TAG="${SMOKE_IMAGE_TAG:-latest}"

export REGISTRY=${REGISTRY:-docker.io/wallarm}
export PREFIX=${PREFIX:-ingress-controller}
export TAG=${TAG:-$(cat TAG)}

export HELM_ARGS=${HELM_ARGS:-}

# This will prevent the secret for index.docker.io from being used if the DOCKERHUB_USER is not set.
DOCKERHUB_REGISTRY_SERVER="https://index.docker.io/v1/"

if [ "${DOCKERHUB_USER:-false}" = "false" ]; then
  DOCKERHUB_REGISTRY_SERVER="fake_docker_registry_server"
fi

DOCKERHUB_SECRET_NAME="dockerhub-secret"
CI_REGISTRY_SECRET_NAME="ci-registry-secret"
DOCKERHUB_USER="${DOCKERHUB_USER:-fake_user}"
DOCKERHUB_PASSWORD="${DOCKERHUB_PASSWORD:-fake_password}"

K8S_VERSION=${K8S_VERSION:-v1.30.13}
MODE=${MODE:-ingress}

set -euo pipefail

source "./tests/smoke/functions.sh"

trap cleanup EXIT ERR

# unique name for group, also handle local runs
export NODE_GROUP_NAME="gitlab-ingress-${MODE}-${CI_PIPELINE_ID:-local-$(id -un)}"

echo "[test-env] random node group name: ${NODE_GROUP_NAME}..."

# avoid auth through env var and sa token in ci
[[ "${CI:-}" == "true" ]] && unset KUBERNETES_SERVICE_HOST && docker pull -q ${REGISTRY}/${PREFIX}:${TAG}

# check kind availability for local runs
if ! command -v kind --version &> /dev/null; then
  echo "kind is not installed. Use the package manager or visit the official site https://kind.sigs.k8s.io/"
  exit 1
fi

if [[ -z "${NO_ALLURE:-}" ]]; then
  rm -rf ./allure_report || true
  mkdir ./allure_report || true
  KIND_CONFIG=$(cat <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: ${ALLURE_HOST_PATH:-./allure_report}
    containerPath: /allure_report
EOF
)
fi

rm -rf ./logs || true

echo "[test-env] creating kind cluster ..."
kind create cluster --name ${KIND_CLUSTER_NAME} --image "kindest/node:${K8S_VERSION}" --retain --config <(echo "$KIND_CONFIG")


echo "[test-env] creating secret docker-registry ..."
kubectl create secret docker-registry ${DOCKERHUB_SECRET_NAME} \
    --docker-server=${DOCKERHUB_REGISTRY_SERVER} \
    --docker-username="${DOCKERHUB_USER}" \
    --docker-password="${DOCKERHUB_PASSWORD}" \
    --docker-email=docker-pull@unexists.unexists || true

if [ "${SKIP_IMAGE_LOADING:-false}" = "false" ]; then
  echo "[test-env] copying ${REGISTRY}/${PREFIX}:${TAG} image to cluster..."
  kind load docker-image --name="${KIND_CLUSTER_NAME}" "${REGISTRY}/${PREFIX}:${TAG}"
fi

echo "[test-env] installing Helm chart using TAG=${TAG} ..."
cat << EOF | helm upgrade --install nginx-ingress ./charts/nginx-ingress ${HELM_DEBUG:-} --wait ${HELM_ARGS} --values -
controller:
  enableSnippets: true
  config:
    entries:
      real-ip-header: "X-Real-IP"
      real-ip-recursive: "True"
      set-real-ip-from: "0.0.0.0/0"
  service:
    type: NodePort
    httpPort:
      nodePort: 30000
config:
  wallarm:
    enabled: true
    api:
      host: $WALLARM_API_HOST
      token: $WALLARM_API_TOKEN
      ssl: $WALLARM_API_CA_VERIFY
      nodeGroup: $NODE_GROUP_NAME
      fallback: "off"
  images:
    controller:
      repository: ${REGISTRY}/${PREFIX}
      tag: $TAG
EOF
kubectl wait --for=condition=Ready pods --all --timeout=120s

echo "[test-env] Deploy workload and gun ..."
kubectl -n default apply -f ./tests/smoke/workload.yml
kubectl -n default apply -f ./tests/smoke/${MODE}.yml
kubectl -n default wait --for=condition=Ready pods --all --timeout=90s

make smoke-test
