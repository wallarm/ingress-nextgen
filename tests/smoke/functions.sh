# This file used for import in other files

RED='\033[0;31m'
NC='\033[0m'

function cleanup() {
  kind "export" logs --name ${KIND_CLUSTER_NAME} "./logs" || true
  tar czf kind_logs.tar.gz ./logs || true

  if [[ "${CI:-}" == "true" ]]; then
    kind delete cluster \
      --name ${KIND_CLUSTER_NAME}
  fi
}

function describe_pods_on_exit() {
    controller_label="app.kubernetes.io/component=controller"
    wstore_label="app.kubernetes.io/component=wallarm-postanalytics"
    workload_label="app=workload"

    echo "#################### Describe controller POD ####################"
    kubectl describe pod -l $controller_label
    echo "#################### Describe wstore POD ####################"
    kubectl describe pod -l $wstore_label
    echo "#################### Describe workload POD ####################"
    kubectl describe pod -l $workload_label
    get_logs
}

function clean_allure_report() {
  [[ "$ALLURE_GENERATE_REPORT" == false && -d "allure_report" ]] && rm -rf allure_report/* 2>/dev/null || true
}

function get_logs_and_fail() {
    get_logs
    extra_debug_logs
    clean_allure_report
    exit 1
}

function get_logs() {
    echo "#################################"
    echo "###### Init container logs ######"
    echo "#################################"
    kubectl logs -l "app.kubernetes.io/component=controller" -c wd-init --tail=-1
    echo -e "#################################\n"

    echo "#######################################"
    echo "###### Controller container logs ######"
    echo "#######################################"
    kubectl logs -l "app.kubernetes.io/component=controller" -c wallarm-ingress --tail=-1
    echo -e "#######################################\n"

    # wd runs api-firewall as a child process with tee_output, so its output
    # lands here rather than in a container of its own.
    echo "###############################"
    echo "###### wd container logs ######"
    echo "###############################"
    kubectl logs -l "app.kubernetes.io/component=controller" -c wd --tail=-1
    echo -e "###############################\n"

    export POD=$(kubectl get pod -l "app.kubernetes.io/component=controller" -o=name | cut -d/ -f 2)
    echo "####################################################"
    echo "###### List directory /opt/wallarm/etc/wallarm #####"
    echo "####################################################"
    kubectl exec "${POD}" -c wallarm-ingress -- sh -c "ls -laht /opt/wallarm/etc/wallarm && cat /opt/wallarm/etc/wallarm/node.yaml" || true
    echo -e "#####################################################\n"

    echo "############################################"
    echo "###### List directory /var/lib/nginx/wallarm"
    echo "############################################"
    kubectl exec "${POD}" -c wallarm-ingress -- sh -c "ls -laht /opt/wallarm/var/lib/nginx/wallarm && ls -laht /opt/wallarm/var/lib/nginx/wallarm/shm" || true
    echo -e "############################################\n"

    echo "############################################################"
    echo "###### List directory /opt/wallarm/var/lib/wallarm-acl #####"
    echo "############################################################"
    kubectl exec "${POD}" -c wallarm-ingress -- sh -c "ls -laht /opt/wallarm/var/lib/wallarm-acl" || true
    echo -e "############################################################\n"

    echo "############################################################"
    echo "###### Postanalytics Pod - init container logs        ######"
    echo "############################################################"
    kubectl logs -l "app.kubernetes.io/component=wallarm-postanalytics" -c wd-init --tail=-1
    echo -e "############################################################\n"

    # wstore and wcli are wd child processes in this pod, not containers.
    echo "############################################################"
    echo "###### Postanalytics Pod - wd container logs          ######"
    echo "############################################################"
    kubectl logs -l "app.kubernetes.io/component=wallarm-postanalytics" -c wd --tail=-1
    echo -e "############################################################\n"
}

function extra_debug_logs {
  echo "############################################"
  echo "###### Extra cluster debug info ############"
  echo "############################################"

  echo "Grepping cluster OOMKilled events..."
  kubectl get events -A | grep -i OOMKill || true

  echo "Displaying pods state in default namespace..."
  kubectl get pods

}
