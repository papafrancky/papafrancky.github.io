# Prometheus & Grafana on Kubernetes

Ce howto explique comment déployer Prometheus et Grafana avec Helm.


## Ajout des *Helm repositories*

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts

helm repo list

  # NAME                	URL
  # prometheus-community	https://prometheus-community.github.io/helm-charts
  # grafana             	https://grafana.github.io/helm-charts


helm repo update

  # Hang tight while we grab the latest from your chart repositories...
  # ...Successfully got an update from the "grafana" chart repository
  # ...Successfully got an update from the "prometheus-community" chart repository
  # Update Complete. ⎈Happy Helming!⎈
```


## Prometheus


### Installation du serveur

```sh
# Installation de Prometheus
helm install prometheus prometheus-community/prometheus

  NAME: prometheus
  LAST DEPLOYED: Sat Dec  9 13:26:23 2023
  NAMESPACE: default
  STATUS: deployed
  REVISION: 1
  TEST SUITE: None
  NOTES:
  The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
  prometheus-server.default.svc.cluster.local
  

# Obtention de l'URL du serveur Prometheus
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=prometheus,app.kubernetes. instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward ${POD_NAME} 9090


# Obtention de l'URL de l'Alert Manager  
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=alertmanager,app.kubernetes. instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward ${POD_NAME} 9093


# Obtention de l'URL de la Push Gateway  
export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus-pushgateway,component=pushgateway"-ojsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9091
```


### Vérification de l'installation

```sh
kubectl get all

  NAME                                                     READY   STATUS    RESTARTS   AGE
  pod/prometheus-alertmanager-0                            1/1     Running   0          9m44s
  pod/prometheus-kube-state-metrics-85596bfdb6-6r4pp       1/1     Running   0          9m44s
  pod/prometheus-prometheus-node-exporter-w5skp            1/1     Running   0          9m44s
  pod/prometheus-prometheus-pushgateway-79745d4495-dh8cv   1/1     Running   0          9m44s
  pod/prometheus-server-fd677cd4c-5sc5x                    2/2     Running   0          9m44s
  
  NAME                                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
  service/kubernetes                            ClusterIP   10.96.0.1       <none>        443/TCP    44m
  service/prometheus-alertmanager               ClusterIP   10.96.135.67    <none>        9093/TCP   9m44s
  service/prometheus-alertmanager-headless      ClusterIP   None            <none>        9093/TCP   9m44s
  service/prometheus-kube-state-metrics         ClusterIP   10.96.78.11     <none>        8080/TCP   9m44s
  service/prometheus-prometheus-node-exporter   ClusterIP   10.96.170.181   <none>        9100/TCP   9m44s
  service/prometheus-prometheus-pushgateway     ClusterIP   10.96.148.56    <none>        9091/TCP   9m44s
  service/prometheus-server                     ClusterIP   10.96.118.59    <none>        80/TCP     9m44s  
  NAME                                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
  daemonset.apps/prometheus-prometheus-node-exporter   1         1         1       1            1           kubernetes.io/os=linux   9m44s  
  NAME                                                READY   UP-TO-DATE   AVAILABLE   AGE
  deployment.apps/prometheus-kube-state-metrics       1/1     1            1           9m44s
  deployment.apps/prometheus-prometheus-pushgateway   1/1     1            1           9m44s
  deployment.apps/prometheus-server                   1/1     1            1           9m44s  
  NAME                                                           DESIRED   CURRENT   READY   AGE
  replicaset.apps/prometheus-kube-state-metrics-85596bfdb6       1         1         1       9m44s
  replicaset.apps/prometheus-prometheus-pushgateway-79745d4495   1         1         1       9m44s
  replicaset.apps/prometheus-server-fd677cd4c                    1         1         1       9m44s  
  NAME                                       READY   AGE
  statefulset.apps/prometheus-alertmanager   1/1     9m44s

```

### Port-forwarding (tcp/9090)

```sh
Prometheus port-forwarding on port 9090
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9090 &
```

-> Prometheus est accessible à l'adresse suivante : http://localhost:9090 !



## Grafana


### Installation

```sh
helm install grafana grafana/grafana

  NAME: grafana
  LAST DEPLOYED: Sat Dec  9 14:46:26 2023
  NAMESPACE: default
  STATUS: deployed
  REVISION: 1
  NOTES:
  1. Get your 'admin' user password by running:  
     kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
    
  2. The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:
     grafana.default.svc.cluster.local
  
     Get the Grafana URL to visit by running these commands in the same shell:
       export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadataname}")
       kubectl --namespace default port-forward $POD_NAME 3000
  
  3. Login with the password from step 1 and the username: admin
  #################################################################################
  ######   WARNING: Persistence is disabled!!! You will lose your data when   #####
  ######            the Grafana pod is terminated.                            #####
  #################################################################################
```

### Port-forwarding (tcp/3000)

```sh
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 3000 &
```

-> Grafana est accessible à l'URL suivante : http://localhost:3000

!!! tip
    Admin password : kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo 




# WORK IN PROGRESS


    helm show chart prometheus-community/prometheus
    
    # annotations:
    #   artifacthub.io/license: Apache-2.0
    #   artifacthub.io/links: |
    #     - name: Chart Source
    #       url: https://github.com/prometheus-community/helm-charts
    #     - name: Upstream Project
    #       url: https://github.com/prometheus/prometheus
    # apiVersion: v2
    # appVersion: v2.48.0
    # dependencies:
    # - condition: alertmanager.enabled
    #   name: alertmanager
    #   repository: https://prometheus-community.github.io/helm-charts
    #   version: 1.7.*
    # - condition: kube-state-metrics.enabled
    #   name: kube-state-metrics
    #   repository: https://prometheus-community.github.io/helm-charts
    #   version: 5.15.*
    # - condition: prometheus-node-exporter.enabled
    #   name: prometheus-node-exporter
    #   repository: https://prometheus-community.github.io/helm-charts
    #   version: 4.24.*
    # - condition: prometheus-pushgateway.enabled
    #   name: prometheus-pushgateway
    #   repository: https://prometheus-community.github.io/helm-charts
    #   version: 2.4.*
    # description: Prometheus is a monitoring system and time series database.
    # home: https://prometheus.io/
    # icon: https://raw.githubusercontent.com/prometheus/prometheus.github.io/master/assets/prometheus_logo-cb55bb5c346.png
    # keywords:
    # - monitoring
    # - prometheus
    # kubeVersion: '>=1.19.0-0'
    # maintainers:
    # - email: gianrubio@gmail.com
    #   name: gianrubio
    # - email: zanhsieh@gmail.com
    #   name: zanhsieh
    # - email: miroslav.hadzhiev@gmail.com
    #   name: Xtigyro
    # - email: naseem@transit.app
    #   name: naseemkullah
    # - email: rootsandtrees@posteo.de
    #   name: zeritti
    # name: prometheus
    # sources:
    # - https://github.com/prometheus/alertmanager
    # - https://github.com/prometheus/prometheus
    # - https://github.com/prometheus/pushgateway
    # - https://github.com/prometheus/node_exporter
    # - https://github.com/kubernetes/kube-state-metrics
    # type: application
    # version: 25.8.1

    # To unsinstall Prometheus
    helm uninstall prometheus

    # To get the default helm configuration :
    helm show values prometheus-community/prometheus > helm_values.prometheus.yaml.ORIG
    cp helm_values.prometheus.yaml.ORIG helm_values.prometheus.yaml

    # To install Prometheus with the default configuration :
    helm install prometheus prometheus-community/prometheus

    # To install Prometheus with a custom configuration :
    helm install prometheus prometheus-community/prometheus -f helm_values.prometheus.yaml

    # To upgrade an already installed Prometheus with a custom configuration :
    helm upgrade prometheus prometheus-community/prometheus -f helm_values.prometheus.yaml


    helm history prometheus                                                                                               1 ✘    kind-sandbox ⎈  16:47:23 
    # REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION
    # 1       	Sat Dec  9 16:34:59 2023	superseded	prometheus-25.8.1	v2.48.0    	Install complete
    # 2       	Sat Dec  9 16:46:39 2023	deployed  	prometheus-25.8.1	v2.48.0    	Upgrade complete

    helm rollback prometheus 1

## Customiser un Helm Chart à partir des fichiers source

### Chart download locally

    helm pull prometheus-community/prometheus --untar

### Install a Chart from local files

    helm install prometheus --dry-run ./prometheus -f helm_values.prometheus.yaml

### blah blah blah
k exec -it prometheus-server-fd677cd4c-7t8b8 -- sh
ps
/bin/prometheus-config-reloader --watched-dir=/etc/config --reload-url=http://127.0.0.1:9090/-/reload



## Cours Helm sur Pluralsight




### Pour tester les helms :

    helm template [chart] (works 'offline', without kubernetes)
    helm install [release] [chart] --dry-run --debug 2>&1       (real helm install but without commit)
    helm get all [release] -> compiles all the values
