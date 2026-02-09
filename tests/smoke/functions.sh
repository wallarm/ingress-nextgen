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
    wstore_label="app.kubernetes.io/component=controller-wallarm-wstore"
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
    kubectl logs -l "app.kubernetes.io/component=controller" -c init --tail=-1
    echo -e "#################################\n"

    echo "#######################################"
    echo "###### Controller container logs ######"
    echo "#######################################"
    kubectl logs -l "app.kubernetes.io/component=controller" -c controller --tail=-1
    echo -e "#######################################\n"

    echo "#################################"
    echo "###### Wcli container logs ######"
    echo "#################################"
    kubectl logs -l "app.kubernetes.io/component=controller" -c wcli --tail=-1
    echo -e "#################################\n"

    echo "###################################"
    echo "###### API-WF container logs ######"
    echo "###################################"
    kubectl logs -l "app.kubernetes.io/component=controller" -c api-firewall --tail=-1 || true
    echo -e "####################################\n"

    export POD=$(kubectl get pod -l "app.kubernetes.io/component=controller" -o=name | cut -d/ -f 2)
    echo "####################################################"
    echo "###### List directory /opt/wallarm/etc/wallarm #####"
    echo "####################################################"
    kubectl exec "${POD}" -c controller -- sh -c "ls -laht /opt/wallarm/etc/wallarm && cat /opt/wallarm/etc/wallarm/node.yaml" || true
    echo -e "#####################################################\n"

    echo "############################################"
    echo "###### List directory /var/lib/nginx/wallarm"
    echo "############################################"
    kubectl exec "${POD}" -c controller -- sh -c "ls -laht /opt/wallarm/var/lib/nginx/wallarm && ls -laht /opt/wallarm/var/lib/nginx/wallarm/shm" || true
    echo -e "############################################\n"

    echo "############################################################"
    echo "###### List directory /opt/wallarm/var/lib/wallarm-acl #####"
    echo "############################################################"
    kubectl exec "${POD}" -c controller -- sh -c "ls -laht /opt/wallarm/var/lib/wallarm-acl" || true
    echo -e "############################################################\n"

    echo "##################################################"
    echo "###### WSTORE Pod - Wcli container logs  ######"
    echo "##################################################"
    kubectl logs -l "app.kubernetes.io/component=controller-wallarm-wstore" -c wcli --tail=-1
    echo -e "##################################################\n"

    echo "######################################################"
    echo "###### WSTORE Pod - Wstore container logs ######"
    echo "######################################################"
    kubectl logs -l "app.kubernetes.io/component=controller-wallarm-wstore" -c wstore --tail=-1
    echo -e "######################################################\n"
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
