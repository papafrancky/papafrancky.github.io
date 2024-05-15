# 'kube-prometheus-stack' managed with FluxCD

----------------------------------------------------------------------------------------------------
## Abstract

Ce howto fait suite au hoxto _*'FluxCD / FluxCD - Démonstration par l'exemple'*_.

Il décrit comment déployer via FluxCD le Helm Chart 'kube-prometheus-stack' qui vise à installer un monitoring de notre cluster Kubernetes reposant sur Prometheus / Alert manager et Grafana.

|Doc|URL|
|---|---|
|artifacthub.io|https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack|
|GitHub|https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack|



----------------------------------------------------------------------------------------------------
## Préparatifs

Préparons notre environnement local :

```sh
# Répertoire accueillant nos dépôts Git en local
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

# Mise à jour des copies locales des dépôts dédiés à FluxCD et aux applications qu'il gère
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-apps   && git pull
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd && git pull

# Création d'un répertoire dédié au monitoring
mkdir -p ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring
```

Créons ensuite un namesapce dédié au monitoring :

```sh
kubectl create ns monitoring --dry-run=client -o yaml > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/namespace.yaml
kubectl apply -f ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/namespace.yaml
```


----------------------------------------------------------------------------------------------------
## Helm Repository

Nous pouvons désormais définir auprès de FluxCD le HelmRepository qui nous intéresse :

=== "code"
    ```sh
    flux create source helm prometheus-community \
      --url=https://prometheus-community.github.io/helm-charts \
      --namespace=monitoring \
      --interval=1m \
      --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/helm-repository.yaml
    ```

=== "output"
    ```sh
    ---
    apiVersion: source.toolkit.fluxcd.io/v1beta2
    kind: HelmRepository
    metadata:
      name: prometheus-community
      namespace: monitoring
    spec:
      interval: 1m0s
      url: https://prometheus-community.github.io/helm-charts
    ```

Poussons nos modifications sur notre dépôt GitHub pour que FluxCD les prenne en compte :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    git add .
    git commit -m "feat: Defining a namespace + a Helm repository for Prometheus."
    git push
    
    flux reconcile kustomization flux-system --with-source
    
    kubectl -n monitoring get helmrepository
    ```

=== "output"
    ```sh
    NAME                   URL                                                  AGE   READY   STATUS
    prometheus-community   https://prometheus-community.github.io/helm-charts   37s   True    stored artifact: revision 'sha256:8d880a1010d4ba3df22364b59881e235590c184266f0c9fb894eeedb23442b12'
    ```



----------------------------------------------------------------------------------------------------
## Helm Release

Création d'un répertoire non géré par FluxCD pour y placer un éventuel fichier values.yaml pour notre HelmRelease :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    # création d'un répertoire non géré par FluxCD pour y placer un éventuel fichier values.yaml pour notre HelmRelease
    mkdir -p ~/helmrelease_values/kube-prometheus-stack
    
    # Définition de la Helm Release
    flux create helmrelease kube-prometheus-stack \
      --source=HelmRepository/prometheus-community \
      --chart=kube-prometheus-stack \
      --namespace=monitoring \
      --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/helm-release.yaml
      #--values=~/helmrelease_values/kube-prometheus-stack/values.yaml \
    ```

=== "output"
    ```sh
    ---
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: kube-prometheus-stack
      namespace: monitoring
    spec:
      chart:
        spec:
          chart: kube-prometheus-stack
          reconcileStrategy: ChartVersion
          sourceRef:
            kind: HelmRepository
            name: prometheus-community
      interval: 1m0s
    ```

Poussons nos modifications sur notre dépôt GitHub pour que FluxCD les prenne en compte :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    git add .
    git commit -m "feat: Defining a kube-prometheus-stack Helm release."
    git push
    
    flux reconcile kustomization flux-system --with-source
    
    kubectl -n monitoring get helmrelease
    ```

=== "output"
    ```sh
    NAME                    AGE   READY   STATUS
    kube-prometheus-stack   93s   True    Release reconciliation succeeded
    ```

Vérifions ce qui a été déployé sur le cluster :

=== "code"
    ```sh
    kubetl -n monitoring get all
    ```

=== "output"
    ```sh
    NAME                                                            READY   STATUS    RESTARTS   AGE
    pod/alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running   0          118s
    pod/kube-prometheus-stack-grafana-7cf5785ff8-qp5xf              3/3     Running   0          2m10s
    pod/kube-prometheus-stack-kube-state-metrics-65594f9476-8tpcv   1/1     Running   0          2m10s
    pod/kube-prometheus-stack-operator-6459f9c556-67dvk             1/1     Running   0          2m10s
    pod/kube-prometheus-stack-prometheus-node-exporter-qkjzz        1/1     Running   0          2m10s
    pod/prometheus-kube-prometheus-stack-prometheus-0               2/2     Running   0          118s
    
    NAME                                                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
    service/alertmanager-operated                            ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP   118s
    service/kube-prometheus-stack-alertmanager               ClusterIP   10.96.133.65    <none>        9093/TCP,8080/TCP            2m10s
    service/kube-prometheus-stack-grafana                    ClusterIP   10.96.203.186   <none>        80/TCP                       2m10s
    service/kube-prometheus-stack-kube-state-metrics         ClusterIP   10.96.22.99     <none>        8080/TCP                     2m10s
    service/kube-prometheus-stack-operator                   ClusterIP   10.96.18.86     <none>        443/TCP                      2m10s
    service/kube-prometheus-stack-prometheus                 ClusterIP   10.96.60.161    <none>        9090/TCP,8080/TCP            2m10s
    service/kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.96.92.181    <none>        9100/TCP                     2m10s
    service/prometheus-operated                              ClusterIP   None            <none>        9090/TCP                     118s
    
    NAME                                                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
    daemonset.apps/kube-prometheus-stack-prometheus-node-exporter   1         1         1       1            1           kubernetes.io/os=linux   2m10s
    
    NAME                                                       READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/kube-prometheus-stack-grafana              1/1     1            1           2m10s
    deployment.apps/kube-prometheus-stack-kube-state-metrics   1/1     1            1           2m10s
    deployment.apps/kube-prometheus-stack-operator             1/1     1            1           2m10s
    
    NAME                                                                  DESIRED   CURRENT   READY   AGE
    replicaset.apps/kube-prometheus-stack-grafana-7cf5785ff8              1         1         1       2m10s
    replicaset.apps/kube-prometheus-stack-kube-state-metrics-65594f9476   1         1         1       2m10s
    replicaset.apps/kube-prometheus-stack-operator-6459f9c556             1         1         1       2m10s
    
    NAME                                                               READY   AGE
    statefulset.apps/alertmanager-kube-prometheus-stack-alertmanager   1/1     118s
    statefulset.apps/prometheus-kube-prometheus-stack-prometheus       1/1     118s
    ```

-----
TODO : 

* alerting Discord
* accéder à Prometheus, Alert Manager, Grafana
* Se poser la question de protéger les secrets avec Vault

