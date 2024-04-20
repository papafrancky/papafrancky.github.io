# Minikube et l'ingress Nginx sur macOS

Déploiement d'un cluster Minikube sur MacOS avec un Ingress Nginx et exposition d'un application de démo.
 

## Docs

|Liens utiles|
|---|
|[le tuto d'origine (kubernetes.io)](https://kubernetes.io/docs/tasks/access-application-cluster/ingress-minikube/)|
|[all GKE code samples](https://cloud.google.com/kubernetes-engine/docs/samples?hl=en)|
|[hello-app source code](https://cloud.google.com/kubernetes-engine/docs/samples/container-hello-app?_gl=1*194jebn*_ga*MjAxNDQ5NjcxNi4xNjk2NTM2NjU4*_ga_WH2QY8WWF5*MTcxMTc5NjM4OC4xNy4xLjE3MTE3OTY3NTkuMC4wLjA.&_ga=2.93273374.-2014496716.1696536658&hl=en)|
|[hello-app image on Google Container Registry (GCR)](https://console.cloud.google.com/gcr/images/google-samples/global/hello-app)|
|[cURL : provide a custom IP adress for a name](https://everything.curl.dev/usingcurl/connections/name.html)|
|[Docker & Kubernetes : Setting up Ingress with NGINX Controller on Minikube (Mac)](https://www.bogotobogo.com/DevOps/Docker/Docker_Kubernetes_Nginx_Ingress_Controller_2.php)|
|[Minikube - accessing apps](https://minikube.sigs.k8s.io/docs/handbook/accessing/)|
|[minikube tunnel](https://minikube.sigs.k8s.io/docs/commands/tunnel/)|
|[Kubernetes documentation - networking - ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)|


## Pré-requis

### installation de kubectl, kubens, kubectx, ...
Se reporter aux autres docs, ok ? ^^


### Installation et démarrage de minikube avec Nginx comme ingress

```sh title="Minikube install with nginx ingress controller"
brew update && brew install minikube
minikube start
minikube status
minikube addons list
minikube addons enable ingress
k get po -n ingress-nginx
```

## Démo

### Déploiement et exposition d'une 'dummy app'

L'application 'hello-app' affiche dans une page web le nom de l'application, sa version ainsi que le pod dans lequel elle tourne.


```sh title="Déploiement d'une 'dummy app'"
    # Déploiement de l'application à la version 1 :
    kubectl create deployment web --image=gcr.io/google-samples/hello-app:1.0 --dry-run=client -o yaml > web.deployment.yaml
    kubectl apply -f web.deployment.yaml

    # Vérification de son bon fonctionnement et de son port d'écoute :
    podName=$( kubectl -n default get pod -l app=web -o json | jq -r '.items[].metadata.name' )
    kubectl -n default logs ${podName}
    
        # 2024/03/30 14:46:46 Server listening on port 8080


    # Exposition de l'application :
    kubectl expose deployment web --type=NodePort --port=8080 --dry-run=client -o yaml > web.service.yaml

    kubectl -n default get service web

        # NAME   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
        # web    NodePort   10.98.252.182   <none>        8080:32002/TCP   109s


    # Accès à l'application :
    
      - via le port-forwarding :

        kubetl port-forward service/web 8080:8080 &
        curl http://localhost:8080

      - via le NodePort :

        minikube service web    # Renvoie une URL pour se connecter à un service (de type NodePort)

          # |-----------|------|-------------|---------------------------|
          # | NAMESPACE | NAME | TARGET PORT |            URL            |
          # |-----------|------|-------------|---------------------------|
          # | default   | web  |        8080 | http://192.168.49.2:32002 |
          # |-----------|------|-------------|---------------------------|
          # 🏃  Tunnel de démarrage pour le service web.
          # |-----------|------|-------------|------------------------|
          # | NAMESPACE | NAME | TARGET PORT |          URL           |
          # |-----------|------|-------------|------------------------|
          # | default   | web  |             | http://127.0.0.1:54247 |
          # |-----------|------|-------------|------------------------|
          # 🎉  Ouverture du service default/web dans le navigateur par défaut...
          # ❗  Comme vous utilisez un pilote Docker sur darwin, le terminal doit être ouvert pour l'exécuter.
```

C'est très bien, ça fonctionne, mais ce n'est pas ce qu'on veut faire : on veut passer par un service de type Load-Balancer en renseignant un FQDN et nom une IP et un port TCP.


### Définition d'un Ingress Controller pour notre 'ummy app'

    cat << EOF >> web.ingress.yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: web
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      rules:
        - host: hello-world.info
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: web
                    port:
                      number: 8080
    EOF

    kubectl -n default apply -f web.ingress.yaml
    kubectl -n default get ingress web

        # NAME   CLASS   HOSTS              ADDRESS        PORTS   AGE
        # web    nginx   hello-world.info   192.168.49.2   80      10s

__Note__ : l'adresse IP renvoyée correspond ici à celle de minikube (qu'on peut obtenir avec la commande: "minikube ip")

Sur un Mac, il n'est pas posible d'utiliser un service NodePort directement à cause de la façon dont la couche réseau de Docker est implémentée. Nous devons utiliser un moyen de contournement :  *__minikube tunnel__*.

La commande *'minikube tunnel'* crée une route vers les services déployés avec le type LoadBalancer et définit leur Ingress à leur ClusterIP.
Dans un nouveau terminal, exécuter la commande suivante sans l'interrompre :

    sudo minikube tunnel    # sudo est nécessaire car on vise des ports réservés (<1024)

#### Accès à l'application avec cURL

    curl --Header "Host: hello-world.info" http://localhost/


#### Accès à l'application avec un navigateur

Il faudra modifier l'entrée localhost dans /etc/hosts :
127.0.0.1	localhost hello-world.info
Ensuite il suffira d'accéder à l'URL : 

    http://hello-world.info/


### Déploiement d'une seconde application

Pour aller plus loin, nous allons crér un second deployment de la même 'dummy app', mais à la version 2 et l'exposer ensuite :

    kubectl create deployment web2 --image=gcr.io/google-samples/hello-app:2.0 --dry-run=client -o yaml > web2.deployment.yaml
    kubectl apply -f web2.deployment.yaml

    kubectl expose deployment web2 --port=8080 --type=NodePort --dry-run=client -o yaml > web2.service.yaml
    kubectl apply -f web2.service.yaml
    
    kubectl -n default get pods,deployments,services

Nous allons compléter le manifest de notre Ingress controller :

    cat << EOF >> web.ingress.yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: web
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      rules:
        - host: hello-world.info
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: web
                    port:
                      number: 8080
              - path: /v2
                pathType: Prefix
                backend:
                  service:
                    name: web2
                    port:
                      number: 8080
    EOF

    kubectl -n default apply -f web.ingress.yaml
    kubectl -n default get ingress web


#### Accès aux 2 applications 

Pour tester, il suffit d'accéder à partir d'un navigateur ou de cURL aux URLs suivantes :

    * http://hello-world.info/      # avec cURL : curl --Header "Host: hello-world.info" http://localhost/
    * http://hello-world.info/v2    # avec cURL : curl --Header "Host: hello-world.info" http://localhost/v2

Et voilà ^^


### Modification du routage : chaque application aura son propre FQDN

Nous souhaitons désormais rendre accessible :
* web  via l'URL hello-world.info;
* web2 via l'URL hello-world-2.info.

#### Modification de l'Ingress Resource

    kubectl delete ingress web

    cat << EOF >> web2.ingress.yaml 
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: web2
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      rules:
        - host: hello-world.info
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: web
                    port:
                      number: 8080
        - host: hello-world-2.info
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: web2
                    port:
                      number: 8080
    EOF

    kubectl apply -f web2.ingress.yaml
    kubect ldescribe ingress web2

#### Tests

    curl --header "Host: hello-world.info" http://127.0.0.1/

    # Hello, world!
    # Version: 1.0.0
    # Hostname: web-57f46db77f-r2rtc


    curl --header "Host: hello-world-2.info" http://127.0.0.1/

      # Hello, world!
      # Version: 2.0.0
      # Hostname: web2-866dc4bcc8-52xjp

Via le navigateur, il faut avant tout modifier l'entrée du fichier /etc/hosts pour que 127.0.0.1 renvoie vers hello-world.info et hello-world-2.info.


## Nettoyage

* Arrêter minikube tunnel et fermer son terminal;

* Supprimer l'*Ingress controller*, les *services* et les *deployments* :

      kubectl -n default delete ingress web
      kubectl -n default delete services web web2
      kubectl -n default delete deployments web web2

* Vérifier que nous n'avons rien oublié:

      kubectl -n default get pods,deployments,services,ingress

* Arrêter le cluster minikube :

      minikube stop
      minikube status