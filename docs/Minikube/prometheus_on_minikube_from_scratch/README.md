# Prometheus on MiniKube from scratch
Creating and publishing an Alpine+Prometheus image on Docker Hub and deploying the Prometheus service on MiniKube 

Prerequisite : MiniKube already installed, up and running

|USEFUL PAGES|URL|
|---|---|
|RBAC Prometheus|https://github.com/prometheus-operator/prometheus-operator/tree/main/example/rbac/prometheus|
|RBAC ClusterRole|https://kubernetes.io/docs/reference/access-authn-authz/rbac/#kubectl-create-clusterrole|
|How to Install Prometheus on Kubernetes and Use It for Monitoring|https://phoenixnap.com/kb/prometheus-kubernetes|
|MiniKube - persistent volumes|https://minikube.sigs.k8s.io/docs/handbook/persistent_volumes/|
|Kubernetes persistent volumes|https://spacelift.io/blog/kubernetes-persistent-volumes|

## Retrieving the Prometheus Helm Chart locally

    helm pull prometheus-community/prometheus --untar

## Docker image

    docker build -t <my_docker_username>/prometheus:2.48.1 -t <my_docker_username>/prometheus:latest .
    docker login --username <my_docker_username> --password <my_docker_password>
    docker push zigouigoui/prometheus:2.48.1
    docker push zigouigoui/prometheus:latest

## Prometheus service on MiniKube

    manifestsList=( monitoring.namespace.yaml
                    prometheus.service-account.yaml
                    prometheus.cluster-role.yaml
                    prometheus.cluster-role-binding.yaml
                    prometheus.configmap.yaml
                    prometheus.persistent-volume.data.yaml
                    prometheus.persistent-volume.logs.yaml
                    prometheus.persistent-volume-claim.data.yaml
                    prometheus.persistent-volume-claim.logs.yaml
                    prometheus.deployment.yaml
                    prometheus.service.yaml )
    
    for manifest in ${manifestsList[@]}; do 
        echo "kubectl apply -f ${manifest}"
    done


## Accessing the WUI

    kubectl port-forward service/prometheus 8080:9090

-> browser : http://localhost:8080 -> Prometheus WUI
