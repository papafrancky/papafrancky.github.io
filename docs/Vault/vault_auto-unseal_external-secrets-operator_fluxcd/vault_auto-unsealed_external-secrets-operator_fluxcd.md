# Déploiement de Vault (auto-unsealed) et External Secrets Operator via FluxCD

## Abstract

Ce howto fait suite au howto ['FluxCD / FluxCD - Démonstration par l'exemple](https://papafrancky.github.io/FluxCD/FluxCD_demonstration_par_l_exemple/).

Jusqu'à présent, nous disposons d'un cluster Kubernetes piloté par FluxCD et sur lequel nous avons déployé deux applications : 

* '**agnhost**', dont le code source est accessible depuis un dépôt Git (GitHub dans notre cas);
* '**podinfo**', application packagée avec *Helm* et que nous avons récupérée directement depuis sont dépôt *Helm* (ou '*Helm Repository*').
  
Ces applications sont monitorées via '*Discord*', une messagerie instantanée, qui nous alerte lorsqu'une modification est apportée aux applications.

Pour déployer nos applications, nous avons dû définir des '*secrets*' sur notre cluster Kubernetes. Pour des raisons évidentes de sécurité, nous ne les avons pas écrits dans notre code pour qu'ils ne se retrouvent pas sur nos dépôts Git.

Le présent HOWTO décrit la mise en place d'un coffre ('**HashiCorp Vault**') dans lequel nous placerons nos '*secrets*', et installerons également '**External Secrets Operator**' (ou '**ESO**') pour interagir avec ce dernier depuis les namespaces Kubernetes.

!!! Doc
    Vault - [https://developer.hashicorp.com/vault](https://developer.hashicorp.com/vault)

    External Secrets Operator - [https://external-secrets.io/latest/](https://external-secrets.io/latest/)


## Mode opératoire

Nous commencerons par préparer notre environnement local, un namespace dédié à '*Vault*' et un autre à '*External Secrets Operator*'; puis nous mettrons l'alerting '*Discord*' en place, avant de déployer les 2 composants depuis leurs '*Helm Repositories*' respectifs avec une configuration adaptée à notre besoin.


## Préparation de notre environnement de développement (local)

```sh
# Répertoire accueillant nos dépôts Git en local
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

# Mise à jour des copies locales des dépôts dédiés à FluxCD et aux applications qu'il gère
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-apps   && git pull
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd && git pull

# Création d'un répertoire dédié à la gestion des secrets
mkdir -p ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault
mkdir -p ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/external-secrets

```



## Namespaces dédiés à Vault et External-Secrets Operator (ESO)

```sh
kubectl create ns vault --dry-run=client -o yaml > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault/vault.namespace.yaml
kubectl create ns external-secrets --dry-run=client -o yaml > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/external-secrets/external-secrets.namespace.yaml

kubectl apply -f ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault/vault.namespace.yaml
kubectl apply -f ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/external-secrets/external-secrets.namespace.yaml
```


## Alerting Discord

Nous passerons vite sur cette partie, car nous l'avons déjà bien documentée [dans le HOWTO précédent](https://papafrancky.github.io/FluxCD/FluxCD_demonstration_par_l_exemple/#creation-dun-channel-dans-notre-serveur-discord).

Nous utiliserons notre serveur Discord _*'k8s'*_ déjà existant et créerons pour **Vault** et pour **External Secrets** leur propre '*channel*' ainsi qu'un '*webhook*' associé.

![Vault and External Secrets Operator new Discord channels](./images/discord_vault_and_external-secrets_channels.png)

|Discord Channel|WebHook URL|
|---|---|
|vault|https://discord.com/api/webhooks/1426889931195813968/5IuDXdjRNlpmaszWgRxHt4-P1QottSfWgFdg9bmuTSbwuquRpDZNus1U0AvRMyp26VMu|
|external-secrets|https://discord.com/api/webhooks/1426890931122208919/_isXhWPYEX1b2l_ST80xwUAuofsrPyWBUns5MyMkfXBKcsg_aK2Ay2Qtmbg0wU5Xe1Et|


### Définition des webhooks des *channels* Discord '*vault*' et '*external-secrets*'

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    export WEBHOOK_VAULT="https://discord.com/api/webhooks/1426889931195813968/5IuDXdjRNlpmaszWgRxHt4-P1QottSfWgFdg9bmuTSbwuquRpDZNus1U0AvRMyp26VMu"
    export WEBHOOK_EXTERNAL_SECRETS="https://discord.com/api/webhooks/1426890931122208919/_isXhWPYEX1b2l_ST80xwUAuofsrPyWBUns5=MyMkfXBKcsg_aK2Ay2Qtmbg0wU5Xe1Et"
    
    kubectl -n vault            create secret generic discord-webhook --from-literal=address=${WEBHOOK_VAULT}
    kubectl -n external-secrets create secret generic discord-webhook --from-literal=address=${WEBHOOK_EXTERNAL_SECRETS} 
    ```

=== "vault"
    ```yaml
    apiVersion: v1
    data:
      address: aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQyNjg4OTkzMTE5NTgxMzk2OC81SXVEWGRqUk5scG1hc3pXZ1J4SHQ0LVAxUW90dFNmV2dGZGc5Ym11VFNid3VxdVJwRFpOdXMxVTBBdlJNeXAyNlZNdQ==
    kind: Secret
    metadata:
      creationTimestamp: "2025-10-12T11:40:41Z"
      name: discord-webhook
      namespace: vault
      resourceVersion: "472479"
      uid: 3fcebb03-80a6-4edd-abf6-b9c41d8657da
    type: Opaque
    ```

=== "external-secrets"
    ```yaml
    apiVersion: v1
    data:
      address: aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQyNjg5MDkzMTEyMjIwODkxOS9faXNYaFdQWUVYMWIybF9TVDgweHdVQXVvZnNyUHlXQlVuczU9TXlNa2ZYQktjc2dfYUsyQXkyUXRtYmcwd1U1WGUxRXQ=
    kind: Secret
    metadata:
      creationTimestamp: "2025-10-12T11:40:41Z"
      name: discord-webhook
      namespace: external-secrets
      resourceVersion: "472480"
      uid: f16617d0-129b-4ce5-b0f4-a4bc084f223f
    type: Opaque
    ```



### Discord notification provider

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    flux create alert-provider discord \
      --type=discord \
      --secret-ref=discord-webhook \
      --channel=vault \
      --username=FluxCD \
      --namespace=vault \
      --export > apps/vault/discord.notification-provider.yaml

    flux create alert-provider discord \
      --type=discord \
      --secret-ref=discord-webhook \
      --channel=external-secrets \
      --username=FluxCD \
      --namespace=external-secrets \
      --export > apps/external-secrets/discord.notification-provider.yaml
    ```

=== "vault"
    ```yaml
    ---
    apiVersion: notification.toolkit.fluxcd.io/v1beta3
    kind: Provider
    metadata:
      name: discord
      namespace: vault
    spec:
      channel: vault
      secretRef:
        name: discord-webhook
      type: discord
      username: FluxCD
    ```

=== "external-secrets"
    ```yaml
    ---
    apiVersion: notification.toolkit.fluxcd.io/v1beta3
    kind: Provider
    metadata:
      name: discord
      namespace: external-secrets
    spec:
      channel: external-secrets
      secretRef:
        name: discord-webhook
      type: discord
      username: FluxCD
    ```


### Discord alert

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    flux create alert discord \
      --event-severity=info \
      --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*,HelmRelease/*' \
      --provider-ref=discord \
      --namespace=vault \
      --export > apps/vault/discord.notification-alert.yaml

    flux create alert discord \
      --event-severity=info \
      --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*,HelmRelease/*' \
      --provider-ref=discord \
      --namespace=external-secrets \
      --export > apps/external-secrets/discord.notification-alert.yaml
    ```

=== "vault"
    ```yaml
    ---
    apiVersion: notification.toolkit.fluxcd.io/v1beta2
    kind: Alert
    metadata:
      name: discord
      namespace: vault
    spec:
      eventSeverity: info
      eventSources:
      - kind: GitRepository
        name: '*'
      - kind: Kustomization
        name: '*'
      - kind: ImageRepository
        name: '*'
      - kind: ImagePolicy
        name: '*'
      - kind: HelmRepository
        name: '*'
      - kind: HelmRelease
        name: '*'
      providerRef:
        name: discord
    ```

=== "external-secrets"
    ```yaml
    ---
    apiVersion: notification.toolkit.fluxcd.io/v1beta3
    kind: Alert
    metadata:
      name: discord
      namespace: external-secrets
    spec:
      eventSeverity: info
      eventSources:
      - kind: GitRepository
        name: '*'
      - kind: Kustomization
        name: '*'
      - kind: ImageRepository
        name: '*'
      - kind: ImagePolicy
        name: '*'
      - kind: HelmRepository
        name: '*'
      - kind: HelmRelease
        name: '*'
      providerRef:
        name: discord
    ```


### Activation de l'alerting

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: setting up 'vault' and 'external secrets' Discord alerting."
git push

flux reconcile kustomization flux-system --with-source
```

Vérification :

=== "code"
    ```sh
    kubectl -n vault            get providers,alerts
    kubectl -n external-secrets get providers,alerts
    ```

=== "namespace 'vault'"
    ```sh
    NAME                                              AGE
    provider.notification.toolkit.fluxcd.io/discord   2m49s

    NAME                                           AGE
    alert.notification.toolkit.fluxcd.io/discord   2m49s
    ```

=== "namespace 'external-secrets'"
    ```sh
    NAME                                              AGE
    provider.notification.toolkit.fluxcd.io/discord   2m49s

    NAME                                           AGE
    alert.notification.toolkit.fluxcd.io/discord   2m49s
    ```


## Helm repositories

!!! Doc
    Vault helm chart - [https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm)

    External secrets operator - [https://external-secrets.io/latest/introduction/getting-started/#installing-with-helm](https://external-secrets.io/latest/introduction/getting-started/#installing-with-helm)

Nous allons définir au niveau de FluxCD les _*'Helm registries'*_ pour installer sur notre cluster l'**External Secrets Operator** et **HashiCorp Vault OSS** :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    flux create source helm hashicorp \
      --url=https://helm.releases.hashicorp.com \
      --namespace=vault \
      --interval=1m \
      --export > apps/vault/hashicorp.helmrepository.yaml

    flux create source helm external-secrets \
      --url=https://charts.external-secrets.io \
      --namespace=external-secrets \
      --interval=1m \
      --export > apps/external-secrets/external-secrets.helmrepository.yaml

    git add .
    git commit -m "feat: Defined 'hashicorp' and 'external-secrets' helm repositories." 
    git push

    flux reconcile kustomization flux-system --with-source
    ```

=== "'hashicorp' helm repository"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: HelmRepository
    metadata:
      name: hashicorp
      namespace: vault
    spec:
      interval: 1m0s
      url: https://helm.releases.hashicorp.com
    ```

=== "'external-secrets' helm repository"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: HelmRepository
    metadata:
      name: external-secrets
      namespace: externel-secrets
    spec:
      interval: 1m0s
      url: https://charts.external-secrets.io
    ```


Discord nous informe tout de suite de la bonne création des _*'Helm registries'*_ :

![Hashicorp HelmRepository creation alert](./images/alert_hashicorp_helmrepository_creation.png)

![External-secrets HelmRepository creation alert](./images/alert_external-secrets_helmrepository_creation.png)



## Déploiement de l'**External Secrets Operator (ESO)**

!!! Doc
    [https://external-secrets.io/latest/introduction/overview/](https://external-secrets.io/latest/introduction/overview/)

La solution fonctionne '*as-is*' : il n'est pas nécessaire de personnaliser la configuration de l'opérateur.

Nous allons donc nous contenter de définir dans le dépôt GitHub que nous avons dédié à nos applications (`k8s-kind-apps`) une **Helm Release** depuis la *Helm Chart* '*external-secrets*' sans '*custom values*'.


### Le GitRepository dédié aux applications

Commençons par définir le dépôt Git où nous définirons notre Helm Release.

#### Création et installation de la '**Deploy Key**'

Pour accéder à notre **GitRepository**, nous devons nous authentifier.

=== "code"
    ```sh
    export GITHUB_USERNAME=papafrancky

    flux create secret git k8s-kind-apps-gitrepository-deploykeys \
      --url=ssh://github.com/${GITHUB_USERNAME}/k8s-kind-apps \
      --namespace=external-secrets
    
    kubectl -n external-secrets get secret k8s-kind-apps-gitrepository-deploykeys -o yaml
    ```

=== "output"
    ```yaml
    apiVersion: v1
    data:
      identity: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JRzJBZ0VBTUJBR0J5cUdTTTQ5QWdFR0JTdUJCQUFpQklHZU1JR2JBZ0VCQkREdnlWSWRMWjNlamYvTHBPb1AKdnVrbVp4Uzg3ZG15dFROaFV0MDFoTUlTU29KVHJseW94TjNKdndTUnJkY2VRdjZoWkFOaUFBUUwvYlB5SGhYRApmVElKSkR4OEZKTXhSMG5aNDRuU091a25lWEtWUUZWRVlobFBYVHB0Wm80SzR1MDl0UysvSHZVT0FUdG8rTkM2CklzWDNMLzJQazVieFdXZlVSRHFRWWtOcElPekpwcG1lMUJLZ2Z2cklpaEJCSEFpY2NHWGRpdVE9Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
      identity.pub: ZWNkc2Etc2hhMi1uaXN0cDM4NCBBQUFBRTJWalpITmhMWE5vWVRJdGJtbHpkSEF6T0RRQUFBQUlibWx6ZEhBek9EUUFBQUJoQkF2OXMvSWVGY045TWdra1BId1VrekZIU2RuamlkSTY2U2Q1Y3BWQVZVUmlHVTlkT20xbWpncmk3VDIxTDc4ZTlRNEJPMmo0MExvaXhmY3YvWStUbHZGWlo5UkVPcEJpUTJrZzdNbW1tWjdVRXFCKytzaUtFRUVjQ0p4d1pkMks1QT09Cg==
      known_hosts: Z2l0aHViLmNvbSBlY2RzYS1zaGEyLW5pc3RwMjU2IEFBQUFFMlZqWkhOaExYTm9ZVEl0Ym1semRIQXlOVFlBQUFBSWJtbHpkSEF5TlRZQUFBQkJCRW1LU0VOalFFZXpPbXhrWk15N29wS2d3RkI5bmt0NVlScllNak51RzVOODd1UmdnNkNMcmJvNXdBZFQveTZ2MG1LVjBVMncwV1oyWUIvKytUcG9ja2c9
    kind: Secret
    metadata:
      creationTimestamp: "2025-10-12T17:10:52Z"
      name: k8s-kind-apps-gitrepository-deploykeys
      namespace: external-secrets
      resourceVersion: "486819"
      uid: 632669dc-9f66-4876-bc67-ece788d3ca55
    type: Opaque
    ```

Nous devons déployer la **Deploy Key** (ie. la clé publique du jeu de clés que nous venons de créer) sur notre dépôt GitHub '*k8s-kind-apps*'.

Commençons par récupérer notre clé publique depuis le *secret* que nous venons de créer : 

=== "code"
    ```sh
    kubectl -n external-secrets get secret k8s-kind-apps-gitrepository-deploykeys -o jsonpath='{.data.identity\.pub}' | base64 -D
    ```

=== "output"
    ```yaml
    ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBAv9s/IeFcN9MgkkPHwUkzFHSdnjidI66Sd5cpVAVURiGU9dOm1mjgri7T21L78e9Q4BO2j40Loixfcv/Y+TlvFZZ9REOpBiQ2kg7MmmmZ7UEqB++siKEEEcCJxwZd2K5A==
    ```

Intégrons-la enfin sur le dépôt GitHub dédié à nos applications :

![External-secrets Deploy Key](./images/external-secrets_deploy_key.png)

![External-secrets Deploy Key](./images/external-secrets_deploy_key.2.png)




#### Définition du GitRepository

Nous avons défini la '**Deploy Key**', nous pouvons désormais définir le dépôt Git :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    export GITHUB_USERNAME=papafrancky

    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

    flux create source git k8s-kind-apps \
      --url=ssh://git@github.com/${GITHUB_USERNAME}/k8s-kind-apps.git \
      --branch=main \
      --secret-ref=k8s-kind-apps-gitrepository-deploykeys \
      --namespace=external-secrets \
      --export > apps/external-secrets/k8s-kind-apps.gitrepository.yaml
    ```

=== "'k8s-kind-apps' GitRepository"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: k8s-kind-apps
      namespace: external-secrets
    spec:
      interval: 1m0s
      ref:
        branch: main
      secretRef:
        name: k8s-kind-apps-gitrepository-deploykeys
      url: ssh://git@github.com/papafrancky/k8s-kind-apps.git
    ```


### La **Kustomization** 'external-secrets'

Nous devons demander à FluxCD de surveiller le sous-répertoire que nous dédierons à l'**External Secrets Operator** sur le dépôt GitHub dédié aux applications :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

    flux create kustomization external-secrets \
      --source=GitRepository/k8s-kind-apps.external-secrets \
      --path=./external-secrets \
      --prune=true \
      --namespace=external-secrets \
      --export  > apps/external-secrets/external-secrets.kustomization.yaml
    
    git add .
    git commit -m 'feat: Defined a deploy key, a git repository and a kustomization for external secrets operator.'
    git push

    flux reconcile kustomization flux-system --with-source
    ```

=== "'external-secrets' kustomization"
    ```yaml
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: external-secrets
      namespace: external-secrets
    spec:
      interval: 1m0s
      path: ./external-secrets
      prune: true
      sourceRef:
        kind: GitRepository
        name: k8s-kind-apps
        namespace: external-secrets
    ```

Discord prévient d'une erreur liée à la *kustomization* '*external-secrets*' :

![](./images/alert_external-secrets_kustomization_error.png)

C'est peut-être normal : dans le dépôt `k8s-kind-apps`, le sous-répertoire `./external-secrets` est vide. Il est temps d'y définir la **HelmRelease**.


### La Helm Release 'external-secrets'

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"

    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-apps
    mkdir external-secrets
    
    flux create helmrelease external-secrets \
      --source=HelmRepository/external-secrets \
      --chart=external-secrets \
      --namespace=external-secrets \
      --export > ./external-secrets/external-secrets.helmrelease.yaml

    git add .
    git commit -m 'feat: Defined external-secrets helm release.'
    git push

    flux -n external-secrets reconcile kustomization external-secrets --with-source
    ```

=== "'external-secrets' Helm release"
    ```yaml
    ---
    apiVersion: helm.toolkit.fluxcd.io/v2
    kind: HelmRelease
    metadata:
      name: external-secrets
      namespace: external-secrets
    spec:
      chart:
        spec:
          chart: external-secrets
          reconcileStrategy: ChartVersion
          sourceRef:
            kind: HelmRepository
            name: external-secrets
      interval: 1m0s
    ```

Discord nous annonce la résolution du problème autour de la *kustomization* '*external secrets*' ainsi que le bon déploiement de la Helm release :

![external-secrets Helm release deployment](./images/discord_external-secrets_helm_release.png)


Regardons quels objets ont été déployés sur le cluster :

=== "code"
    ```sh
    kubectl -n external-secrets get all -l app.kubernetes.io/name=external-secrets
    ```

=== "output"
    ```sh
    NAME                                   READY   STATUS    RESTARTS   AGE
    pod/external-secrets-f44d64679-446nt   1/1     Running   0          10m

    NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/external-secrets   1/1     1            1           10m

    NAME                                         DESIRED   CURRENT   READY   AGE
    replicaset.apps/external-secrets-f44d64679   1         1         1       10m
    ```

Effectons une dernière vérification : 

=== "code"
    ```sh
    kubectl -n external-secrets get all
    ```

=== "output"
    ```sh
    NAME                                                   READY   STATUS    RESTARTS   AGE
    pod/external-secrets-cert-controller-6658f6fb8-2bsrj   1/1     Running   0          12m
    pod/external-secrets-f44d64679-446nt                   1/1     Running   0          12m
    pod/external-secrets-webhook-955948cd4-599dt           1/1     Running   0          12m

    NAME                               TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
    service/external-secrets-webhook   ClusterIP   10.43.39.24   <none>        443/TCP   12m

    NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/external-secrets                   1/1     1            1           12m
    deployment.apps/external-secrets-cert-controller   1/1     1            1           12m
    deployment.apps/external-secrets-webhook           1/1     1            1           12m

    NAME                                                         DESIRED   CURRENT   READY   AGE
    replicaset.apps/external-secrets-cert-controller-6658f6fb8   1         1         1       12m
    replicaset.apps/external-secrets-f44d64679                   1         1         1       12m
    replicaset.apps/external-secrets-webhook-955948cd4           1         1         1       12m
    ```


!!! Success
    **'External-Secrets Operator (ESO)'** est déployé correctement sur notre cluster ! :fontawesome-regular-face-laugh-wink:



## Déploiement de **Vault OSS**



### Google Cloud Platform

Le mécanisme d'*auto-unseal* de Vault repose sur l'utilisation d'un service de gestion de clés (ie. '*Key Management System*', ou '*KMS*') proposé par un '*Cloud Service Provider*' ('*CSP*'). Notre choix s'est porté sur la plateforme '*Google Cloud Platform*' ('*CGP*') mais tout autre *CSP* proposant un *KMS* aurait pu faire l'affaire.

!!! info
    [https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-gcp-kms](https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-gcp-kms)



#### Projet GCP

Nous disposons d'un compte GCP et avons préalablement créé le projet suivant :

|KEY|VALUE|
|---:|---|
|Project Name|papaFrancky|
|Project ID|papafrancky|



#### Activation des APIs

Pour consommer les services GCP, il faut activer leurs APIs.

|APIs à activer|
|---|
|Cloud Key Management Service (KMS) API|
|Compute Engine API|


##### Activation des APIs GCP via la console (web UI)

!!! tip
    APIs & Services > Enabled APIs & Services > + ENABLE APIS AND SERVICES

Sélectionner 'Enabled APIs and Services' dans la colonne de gauche :
![Enabled APIs and services](./images/gcp.enable_apis.01.png)

Ajout d'une nouvelle API :
![Ajout d'une nouvelle API](./images/gcp.enable_apis.02.png)

Recherche de l'API KMS :
![Recherche de l'API KMS](./images/gcp.enable_apis.03.png)

Sélection de l'API KMS :
![Sélection de l'API KMS](./images/gcp.enable_apis.04.png)

Activation de l'API KMS :
![Activation de l'API KMS](./images/gcp.enable_apis.05.png)

Ajout d'une nouvelle API :
![Ajout d'une nouvelle API](./images/gcp.enable_apis.02.png)

Validation et retour à la recherche d'APIs :
![Validation et retour à la recherche d'APIs](./images/gcp.enable_apis.06.png)

Recherche de l'API Compute :
![Recherche de l'API Compute](./images/gcp.enable_apis.07.png)

Sélection de l'API Compute :
![Sélection de l'API Compute](./images/gcp.enable_apis.08.png)

Activation de l'API Compute :
![Activation de l'API Compute](./images/gcp.enable_apis.09.png)


##### Activation des APIs GCP via *gcloud* (CLI)

```sh
# gcloud update
gcloud components update --quiet

# Authentification
gcloud auth login

# Affichage des projets existants
gcloud projects list
  # PROJECT_ID   NAME         PROJECT_NUMBER
  # papafrancky  papaFrancky  11623004919

# Sélection du projet papaFrancky
gcloud config set project papafrancky

# Activation des APIS 'cloudkms' et 'compute'
gcloud services enable cloudkms.googleapis.com compute.googleapis.com

# Vérification de la bonne activation des APIS
gcloud services list | grep -E 'kms|compute'    
```



#### Service account

Vault utilisera un service-account GCP (en fournissant ses credentials) qui disposera des droits d'accès à une clé hébergée dans le *Key Management Service (KMS)* de *GCP*. Paramétré en mode auto-unseal, Vault se servira de cette clé comme *root key* pour protèger l'*encryption key*.


##### Création du service account via la console (Web UI)

!!! tip
    IAM & Admin > Service Accounts > + CREATE SERVICE ACCOUNT

Sélection de 'APIs and services' > 'service account' :
![Sélection de 'API and services' > 'service accounts'](./images/gcp.service_account.01.png)

Création d'un nouveau *service account* :
![Création d'un nouveau service account](./images/gcp.service_account.02.png)

![Création d'un nouveau service account](./images/gcp.service_account.03.png)

Validation de la création du *service account* :
![Création d'un nouveau service account](./images/gcp.service_account.04.png)


##### Création du service account via gcloud (CLI)


=== "code"
    ```sh
    gcloud iam service-accounts create k8s-vault-test \
      --project="papafrancky" \
      --description="Vault OSS" \
      --display-name="k8s-vault"
    ```


#### Service-account key

Pour consommer les APIS activées sur notre projet GCP avec les privilèges associés au *service account 'k8s-vault'*, Vault OSS aura besoin de la clé privée de ce dernier. Nous Décrirons ici la création de cette clé privée.


##### Création de la clé via la console (Web UI)

![Création de la clé privée du service account #1](./images/gcp.service_account_key.01.png)

![Création de la clé privée du service account #2](./images/gcp.service_account_key.02.png)

![Création de la clé privée du service account #3](./images/gcp.service_account_key.03.png)

![Création de la clé privée du service account #4](./images/gcp.service_account_key.04.png)

![Création de la clé privée du service account #5](./images/gcp.service_account_key.05.png)

La création d'une clé déclenche le téléchargement d'un fichier texte au format JSON :
![Création de la clé privée du service account #6](./images/gcp.service_account_key.06.png)

![Création de la clé privée du service account #7](./images/gcp.service_account_key.07.png)



##### Création de la clé via gcloud (CLI)

!!! Note
    Nous préciserons que nous souhaitons récupérer le fichier JSON contenant la clé privée de notre *service account* en local dans le fichier ```${HOME}/vault-sa-key```.

=== "code"
    ```sh
    gcloud iam service-accounts keys create ${HOME}/vault-sa-key \
      --iam-account=k8s-vault@papafrancky.iam.gserviceaccount.com
    ```
=== "output"
    ```sh
    created key [22a3198bbbd9984c615b3600d0eef0183091c4bb] of type [json] as [/Users/franck/vault-sa-key] for [k8s-vault@papafrancky.iam.gserviceaccount.com]
    ```

=== "Clé privée au format JSON"
    ```json
    {
      "type": "service_account",
      "project_id": "papafrancky",
      "private_key_id": "9888481c9848a94a8549c8b58112642fa8032a2f",
      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCfKVHMPAX5sbri\n8lQUMELRGipMxsd    +FwFQQ0uYSYRW9YgK6YgyJojTnnh/XJqPk/JLP/tEP4cg2wFe\nrNw7+PWe3j1t0TZPMHzSUylm6CKHfqdXGiaDRmmDp8pbTtLGCk   +NrqN7IIXZrZq1\nNnEQ4WRQciRZmHba2NL7jM6kPgpkRR2vAr0rnz0LJe1UI0em1EPqAtOTyRIwn3fV\n3Sccbl2WI2G5Dhq1DaLkz9D/  dWfpmGzDPURfGQJ9Igen7Erw0mzcQQ81F2j/+RuH\npmOKUrH8I9thb00BHIa54VwSENzAL/UV1p   +7W22O61uqdpjpDiUm6eaY27DstBP4\nSeVJeOWvAgMBAAECggEAO1VshH413g1XNcaP+Iy7Q/eEoGWUNhm+aB0GP+ncN4zF\n4AeKOePqqzVPB2/   OwMqvD0V1Vs52AhYSzygS3Bql+kkwTlGpdOEHD2NoMlBEmw1o\ntcxuYg7sQ+PXyK08Xw619IQPttV7gJg67eYzRU85FdJPYcU4PcKJ+LPXzxu/  xPv2\nCK0KIeX6taQNPpTY48lqRAs0gl9yHpRwTEGmWkWcic5qH9F6hAnfp4SPbOFAXtTm\n7JTtsE0hd1GSnZFl2aGep6yfpU6MrhXNZLjUBFnB7XZw3ZBHRnsEx2GAkTaRs3   Uj\nXSKt6STH+p1q+u3HaeNwl9PvyykBNb7P4JxGxSij7QKBgQDcsisG0Oym0zI+Wc2T\nG9lElL4cn7Xa62qys9tQggd4i6CMI/  nBlPXqkQ1or2JVTfehB0grRJAVeE2VWseT\nJaum7imkadp259/LvgRqrZDbWMZ9rfbi9fBE0CCvTakLs7Y5ZDGiVqYEOFzrzwh/\ne0/    9xPMOn6nyEFq0PErZWs969QKBgQC4nzftBSWEQe4BZ2GZMB1pqWzMeu+pxtO4\ntstEK4gbihhVdkcLNW7NjqvX1W3+zEFDQTzFmZCdNivyLpaw5gdPI9Y9Kr7ZqaG/   \n4PR8bPowDAXqh28UbEWgvheKUqblj0cL4EW54OPRh6n2Xk5neXAmBId1Ux2iRKT3\n29k/Wuc/kwKBgFnrRdibGzDFb/  0zfazoddeZevQSpnex32E8IqlksUKOMTWoGsSi\nuqd9vibe/oOfJru3SdJHNyVoRMQLnrD3cj6rXtAcSOSViPtsSkRkv1Z/jy/5x1Ol\nvOVsn0SNsciQyjgL   +KUaBL5HcKSrT90REwBkVFuq9gUoYKx6vExe0ZZZAoGARHxT\nq6noE9q9JmoqK0BM+OAvit7jvrAR5Ahy  +LPJRqYAhttcWU0V8EzHdEYpCobMgt1V\nZNulaJwqyyj7H14FQhdCJuiPaYDijqItL2bhnCcpnqlkzEepwIojg11LqgZvTXmB\nhAVnnVdc9hZfsUS8FG5DrYMKkCI0q/   ky6qyW8d8CgYAkH9WQFS7xR2oIzSkCH8NW\nZKlO9ruGUSIUT0pIdh5yD0oGgFN/cR3f2sEgj5wX7zXg3+fJ/f7wBKx438hWw540\nzD58uxl/9brOYx95/   dld58AGiLWvYhJBgVI1QZNPmXZxMHdW86/G+3S/JQC6nprE\nMXVybj1Axo6H+6LsSbb71w==\n-----END PRIVATE KEY-----\n",
      "client_email": "k8s-vault@papafrancky.iam.gserviceaccount.com",
      "client_id": "114409726477469875395",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/k8s-vault%40papafrancky.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    }
    ```



Nous allons tout de suite intégrer cette clé sous la forme de _*secret Kubernetes*_ dans le namespace dédié à Vault :


```sh
kubectl -n vault create secret generic vault-sa-key --from-file=${HOME}/vault-sa-key
```

Vérifions notre objet nouvellement créé :

=== "code"
    ```sh
    kubectl -n vault get secret vault-sa-key -o yaml
    ```

=== "output"
    ```yaml
    apiVersion: v1
    data:
      vault-sa-key:     ewogICJ0eXBlIjogInNlcnZpY2VfYWNjb3VudCIsCiAgInByb2plY3RfaWQiOiAicGFwYWZyYW5ja3kiLAogICJwcml2YXRlX2tleV9pZCI6ICI5ODg4NDgxYzk4NDhhOTRhODU0OW    M4YjU4MTEyNjQyZmE4MDMyYTJmIiwKICAicHJpdmF0ZV9rZXkiOiAiLS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tXG5NSUlFdkFJQkFEQU5CZ2txaGtpRzl3MEJBUUVGQUFTQ0JL    WXdnZ1NpQWdFQUFvSUJBUUNmS1ZITVBBWDVzYnJpXG44bFFVTUVMUkdpcE14c2QrRndGUVEwdVlTWVJXOVlnSzZZZ3lKb2pUbm5oL1hKcVBrL0pMUC90RVA0Y2cyd0ZlXG5yTnc3K1    BXZTNqMXQwVFpQTUh6U1V5bG02Q0tIZnFkWEdpYURSbW1EcDhwYlR0TEdDaytOcnFON0lJWFpyWnExXG5ObkVRNFdSUWNpUlptSGJhMk5MN2pNNmtQZ3BrUlIydkFyMHJuejBMSmUx    VUkwZW0xRVBxQXRPVHlSSXduM2ZWXG4zU2NjYmwyV0kyRzVEaHExRGFMa3o5RC9kV2ZwbUd6RFBVUmZHUUo5SWdlbjdFcncwbXpjUVE4MUYyai8rUnVIXG5wbU9LVXJIOEk5dGhiMD    BCSElhNTRWd1NFTnpBTC9VVjFwKzdXMjJPNjF1cWRwanBEaVVtNmVhWTI3RHN0QlA0XG5TZVZKZU9XdkFnTUJBQUVDZ2dFQU8xVnNoSDQxM2cxWE5jYVArSXk3US9lRW9HV1VOaG0r    YUIwR1ArbmNONHpGXG40QWVLT2VQcXF6VlBCMi9Pd01xdkQwVjFWczUyQWhZU3p5Z1MzQnFsK2trd1RsR3BkT0VIRDJOb01sQkVtdzFvXG50Y3h1WWc3c1ErUFh5SzA4WHc2MTlJUV    B0dFY3Z0pnNjdlWXpSVTg1RmRKUFljVTRQY0tKK0xQWHp4dS94UHYyXG5DSzBLSWVYNnRhUU5QcFRZNDhscVJBczBnbDl5SHBSd1RFR21Xa1djaWM1cUg5RjZoQW5mcDRTUGJPRkFY    dFRtXG43SlR0c0UwaGQxR1NuWkZsMmFHZXA2eWZwVTZNcmhYTlpMalVCRm5CN1hadzNaQkhSbnNFeDJHQWtUYVJzM1VqXG5YU0t0NlNUSCtwMXErdTNIYWVOd2w5UHZ5eWtCTmI3UD    RKeEd4U2lqN1FLQmdRRGNzaXNHME95bTB6SStXYzJUXG5HOWxFbEw0Y243WGE2MnF5czl0UWdnZDRpNkNNSS9uQmxQWHFrUTFvcjJKVlRmZWhCMGdyUkpBVmVFMlZXc2VUXG5KYXVt    N2lta2FkcDI1OS9MdmdScXJaRGJXTVo5cmZiaTlmQkUwQ0N2VGFrTHM3WTVaREdpVnFZRU9GenJ6d2gvXG5lMC85eFBNT242bnlFRnEwUEVyWldzOTY5UUtCZ1FDNG56ZnRCU1dFUW    U0QloyR1pNQjFwcVd6TWV1K3B4dE80XG50c3RFSzRnYmloaFZka2NMTlc3TmpxdlgxVzMrekVGRFFUekZtWkNkTml2eUxwYXc1Z2RQSTlZOUtyN1pxYUcvXG40UFI4YlBvd0RBWHFo    MjhVYkVXZ3ZoZUtVcWJsajBjTDRFVzU0T1BSaDZuMlhrNW5lWEFtQklkMVV4MmlSS1QzXG4yOWsvV3VjL2t3S0JnRm5yUmRpYkd6REZiLzB6ZmF6b2RkZVpldlFTcG5leDMyRThJcW    xrc1VLT01UV29Hc1NpXG51cWQ5dmliZS9vT2ZKcnUzU2RKSE55Vm9STVFMbnJEM2NqNnJYdEFjU09TVmlQdHNTa1JrdjFaL2p5LzV4MU9sXG52T1ZzbjBTTnNjaVF5amdMK0tVYUJM    NUhjS1NyVDkwUkV3QmtWRnVxOWdVb1lLeDZ2RXhlMFpaWkFvR0FSSHhUXG5xNm5vRTlxOUptb3FLMEJNK09Bdml0N2p2ckFSNUFoeStMUEpScVlBaHR0Y1dVMFY4RXpIZEVZcENvYk    1ndDFWXG5aTnVsYUp3cXl5ajdIMTRGUWhkQ0p1aVBhWURpanFJdEwyYmhuQ2NwbnFsa3pFZXB3SW9qZzExTHFnWnZUWG1CXG5oQVZublZkYzloWmZzVVM4Rkc1RHJZTUtrQ0kwcS9r    eTZxeVc4ZDhDZ1lBa0g5V1FGUzd4UjJvSXpTa0NIOE5XXG5aS2xPOXJ1R1VTSVVUMHBJZGg1eUQwb0dnRk4vY1IzZjJzRWdqNXdYN3pYZzMrZkovZjd3Qkt4NDM4aFd3NTQwXG56RD    U4dXhsLzlick9ZeDk1L2RsZDU4QUdpTFd2WWhKQmdWSTFRWk5QbVhaeE1IZFc4Ni9HKzNTL0pRQzZucHJFXG5NWFZ5YmoxQXhvNkgrNkxzU2JiNzF3PT1cbi0tLS0tRU5EIFBSSVZB    VEUgS0VZLS0tLS1cbiIsCiAgImNsaWVudF9lbWFpbCI6ICJrOHMtdmF1bHRAcGFwYWZyYW5ja3kuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLAogICJjbGllbnRfaWQiOiAiMTE0ND    A5NzI2NDc3NDY5ODc1Mzk1IiwKICAiYXV0aF91cmkiOiAiaHR0cHM6Ly9hY2NvdW50cy5nb29nbGUuY29tL28vb2F1dGgyL2F1dGgiLAogICJ0b2tlbl91cmkiOiAiaHR0cHM6Ly9v    YXV0aDIuZ29vZ2xlYXBpcy5jb20vdG9rZW4iLAogICJhdXRoX3Byb3ZpZGVyX3g1MDlfY2VydF91cmwiOiAiaHR0cHM6Ly93d3cuZ29vZ2xlYXBpcy5jb20vb2F1dGgyL3YxL2Nlcn    RzIiwKICAiY2xpZW50X3g1MDlfY2VydF91cmwiOiAiaHR0cHM6Ly93d3cuZ29vZ2xlYXBpcy5jb20vcm9ib3QvdjEvbWV0YWRhdGEveDUwOS9rOHMtdmF1bHQlNDBwYXBhZnJhbmNr    eS5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSIsCiAgInVuaXZlcnNlX2RvbWFpbiI6ICJnb29nbGVhcGlzLmNvbSIKfQo=
    kind: Secret
    metadata:
      creationTimestamp: "2025-11-10T15:10:23Z"
      name: vault-sa-key
      namespace: vault
      resourceVersion: "1050214"
      uid: eef1fcc1-555e-4e88-90de-36195257616f
    type: Opaque
    ```

S'agissant d'un objet de type 'secret', le contenu est en base 64. Déchiffrons-le pour nous assurer que son contenu correspond bien au fichier JSON téléchargé depuis GCP et contenant la clé privée de notre 'service account':

=== "code"
    ```sh
    kubectl -n vault get secret vault-sa-key -o yaml | yq -r .data.vault-sa-key | base64 -d
    ```

=== "output"
    ```json
    {
      "type": "service_account",
      "project_id": "papafrancky",
      "private_key_id": "9888481c9848a94a8549c8b58112642fa8032a2f",
      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCfKVHMPAX5sbri\n8lQUMELRGipMxsd    +FwFQQ0uYSYRW9YgK6YgyJojTnnh/XJqPk/JLP/tEP4cg2wFe\nrNw7+PWe3j1t0TZPMHzSUylm6CKHfqdXGiaDRmmDp8pbTtLGCk   +NrqN7IIXZrZq1\nNnEQ4WRQciRZmHba2NL7jM6kPgpkRR2vAr0rnz0LJe1UI0em1EPqAtOTyRIwn3fV\n3Sccbl2WI2G5Dhq1DaLkz9D/  dWfpmGzDPURfGQJ9Igen7Erw0mzcQQ81F2j/+RuH\npmOKUrH8I9thb00BHIa54VwSENzAL/UV1p   +7W22O61uqdpjpDiUm6eaY27DstBP4\nSeVJeOWvAgMBAAECggEAO1VshH413g1XNcaP+Iy7Q/eEoGWUNhm+aB0GP+ncN4zF\n4AeKOePqqzVPB2/OwMqvD0V1Vs52AhYSzygS3Bql  +kkwTlGpdOEHD2NoMlBEmw1o\ntcxuYg7sQ+PXyK08Xw619IQPttV7gJg67eYzRU85FdJPYcU4PcKJ+LPXzxu/   xPv2\nCK0KIeX6taQNPpTY48lqRAs0gl9yHpRwTEGmWkWcic5qH9F6hAnfp4SPbOFAXtTm\n7JTtsE0hd1GSnZFl2aGep6yfpU6MrhXNZLjUBFnB7XZw3ZBHRnsEx2GAkTaRs3Uj\n  XSKt6STH+p1q+u3HaeNwl9PvyykBNb7P4JxGxSij7QKBgQDcsisG0Oym0zI+Wc2T\nG9lElL4cn7Xa62qys9tQggd4i6CMI/   nBlPXqkQ1or2JVTfehB0grRJAVeE2VWseT\nJaum7imkadp259/LvgRqrZDbWMZ9rfbi9fBE0CCvTakLs7Y5ZDGiVqYEOFzrzwh/\ne0/   9xPMOn6nyEFq0PErZWs969QKBgQC4nzftBSWEQe4BZ2GZMB1pqWzMeu+pxtO4\ntstEK4gbihhVdkcLNW7NjqvX1W3+zEFDQTzFmZCdNivyLpaw5gdPI9Y9Kr7ZqaG/  \n4PR8bPowDAXqh28UbEWgvheKUqblj0cL4EW54OPRh6n2Xk5neXAmBId1Ux2iRKT3\n29k/Wuc/kwKBgFnrRdibGzDFb/   0zfazoddeZevQSpnex32E8IqlksUKOMTWoGsSi\nuqd9vibe/oOfJru3SdJHNyVoRMQLnrD3cj6rXtAcSOSViPtsSkRkv1Z/jy/5x1Ol\nvOVsn0SNsciQyjgL  +KUaBL5HcKSrT90REwBkVFuq9gUoYKx6vExe0ZZZAoGARHxT\nq6noE9q9JmoqK0BM+OAvit7jvrAR5Ahy   +LPJRqYAhttcWU0V8EzHdEYpCobMgt1V\nZNulaJwqyyj7H14FQhdCJuiPaYDijqItL2bhnCcpnqlkzEepwIojg11LqgZvTXmB\nhAVnnVdc9hZfsUS8FG5DrYMKkCI0q/  ky6qyW8d8CgYAkH9WQFS7xR2oIzSkCH8NW\nZKlO9ruGUSIUT0pIdh5yD0oGgFN/cR3f2sEgj5wX7zXg3+fJ/f7wBKx438hWw540\nzD58uxl/9brOYx95/    dld58AGiLWvYhJBgVI1QZNPmXZxMHdW86/G+3S/JQC6nprE\nMXVybj1Axo6H+6LsSbb71w==\n-----END PRIVATE KEY-----\n",
      "client_email": "k8s-vault@papafrancky.iam.gserviceaccount.com",
      "client_id": "114409726477469875395",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/k8s-vault%40papafrancky.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    }
    ```


#### KMS key

Il s'agit maintenant de créer dans le service GCP '*KMS*' la clé qui servira de '*root key*' pour *Vault OSS*.

!!! Warning
    Avant de créer la clé, nous devons créer son trousseau (ou _*'key ring'*_).

Informations concernant le trousseau :

|KEY|VALUE|
|---|---|
|Key ring name|k8s-vault|
|Single/multi region|single|
|Region|europe-west9|

Informations concernant la clé  :

|KEY|VALUE|
|---|---|
|Key name|k8s-vault|
|Protection level|software|
|Key material|generated|
|Purpose and algorithm|symmetric encrypt/decrypt|
|Key rotation|90d|


###### Création du trousseau (ou '*key ring*') et de sa clé via la console (Web UI)


![Création du trouseau KMS et de sa clé #1](./images/gcp.kms.key.01.png)

![Création du trouseau KMS et de sa clé #2](./images/gcp.kms.key.02.png)

![Création du trouseau KMS et de sa clé #3](./images/gcp.kms.key.03.png)

![Création du trouseau KMS et de sa clé #4](./images/gcp.kms.key.04.png)

![Création du trouseau KMS et de sa clé #5](./images/gcp.kms.key.05.png)


###### Création du trousseau (ou '*key ring*') et de sa clé via gcloud (CLI)


=== "code"
    ```sh
    # Création du trousseau (ou 'key ring') :
    gcloud kms keyrings create k8s-vault \
      --location europe-west9

    # Création de la clé :
    gcloud kms keys create k8s-vault \
      --keyring k8s-vault \
      --location europe-west9 \
      --purpose encryption \
      --rotation-period "90d" \
      --next-rotation-time "2025-11-01T00:00:00"
    ```


#### Accès du service account à la clé

Il nous reste à autoriser notre service account ***'k8s-vault@papafrancky.iam.gserviceaccount.com'*** à accéder à la clé que nous venons de créer.

|KEY|VALUE|
|---|---|
|Principal|k8s-vault@papafrancky.iam.gserviceaccount.com|
|Role|Cloud KMS Viewer|
|Role|Cloud KMS CryptoKey Encrypter/Decrypter|


##### Accès du service account à la clé via la console (Web UI)

!!! tip
    Security > Key Management > k8s-vault (key ring) > k8s-vault (key) > PERMISSIONS > + GRANT ACCESS


![Autorisation d'accès du service account à la clé KMS #1](./images/gcp.kms.grant_access.01.png)

![Autorisation d'accès du service account à la clé KMS #2](./images/gcp.kms.grant_access.02.png)

![Autorisation d'accès du service account à la clé KMS #3](./images/gcp.kms.grant_access.03.png)

![Autorisation d'accès du service account à la clé KMS #4](./images/gcp.kms.grant_access.04.png)

![Autorisation d'accès du service account à la clé KMS #5](./images/gcp.kms.grant_access.05.png)

![Autorisation d'accès du service account à la clé KMS #6](./images/gcp.kms.grant_access.06.png)

![Autorisation d'accès du service account à la clé KMS #7](./images/gcp.kms.grant_access.07.png)

![Autorisation d'accès du service account à la clé KMS #8](./images/gcp.kms.grant_access.08.png)

![Autorisation d'accès du service account à la clé KMS #9](./images/gcp.kms.grant_access.09.png)

![Autorisation d'accès du service account à la clé KMS #10](./images/gcp.kms.grant_access.10.png)


##### Accès du service account à la clé via gcloud (CLI)

!!! Doc
    [https://cloud.google.com/kms/docs/iam#granting_permissions_to_use_keys](https://cloud.google.com/kms/docs/iam#granting_permissions_to_use_keys)


Donnons les accès souhaités à notre service account '*k8s-vault*' sur la clé KMS :

```sh
gcloud kms keys add-iam-policy-binding k8s-vault \
  --keyring k8s-vault \
  --location europe-west9 \
  --member serviceAccount:k8s-vault@papafrancky.iam.gserviceaccount.com \
  --role roles/cloudkms.viewer

gcloud kms keys add-iam-policy-binding k8s-vault \
  --keyring k8s-vault \
  --location europe-west9 \
  --member serviceAccount:k8s-vault@papafrancky.iam.gserviceaccount.com \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter
```


Vérifions l'opération :

=== "code"
    ```sh
    gcloud kms keys get-iam-policy k8s-vault \
      --keyring k8s-vault \
      --location europe-west9
    ```

=== "output"
    ```sh
    bindings:
    - members:
      - serviceAccount:k8s-vault@papafrancky.iam.gserviceaccount.com
      role: roles/cloudkms.cryptoKeyEncrypterDecrypter
    - members:
      - serviceAccount:k8s-vault@papafrancky.iam.gserviceaccount.com
      role: roles/cloudkms.viewer
    etag: BwZCnYs5aTQ=
    version: 1
    ```

Nous en avons fini avec les préparatifs côté GCP :fontawesome-regular-face-laugh-wink:



### Mise en place de Vault en mode 'auto-unseal'

Nous couvrirons dans cette section l'installation de Vault, son initialisation et son _*unsealing*_.


#### Dépôt GitHub

La définition de la '*HelmRelease*' ainsi que ses '*custom values*' sera hébergée dans un sous-répertoire déddié à **Vault**, dans le dépôt GitHub des applications gérées par FluxCD :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-apps
mkdir vault
```


#### 'Custom values'

Les '*Helm Charts*' viennent toujours avec des '*default values*' et **Vault** ne fait pas exception à la règle.

Pour consulter les '*custom values*' de **Vault** :

```sh
helm show values hashicorp/vault
```

Nous souhaitons déployer sur notre cluster Kubernetes Vault en mode standalone et en 'auto-unseal', ce qui ne correspond pas au paramétrage proposé par les '*default values*'.

Sur la base de ces dernières, nous allons écrire les '*custom values*' de notre instance **Vault** pour arriver à nos fins. Nous stockerons nos '*custom values*' dans un '*ConfigMap*' :

!!! Warning
    Nous déploierons ici Vault en mode **'standalone'**, ce qui ne se prête pas à un contexte de production.

Notre pod Vault aura besoin de la clé privée du service-account GCP '*k8s-vault*' pour accéder à la clé KMS qui débloquera Vault ('*unsealing*'). Cette clé privée est récupérée à partir du *secret* Kubernetes '*k8s-vault-gcp-service-account-key*' qui sera monté dans le répertoire '*/vault/userconfig*' du pod.


```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-apps
mkdir vault
# Ecriture des 'custom values' du HelmChart vault dans un fichier 'values.yaml' :
cat << EOF > ./vault/values.yaml
global:
  enabled: false
  namespace: "vault"
injector:
  enabled: false
server:
  enabled: true
  extraEnvironmentVars:
    GOOGLE_REGION: europe-west9
    GOOGLE_PROJECT: papafrancky
    GOOGLE_APPLICATION_CREDENTIALS: /vault/userconfig/vault-sa-key/vault-sa-key
  extraVolumes:
    - type: secret
      name: vault-sa-key
      path: /vault/userconfig
  standalone:
    enabled: true
    config: |
      ui = true

      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
        # Enable unauthenticated metrics access (necessary for Prometheus Operator)
        #telemetry {
        #  unauthenticated_metrics_access = "true"
        #}
      }
      storage "file" {
        path = "/vault/data"
      }

      # Example configuration for using auto-unseal, using Google Cloud KMS. The
      # GKMS keys must already exist, and the cluster must have a service account
      # that is authorized to access GCP KMS.
      seal "gcpckms" {
        project     = "papafrancky"
        region      = "euope-west9"
        key_ring    = "k8s-vault"
        crypto_key  = "k8s-vault"
      }
  serviceAccount:
    create: true
    name: "vault"
ui:
  enabled: true
EOF

# Création du ConfigMap :
kubectl -n vault create configmap vault-values \
  --from-file=./vault/values.yaml \
  --dry-run=client \
  -o yaml > ./vault/vault-values.configmap.yaml

# Suppression du fichier values.yaml :
/bin/rm ./vault/values.yaml
```


#### Helm release Vault


##### Le GitRepository dédié à Vault

###### Création et installation de la '**Deploy Key**'

La '*deploy key*' va permettre à FluxCD de s'authentifier auprès du dépôt GitHub dédié à nos applications. Nous avons pris le partir de fournir une '*deploy key*' par application.

=== "code"
    ```sh
    export GITHUB_USERNAME=papafrancky

    flux create secret git k8s-kind-apps-gitrepository-deploykeys \
      --url=ssh://github.com/${GITHUB_USERNAME}/k8s-kind-apps \
      --namespace=vault
    
    kubectl -n vault get secret k8s-kind-apps-gitrepository-deploykeys -o yaml
    ```

=== "output"
    ```yaml
      apiVersion: v1
      data:
        identity:       LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JRzJBZ0VBTUJBR0J5cUdTTTQ5QWdFR0JTdUJCQUFpQklHZU1JR2JBZ0VCQkRCZ     kIrbnV3VUVuOWxKc0NQMTIKR0NoZzIrYVJ5c2dKem95b2xVMEJZT09KL29kRjJIdFRMd0k1a1FXb2lGYVBld3FoWkFOaUFBVHZTal     ZrNWF0eQpMSDhWUVhVV0pCdlFBbXJYVFd2K1RCQVRoMGZwcmsxbmJxS1hlc1pab0d4eGFJWElYMEJiZi9FZXdMTWxNRWUrClVqRVV   FSE4veGF4b1E3ZnAwV2NkeGtnV1loVkF4ZU15Z09EQXU3TzhBK1l6K3RVT0h5U1NKSTA9Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0t      LS0K
        identity.pub:       ZWNkc2Etc2hhMi1uaXN0cDM4NCBBQUFBRTJWalpITmhMWE5vWVRJdGJtbHpkSEF6T0RRQUFBQUlibWx6ZEhBek9EUUFBQUJoQk85S     05XVGxxM0lzZnhWQmRSWWtHOUFDYXRkTmEvNU1FQk9IUittdVRXZHVvcGQ2eGxtZ2JIRm9oY2hmUUZ0LzhSN0FzeVV3Ujc1U01SUV     FjMy9GckdoRHQrblJaeDNHU0JaaUZVREY0ektBNE1DN3M3d0Q1alA2MVE0ZkpKSWtqUT09Cg==
        known_hosts:      Z2l0aHViLmNvbSBlY2RzYS1zaGEyLW5pc3RwMjU2IEFBQUFFMlZqWkhOaExYTm9ZVEl0Ym1semRIQXlOVFlBQUFBSWJtbHpkSEF5T     lRZQUFBQkJCRW1LU0VOalFFZXpPbXhrWk15N29wS2d3RkI5bmt0NVlScllNak51RzVOODd1UmdnNkNMcmJvNXdBZFQveTZ2MG1LVj   BVMncwV1oyWUIvKytUcG9ja2c9
      kind: Secret
      metadata:
        creationTimestamp: "2025-11-02T17:40:12Z"
        name: k8s-kind-apps-gitrepository-deploykeys
        namespace: vault
        resourceVersion: "829103"
        uid: b213f750-58a1-40af-afb7-53eb765a2985
      type: Opaque
    ```

Nous devons déployer la **Deploy Key** sur notre dépôt GitHub '*k8s-kind-apps*' comme nous l'avons fait précédemment pour '*external secrets operator*'.

Commençons par récupérer notre clé publique depuis le *secret* que nous venons de créer : 

=== "code"
    ```sh
    kubectl -n vault get secret k8s-kind-apps-gitrepository-deploykeys -o jsonpath='{.data.identity\.pub}' | base64 -D
    ```

=== "output"
    ```yaml
    ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBO9KNWTlq3IsfxVBdRYkG9ACatdNa/5MEBOHR+muTWduopd6xlmgbHFohchfQFt/8R7AsyUwR75SMRQQc3/FrGhDt+nRZx3GSBZiFUDF4zKA4MC7s7wD5jP61Q4fJJIkjQ==
    ```

Intégrons-la enfin sur le dépôt GitHub dédié à nos applications :

![Vault Deploy Key #1](./images/vault.deploy_key.01.png)

![Vault Deploy Key #2](./images/vault.deploy_key.02.png)

![Vault Deploy Key #3](./images/vault.deploy_key.03.png)



###### Le GitRepository dédié aux applications

Nous avons défini la '**Deploy Key**', nous pouvons désormais définir le dépôt Git :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    export GITHUB_USERNAME=papafrancky

    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

    flux create source git k8s-kind-apps \
      --url=ssh://git@github.com/${GITHUB_USERNAME}/k8s-kind-apps.git \
      --branch=main \
      --secret-ref=k8s-kind-apps-gitrepository-deploykeys \
      --namespace=vault \
      --export > apps/vault/k8s-kind-apps.gitrepository.yaml
    ```

=== "'k8s-kind-apps' GitRepository"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: k8s-kind-apps
      namespace: external-secrets
    spec:
      interval: 1m0s
      ref:
        branch: main
      secretRef:
        name: k8s-kind-apps-gitrepository-deploykeys
      url: ssh://git@github.com/papafrancky/k8s-kind-apps.git
    ```

Forçons FluxCD à créer ce nouvel objet :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
git add .
git commit -m 'Defined k8s-kind-apps GitRepository in namespace vault.'
git push

flux reconcile kustomization flux-system --with-source
```



##### La Kustomization pour Vault

Nous devons dire à Flux qu'il doit gérer le sous-répertoire '*vault*' dans le dépôt Git dédié à nos applications :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

    # Définition de la kustomization Vault :
    flux create kustomization vault \
      --source=GitRepository/k8s-kind-apps.vault \
      --path=./vault \
      --prune=true \
      --namespace=vault \
      --export  > apps/vault/vault.kustomization.yaml
    ```

=== "'vault' kustomization"
    ```yaml
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: vault
      namespace: vault
    spec:
      interval: 1m0s
      path: ./vault
      prune: true
      sourceRef:
        kind: GitRepository
        name: k8s-kind-apps
        namespace: vault
    ```

Poussons nos modifications sur GitHub pour une prise en compte par FluxCD :

```sh
   export LOCAL_GITHUB_REPOS="${HOME}/code/github"

   cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

   git add .
   git commit -m 'Defined kustomization for Vault application.'
   git push
   
   flux reconcile kustomization flux-system --with-source
```

Discord nous remonte une erreur dans le channel vault : 

![Vault kustomization Deployment](./images/vault_kustomization.deployment.png)

Rien d'anormal, car nous n'avons écrit aucun manifest YAML dans le sous-répertoire '*vault*' du dépôt GitHub dédié à nos applications '*k8s-kind-apps*'. Dans Git, sans fichiers dans un répertoire, le répertoire n'existe pas. Le problème sera corrigé lorsque nous aurons défini notre '*Helm Release*' et ses '*custom values*'.


##### La Helm Release Vault

Nous définirons la HelmRelease de Vault et ses '*custom values*' dans le dépôt Git dédié à nos applications, comme nous l'avons fait précédemment pour '*external secrets operator*' :



###### Définition de la Release

Nous pouvons désormais définir notre 'helm release' pour que FluxCD puisse gérer le déploiement de Vault :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"

    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-apps
    
    flux create helmrelease vault \
      --source=HelmRepository/hashicorp \
      --chart=vault \
      --namespace=vault \
      --values-from=ConfigMap/vault-values \
      --export > ./vault/vault.helm-release.yaml
    ```

=== "'vault' helm release"
    ```yaml
    ---
    apiVersion: helm.toolkit.fluxcd.io/v2
    kind: HelmRelease
    metadata:
      name: vault
      namespace: vault
    spec:
      chart:
        spec:
          chart: vault
          reconcileStrategy: ChartVersion
          sourceRef:
            kind: HelmRepository
            name: hashicorp
      interval: 1m0s
      valuesFrom:
      - kind: ConfigMap
        name: vault-values
    ```

Poussons les modifications jusqu'à FluxCD :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-apps

git add .
git commit -m "feat: vault helm release with custom values"
git push

flux reconcile kustomization fluxsystem --with-source
flux -n vault reconcile kustomization vault --with-source
```

Discord nous annonce que la kustomization 'vault' est désormais bien fonctionnelle (notre dernier commit a créé le sous-répertoire 'vault' attendu) et que Vault est bien déployé sur notre cluster :

![Vault Helm Release Deployment](./images/vault_helm_release.deployment.png)



Assurons-nous que la Helm release est bien déployée dans le namespace '*vault*' :

=== "code"
    ```sh
    helm -n vault list
    ```

=== "output"
    ```sh
    NAME 	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART       	APP VERSION
    vault	vault    	1       	2025-11-10 15:48:01.835257 +0000 UTC	deployed	vault-0.31.0	1.20.4
    ```

Regardons l'état de nos objets dans le namespace 'vault' :

=== " code"
    ```sh
    kubectl -n vault get all
    ```

=== "output"
    ```sh
    NAME          READY   STATUS    RESTARTS        AGE
    pod/vault-0   0/1     Running   6 (2m10s ago)   8m5s

    NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
    service/vault            ClusterIP   10.43.76.26     <none>        8200/TCP,8201/TCP   8m5s
    service/vault-internal   ClusterIP   None            <none>        8200/TCP,8201/TCP   8m5s
    service/vault-ui         ClusterIP   10.43.131.120   <none>        8200/TCP            8m5s

    NAME                     READY   AGE
    statefulset.apps/vault   0/1     8m5s
    ```

Nous voyons que le pod 'vault-0' à un status 'Running' mais qu'il n'est pas 'ready'. Vérifions l'état de Vault sur le pod : 

=== "code"
    ```sh
    kubectl -n vault exec -it vault-0 -- vault status
    ```

=== "output"
    ```sh
    Key                      Value
    ---                      -----
    Seal Type                gcpckms
    Recovery Seal Type       n/a
    Initialized              false
    Sealed                   true
    Total Recovery Shares    0
    Threshold                0
    Unseal Progress          0/0
    Unseal Nonce             n/a
    Version                  1.20.4
    Build Date               2025-09-23T13:22:38Z
    Storage Type             file
    HA Enabled               false
    command terminated with exit code 2
    ```

Vault doit être initialisé !



#### Initialisation de Vault

L'initialisation de Vault passe par une commande à passer directement sur les pods (dans notre cas, nous n'en avons qu'un) :

=== "code"
    ```sh
    kubectl -n vault exec -it vault-0 -- vault operator init
    ```

=== "output"
    ```sh
    Recovery Key 1: eE4Os3Z4TSnVLjsROqGIyFdEiDVBTGvolywiY5PJ2tLh
    Recovery Key 2: SBLCPjboyMEdzhpPLwnC4g1FnMH5xG1Z8jHv/X/5fDIB
    Recovery Key 3: toG6YbkGeI6yRYMeeKVsKh+WocVFiqE9ZzFxRFpdw8QH
    Recovery Key 4: YVfC0LIPdZZ8OqC6vc3PlYsRjShbJRYLRaOq8bhBI823
    Recovery Key 5: GD2tpYHrtzBtPVzBHSo9ZeK8RM5/H6gxskUOoHBzSvAn

    Initial Root Token: hvs.CQwblgr767wFfJLVU5DgjIi8

    Success! Vault is initialized

    Recovery key initialized with 5 key shares and a key threshold of 3. Please
    securely distribute the key shares printed above.
    ```

!!! warning
    Le **'Root Token'** ainsi que les **'Recovery Keys'** doivent être conservés, et dans un lieu sûr !

Vérifions que Vault est bien opérationnel :

=== "code"
    ```sh
    kubectl -n vault exec -it vault-0 -- vault status
    ```

=== "output"
    ```sh
    Key                      Value
    ---                      -----
    Seal Type                gcpckms
    Recovery Seal Type       shamir
    Initialized              true
    Sealed                   false
    Total Recovery Shares    5
    Threshold                3
    Version                  1.20.4
    Build Date               2025-09-23T13:22:38Z
    Storage Type             file
    Cluster Name             vault-cluster-632ed50e
    Cluster ID               7b77d1d9-cb52-e83b-486f-5ce7811c6929
    HA Enabled               false
    ```

Vault est bien initialisé (Sealed = false). Assurons-nous malgré tout que le pod est désormais bien 'ready' :

=== " code"
    ```sh
    kubectl -n vault get pod vault-0
    ```

=== "output"
    ```sh
    NAME      READY   STATUS    RESTARTS   AGE
    vault-0   1/1     Running   0          65m
    ```


Connectons-nous à la web UI de Vault. Pour ce faire, nous utiliserons le '*root token*' récupéré lors de l'initialisation de Vault.

Commençons par utiliser le '*port-forwarding*' :

```sh
kubectl -n vault port-forward service/vault-ui 8200 8200
```

Ouvrons ensuite notre navigateur à l'URL suivante : ```http://localhost:8200/```.
![Vault UI #01](./images/vault.ui.01.png)

Nous accédons bien à Vault via son interface graphique !
![Vault UI #02](./images/vault.ui.02.png)




Tout est comme attendu ! :fontawesome-regular-face-laugh-wink:



### Test de l'auto-unseal

Vault est installé en *'statefulset'*, sa configuration est pérenne, aussi allons-nous le désinstaller et attendre que FluxCD le réinstalle pour nous assurer que Vault sera réinstallé dans un état initialisé. Paramétré en mode '*auto-unseal*', notre coffre devrait être opérationnel :

|Paramètre|Valeur|
|---|---|
|Initialized|true|
|Sealed|false|

=== "code"
    ```sh
    helm -n vault list
    ```

=== "output"
    ```sh
    NAME 	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART       	APP VERSION
    vault	vault    	1       	2024-06-01 16:13:04.681229835 +0000 UTC	deployed	vault-0.28.0	1.16.1
    ```

Désinstallons Vault tout en sachant que FluxCD le réinstallera ensuite :

=== "code"
    ```sh
    helm -n vault uninstall vault
    kubectl -n vault get all
    ```

=== "output"
    ```sh
    No resources found in vault namespace.
    ```

Discord nous prévient que FluxCD a redéployé la Helm release :

![Vault Helm release re-deployment](./images/vault_helm_release.png)

La Helm Release a bien re-déployé tous les objects nécessaires au bon fonctionnement de Vault en mode '*standalone*' :

=== "code"
    ```sh
    kubectl -n vault get all
    ```

=== "output"
    ```sh
    NAME          READY   STATUS    RESTARTS      AGE
    pod/vault-0   1/1     Running   8 (76m ago)   87m

    NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
    service/vault            ClusterIP   10.43.175.203   <none>        8200/TCP,8201/TCP   26h
    service/vault-internal   ClusterIP   None            <none>        8200/TCP,8201/TCP   26h
    service/vault-ui         ClusterIP   10.43.103.17    <none>        8200/TCP            26h

    NAME                     READY   AGE
    statefulset.apps/vault   1/1     26h
    ```

Regardons sur le pod nouvellement re-déployé l'état de Vault :

=== "code"
    ```sh
    kubectl -n vault exec -it vault-0 -- vault status
    ```

=== "output"
    ```sh
    Key                      Value
    ---                      -----
    Seal Type                gcpckms
    Recovery Seal Type       shamir
    Initialized              true
    Sealed                   false
    Total Recovery Shares    5
    Threshold                3
    Version                  1.20.4
    Build Date               2025-09-23T13:22:38Z
    Storage Type             file
    Cluster Name             vault-cluster-632ed50e
    Cluster ID               7b77d1d9-cb52-e83b-486f-5ce7811c6929
    HA Enabled               false
    ```

Vault est bien '*unsealed*'. Parce qu'il s'agit d'un '*statefulset*', les données sont persistantes sur le cluster et Vault se souvient malgré sa récente désinstallation qu'il avait été initialisé précédemment, raison pour laquelle nous n'avons pas eu à le refaire.

Parce qu'il est initialisé et paramétré correctement en mode '*auto-unseal*', notre coffre est complètement opérationnel juste après sa ré-installation. 

!!! Success
    Nous venons de valider le bon fonctionnement de l'**'auto-unsealing'** de Vault. :fontawesome-regular-face-laugh-wink:



XXXXX



## Intégration de Vault et External-Secrets à la Helm Release 'kube-prometheus-stack'

La stack de monitoring définit un mot de passe par défaut pour le compte admin de Grafana. Et c'est moche.

Pour corriger cela, nous nous proposons de définir un nouveau mot de passe pour ce compte et de le protéger dans Vault.

Nous utiliserons l'opérateur External Secrets synchroniser le mot de passe hébergé dans Vault avec une ConfigMap qui sera utilisée par Flux pour définir les *'custom values'* de la Helm Release 'kube-prometheus-stack'.

Tout un programme. ^^


### Ajout du *'secret'* dans Vault

Connectons-nous au pod *'Vault-0'* pour activer le *'secret engine'* **'KVv2'** et y héberger le mot de passe du compte d'administration de Grafana :

```sh
# Accès au pod du micro-service 'vault'
kubectl -n vault exec -it vault-0 -- sh

# Login sur Vault avec le Root token
vault login hvs.CQwblgr767wFfJLVU5DgjIi8

# Activation du 'secret engine' KVv2
vault secrets enable -version=2 kv

# Ecriture du secret 
vault kv put -mount kv monitoring/grafana/admin-account login=admin password=my-vaulted-custom-password


# Vérification
vault kv get -mount=kv monitoring/grafana/admin-account

============== Secret Path ==============
kv/data/monitoring/grafana/admin-account

======= Metadata =======
Key                Value
---                -----
created_time       2024-06-04T14:45:27.639679075Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            2

====== Data ======
Key         Value
---         -----
login       admin
password    my-vaulted-custom-password

# Deconnexion du pod 
exit
```


### Définition d'une *'policy'* permettant d'accéder en lecture aux secrets dédiés à Grafana

Maintenant, écrivons une *'policy'* nous permettant de récupérer notre mot de passe :

```sh
# Accès au pod du micro-service 'vault'
kubectl -n vault exec -it vault-0 -- sh

# Login sur Vault avec le Root token
vault login hvs.VPcxxUbQjWt66U3jRzMjfIaI

# Definition de la 'policy' donnant accès aux 'secrets' de Grafana en lecture
vault policy write monitoring-grafana--ro - << EOF     
path "kv/metadata/monitoring/grafana*" {
  capabilities = ["list","read"]
}
path "kv/data/monitoring/grafana*" {
  capabilities = ["list","read"]
}

path "kv/metadata/monitoring" {
  capabilities = ["list"]
}
path "kv/data/monitoring" {
  capabilities = ["list"]
}

path "kv/metadata" {
  capabilities = ["list"]
}

path "kv/metadata*" {
  capabilities = ["deny"]
}
path "kv/data*" {
  capabilities = ["deny"]
}
EOF

# Deconnexion du pod 
exit
```

### Authentification Kubernetes sur Vault

L'application Grafana doit pouvoir récupérer le mot de passe hébergé dans Vault. Voici comment nous allons nous y prendre pour arriver à nos fins :

* nous allons activer sur Vault l'**authentification Kubernetes**;
* nous attacherons au *service-account* avec lequel le pod Grafana sera exécuté  *'ClusterRole'* **auth-delegator**;
* enfin, il nous restera à définit au niveau de Vault un rôle visant à rattacher la *policy* créée précédemment à notre *service-account Kubernetes*.


!!! Info
    https://developer.hashicorp.com/vault/docs/auth/kubernetes#kubernetes-auth-method

    Use local service account token as the reviewer JWT :

    When running Vault in a Kubernetes pod the recommended option is to use the pod's local service account token.
    Vault will periodically re-read the file to support short-lived tokens. To use the local token and CA certificate,
    omit token_reviewer_jwt and kubernetes_ca_cert when configuring the auth method. Vault will attempt to load them
    from token and ca.crt respectively inside the default mount folder /var/run/secrets/kubernetes.io/serviceaccount/.

    Each client of Vault would need the **system:auth-delegator** ClusterRole

Commençons par activer et configurer l'authentification Kubernetes sur Vault :

```sh
# Accès au pod du micro-service 'vault'
kubectl -n vault exec -it vault-0 -- sh

# Login sur Vault avec le Root token
vault login hvs.VPcxxUbQjWt66U3jRzMjfIaI


# Activation de l'authentification Kubernetes
vault auth enable kubernetes
vault auth list

# Configuration de l'authentification Kubernetes 
vault write auth/kubernetes/config kubernetes_host=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}

# Deconnexion du pod 
exit
```



### Etablissement de la relation entre le service-account Kubernetes et celui de Vault



#### Service-account Kubernetes

Lors du déploiement de la *Helm release* *'kube-prometheus-stack'*, Grafana devra être en mesure de récupérer ses *custom values* dans un *Secret Kubernetes*. Ce dernier doit être généré en amont par l'opérateur *'External Secrets'* à partir d'un template sous forme de *ConfigMap* indiquant le besoin de récupérer le mot de passe du compte d'administration depuis Vault.

Le *Secret Kubernetes* doit donc être prêt avant le déploiement de la *Helm release*. Or le service-account qui sera utilisé par Grafana ne sera créé que lors de son déploiement. Il n'est donc pas envisageable de l'utiliser pour s'authentifier à Vault et récupérer le *secret* recherché.

Nous devons donc créer un *service-account* dédié, que nous nommerons ***'eso-grafana'***.

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    kubectl -n monitoring create serviceaccount eso-grafana --dry-run=client -o yaml | grep -v creationTimestamp > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/eso-grafana.serviceaccount.yaml
    ```

=== "'eso-grafana' service-account"
    ```sh
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: eso-grafana
      namespace: monitoring
    ```

Créons le service-account car nous en aurons besoin pour les tests un peu plus loin :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: setting up eso-grafana service-account."
git push

flux reconcile kustomization flux-system --with-source
```


#### ClusterRoleBinding

Nous allons donner à notre nouveau *service-account Kubernetes* le droit de déléguer son authentification en le rattachant au ClusterRole **'system:auth-delegator'**.

!!! Info
    https://kubernetes.io/docs/reference/access-authn-authz/rbac/#other-component-roles

    "**system:auth-delegator** allows delegated authentication and authorization checks. This is commonly used by add-on API servers for unified authentication and authorization."


=== "code"
    ```sh
    kubectl create clusterrolebinding eso-grafana-tokenreview-access \
      --clusterrole=system:auth-delegator \
      --serviceaccount=monitoring:eso-grafana
    ```

=== "output"
    ```sh
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      creationTimestamp: "2024-07-06T11:06:53Z"
      name: eso-grafana-tokenreview-access
      resourceVersion: "2860551"
      uid: e74382bd-dd09-4b2e-a896-a1d3fd578a24
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: system:auth-delegator
    subjects:
    - kind: ServiceAccount
      name: eso-grafana
      namespace: monitoring
    ```


#### Rattachement de la policy Vault au service-account Kubernetes

Pour ce faire, nous allons définir un rôle au niveau de l'authentification Kubernetes de Vault.

```sh
# Accès au pod du micro-service 'vault'
kubectl -n vault exec -it vault-0 -- sh

# Login sur Vault avec le Root token
vault login hvs.VPcxxUbQjWt66U3jRzMjfIaI

# Role autorisant le service-account Kubernetes à lire les secrets de Grafana
vault write auth/kubernetes/role/monitoring-grafana--ro \
  bound_service_account_names=eso-grafana \
  bound_service_account_namespaces=monitoring \
  policies=monitoring-grafana--ro \
  ttl=1h

# Vérification
vault read auth/kubernetes/role/monitoring-grafana--ro

  # Key                                         Value
  # ---                                         -----
  # alias_name_source                           serviceaccount_uid
  # bound_service_account_names                 [eso-grafana]
  # bound_service_account_namespace_selector    n/a
  # bound_service_account_namespaces            [monitoring]
  # policies                                    [monitoring-grafana--ro]
  # token_bound_cidrs                           []
  # token_explicit_max_ttl                      0s
  # token_max_ttl                               0s
  # token_no_default_policy                     false
  # token_num_uses                              0
  # token_period                                0s
  # token_policies                              [monitoring-grafana--ro]
  # token_ttl                                   1h
  # token_type                                  def

# Deconnexion du pod 
exit
```


#### Test de l'accès du service-account Kubernetes au secret Vault

Pour tester que le *service-account Kubernetes* **'eso-grafana'** du namespace **'monitoring'** accède bien au secret de Grafana dans Vault, nous allons déployer un pod temporaire qui s'exécutera avec ce service-account.


Voici ce que nous cherchons à vérifier :

1. Le pod est exécuté avec un service-account Kubernetes auquel est rattaché le ClusterRole **'system:auth-delegator'**;
2. L'application exécutée dans le pod s'authentifie à Vault (authentification Kubernetes) en utilisant le token de son *service-account Kubernetes* et rattaché le rôle Vault **'monitoring-grafana--ro'** ;
3. Ce rôle Vault autorise précisément ce service-account Kubernetes d'utiliser la policy Vault qui donne accès en lecture aux login et mot de passe du compte d'administration de Grafana;
4. Vault valide le token du service-account Kubernetes auprès de Kubernetes et renvoie à l'application du pod un token d'authentification à Vault, auquel est rattaché la policy d'accès aux credentials d'admin de Grafana;
5. L'application peut désormais de loguer à Vault avec le token ainsi récupéré et accéder ensuite au compte d'administration de Grafana.



##### Test en interrogeant directement l'API

```sh
# Lancement d'un pod Alpine avec le service-account 'monitoring:kube-prometheus-stack-grafana'
kubectl -n monitoring run --tty --stdin test --image=alpine --rm --overrides='{ "spec": { "serviceAccount": "eso-grafana" }  }' -- /bin/sh

# Installation de cURL
apk update && apk add curl jq

# Récupération du service-token JWT
SA_JWT_TOKEN=$( cat /var/run/secrets/kubernetes.io/serviceaccount/token )
    # -> Pour regarder son contenu : https://jwt.io/ website.

# Authentification sur Vault et récupération du token de session
CLIENT_TOKEN=$( curl --silent --request POST --data '{"jwt": "'"${SA_JWT_TOKEN}"'", "role": "monitoring-grafana--ro"}' http://vault.vault:8200/v1/auth/kubernetes/login | jq -r .auth.client_token )

# Récupération du mot de passe du compte admin de Grafana
curl --silent --header "X-Vault-Token:${CLIENT_TOKEN}"  http://vault.vault:8200/v1/kv/data/monitoring/grafana/admin-account | jq .data.data

# {
#   "login": "admin",
#   "password": "my-vaulted-custom-password"
# }
```


##### Test avec la CLI *'vault'*


```sh
# Lancement d'un pod Alpine avec le service-account 'monitoring:kube-prometheus-stack-grafana'
kubectl -n monitoring run --tty --stdin fedora --image=fedora --rm --overrides='{ "spec": { "serviceAccount": "eso-grafana" }  }' -- /bin/bash

# Installation de Vault : 
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
dnf -y install vault jq

# Pour une raison que j'ignore, la CLI 'vault' ne fonctionne pas après installation, mais une réinstallation semble régler le problème :
rpm -e vault && dnf -y install vault

# Test d'accès aux secrets de Grafana
export VAULT_ADDR="http://vault.vault:8200"
SA_TOKEN=$( cat /var/run/secrets/kubernetes.io/serviceaccount/token )
VAULT_TOKEN=$( vault write auth/kubernetes/login role=monitoring-grafana--ro jwt=${SA_TOKEN} | grep -w ^token | awk '{print $2}' )


vault login ${VAULT_TOKEN}

  # Success! You are now authenticated. The token information displayed below
  # is already stored in the token helper. You do NOT need to run "vault login"
  # again. Future Vault requests will automatically use this token.
  # 
  # Key                                       Value
  # ---                                       -----
  # token                                     hvs.CAESIKPEIR-x0Sx8oK2Yc5wICr13blMQSHWmS6SdTCt5jCExGh4KHGh2cy5zWHByV2ZkY2hHb2Q2VjY2YzBBcVk3QWE
  # token_accessor                            sTrkp8An57VCbuBWy1fDaHnd
  # token_duration                            59m49s
  # token_renewable                           true
  # token_policies                            ["default" "monitoring-grafana--ro"]
  # identity_policies                         []
  # policies                                  ["default" "monitoring-grafana--ro"]
  # token_meta_service_account_namespace      monitoring
  # token_meta_service_account_secret_name    n/a
  # token_meta_service_account_uid            665cb92c-90ba-4ad8-9313-9cae30e72203
  # token_meta_role                           monitoring-grafana--ro
  # token_meta_service_account_name           eso-grafana


vault kv list -mount=kv monitoring/grafana

# Keys
# ----
# admin-account


vault kv get -mount=kv monitoring/grafana/admin-account

  # ============== Secret Path ==============
  # kv/data/monitoring/grafana/admin-account
  # 
  # ======= Metadata =======
  # Key                Value
  # ---                -----
  # created_time       2024-06-08T15:52:46.958211047Z
  # custom_metadata    <nil>
  # deletion_time      n/a
  # destroyed          false
  # version            1
  # 
  # ====== Data ======
  # Key         Value
  # ---         -----
  # login       admin
  # password    my-vaulted-custom-password


vault kv get -mount=kv -field=password monitoring/grafana/admin-account

  # my-vaulted-custom-password
```

!!! success
    Notre pod, par le biais du service-account avec lequel il est exécuté, récupère comme attendu le secret dans Vault!  :fontawesome-regular-face-laugh-wink:



### Configuration d'External Secrets Operator (ESO)

Cet opérateur a pour rôle de synchroniser des objets Kubernetes de type *Secret* ou *ConfigMap* avec des 'secrets' stockés dans un Secrets Manager (dans notre cas, HashiCorp Vault).


#### Definition du Secret Store

Le *'SecretStore'* est un objet qui définit dans notre cas de figure l'adresse de Vault, le *'secret engine'* à utiliser (en renseignant son *'path'* et dans le cas de KV, la version du moteur), la manière de s'y authentifier (ici, on choisit l'authentification Kubernetes), avec quel *service-account Kubernetes* et quel rôle demander.

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

# Définition du SecretStore 'grafana' :
cat << EOF > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/grafana.secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: grafana
  namespace: monitoring
spec:
  provider:
    vault:
      server: "http://vault.vault:8200"
      path: "kv"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "monitoring-grafana--ro"
          serviceAccountRef:
            name: "eso-grafana"
EOF
```



#### Définition de l'*External Secret*

Une fois le *'SecretStore'* défini, nous pouvons nous intéresser aux *'External Secrets'* : il s'agit cette fois de préciser quel(s) *secret(s)* nous souhaitons récupérer depuis *SecretStore* donné :


```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cat << EOF > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/grafana.externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-secrets
  namespace: monitoring
spec:
  refreshInterval: "15s"
  secretStoreRef:
    name: grafana
    kind: SecretStore
  target:
    name: admin-password
  data:
  - secretKey: admin_password
    remoteRef:
      key: kv/monitoring/grafana/admin-account
      property: password
EOF
```



### Autorisation d'accès dans Vault à ce *service-account* aux *secrets* de Grafana 

Bien évidemment, notre nouveau *service-account* doit pouvoir accéder aux *secrets* de Grafana contenus dans Vault. Nous devons adapter notre rôle en conséquence :

```sh
# Login sur le pod Vault :
kubectl -n vault exec -it vault-0  -- sh

# Ouverture d'une session Vault avec le *root token*
vault login hvs.VPcxxUbQjWt66U3jRzMjfIaI

# Autorisation de lecture des secrets Grafana aux service-accounts 'kube-prometheus-grafana' et 'init-grafana' :
vault write auth/kubernetes/role/monitoring-grafana--ro \
  bound_service_account_names=eso-grafana \
  bound_service_account_namespaces=monitoring \
  policies=monitoring-grafana--ro \
  ttl=1h

# Fin de session sur le pod :
exit
```


#### Prise en compte des modifications 

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: setting up grafana secretstore and external-secret."
git push

flux reconcile kustomization flux-system --with-source
```




Vérifions la bonne création des nouveaux objets ESO :

=== "code"
    ```sh
    kubectl -n monitoring get secretstore,externalsecret
    ```
=== "output"
    ```sh
    NAME                                      AGE     STATUS   CAPABILITIES   READY
    secretstore.external-secrets.io/grafana   3d15h   Valid    ReadWrite      True
    
    NAME                                                                                    STORE     REFRESH INTERVAL   STATUS         READY
    externalsecret.external-secrets.io/grafana-secrets                                      grafana   15s                SecretSynced   True
    externalsecret.external-secrets.io/kube-prometheus-stack-custom-values-externalsecret   grafana   1h                 SecretSynced   True
    ```



#### Récupération de l'External Secret depuis un pod de test

```sh
# Création d'un pod Alpine excuté avec le service-account dédié à l'application Grafana
# et affichant le mot de passe du compte d'administration :
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: test
  name: test
  namespace: monitoring
spec:
  containers:
  - name: test
    image: alpine
    command: ["printenv"]
    args: ["ADMIN_PASSWORD"]
    env:
    - name: ADMIN_PASSWORD
      valueFrom:
        secretKeyRef:
          name: admin-password
          key: admin_password
  restartPolicy: Never
  serviceAccount: eso-grafana
EOF
```

Le pod pase à l'état 'Completed'. Consultons ses logs :

=== "code"
    ```sh
    kubectl -n monitoring logs test
    ```
=== "output"
    ```sh
    my-vaulted-custom-password
    ```

!!! success
    Nous récupérons comme attendu le mot de passe du compte d'administration de Grafana présent dans Vault.  :fontawesome-regular-face-laugh-wink:

Supprimons le pod :

```sh
    kubectl -n monioring delete pod test
```



### Intégration de l'external secret de la Helm Release *'kube-prometheus-stack'*

Nous avançons à petits pas, mais nous avançons!


#### Déploiement de la *Helm release 'kube-prometheus-stack'*
Nous allons maintenant déployer la *Helm Release 'kube-prometheus-stack'* avec les valeurs par défaut (présentes dans le fichier *'values.yaml'*).

Nous irons très vite sur l'installation car nous l'avons déjà couverte dans le howto ['kube-prometheus-stack' managed with FluxCD](https://papafrancky.github.io/Prometheus_and_Grafana/kube-prometheus-stack_managed_with_fluxcd/).

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"


# Répertoire qui contiendra tous les objets Kubernetes :
mkdir -p ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring


# Namespace 'monitoring' :
kubectl create namespace monitoring --dry-run=client -o yaml | grep -vE "creationTimestamp|spec|status" > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/namespace.yaml


# Secret contenant le webhook du salon Discord :
export WEBHOOK_FOO="https://discord.com/api/webhooks/1242845059800633425/zyTYEpNZGf6vpd6C1sRLqeW_TGyFEMP2EM8BXAzockt20eeennkSHDKoO2-UxEG0K4ah"
kubectl -n monitoring create secret generic discord-webhook --from-literal=address=${WEBHOOK_FOO} --dry-run=client -o yaml > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/discord-webhook.secret.yaml


# Notification Discord : définition de l'alert-provider :
flux create alert-provider discord \
  --type=discord \
  --secret-ref=discord-webhook \
  --channel=monitoring \
  --username=FluxCD \
  --namespace=monitoring \
  --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/notification-provider.yaml


# Notification Discord : définition des alertes :
flux create alert discord \
  --event-severity=info \
  --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*,HelmRelease/*' \
  --provider-ref=discord \
  --namespace=monitoring \
  --export >  ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/notification-alert.yaml


# Helm repository :
flux create source helm prometheus-community \
  --url=https://prometheus-community.github.io/helm-charts \
  --namespace=monitoring \
  --interval=1m \
  --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/helm-repository.yaml


# Helm Release :
flux create helmrelease kube-prometheus-stack \
  --source=HelmRepository/prometheus-community \
  --chart=kube-prometheus-stack \
  --namespace=monitoring \
  --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/helm-release.yaml


# Prise en compte des modifications :
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
git add apps/monitoring
git commit -m "feat: init monitoring (namespace, alerting Discord, helm repo and release)."
git push
flux reconcile kustomization flux-system --with-source
```

Tout de suite Discord nous informe du bon déploiement de la Helm release : 

![](./images/discord_helm_release_initial_deployment.png)

Vérifions malgré tout notre installation :

```sh
kubectl get ns monitoring

  # NAME         STATUS   AGE
  # monitoring   Active   49s


kubectl -n monitoring get helmrepositories,helmreleases

  # NAME                                                           URL                                                  AGE   READY   STATUS
  # helmrepository.source.toolkit.fluxcd.io/prometheus-community   https://prometheus-community.github.io/helm-charts   80s   True    stored artifact: revision 'sha256:10ee9c60cbd4bf6ec4d73e99b80c5c54ca1600edfaea593f0f65f2a92ba1b35d'
  # 
  # NAME                                                       AGE   READY   STATUS
  # helmrelease.helm.toolkit.fluxcd.io/kube-prometheus-stack   80s   True    Release reconciliation succeeded


kubectl -n monitoring get all

  # NAME                                                            READY   STATUS    RESTARTS   AGE
  # pod/alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running   0          97s
  # pod/kube-prometheus-stack-grafana-86844f6b47-s7wph              3/3     Running   0          98s
  # pod/kube-prometheus-stack-kube-state-metrics-7c8d64d446-d4fgk   1/1     Running   0          98s
  # pod/kube-prometheus-stack-operator-75fc8896c7-4stcp             1/1     Running   0          98s
  # pod/kube-prometheus-stack-prometheus-node-exporter-xmb9j        1/1     Running   0          98s
  # pod/prometheus-kube-prometheus-stack-prometheus-0               2/2     Running   0          97s
  # 
  # NAME                                                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
  # service/alertmanager-operated                            ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP   97s
  # service/kube-prometheus-stack-alertmanager               ClusterIP   10.96.222.244   <none>        9093/TCP,8080/TCP            98s
  # service/kube-prometheus-stack-grafana                    ClusterIP   10.96.24.39     <none>        80/TCP                       98s
  # service/kube-prometheus-stack-kube-state-metrics         ClusterIP   10.96.99.205    <none>        8080/TCP                     98s
  # service/kube-prometheus-stack-operator                   ClusterIP   10.96.119.105   <none>        443/TCP                      98s
  # service/kube-prometheus-stack-prometheus                 ClusterIP   10.96.52.206    <none>        9090/TCP,8080/TCP            98s
  # service/kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.96.28.184    <none>        9100/TCP                     98s
  # service/prometheus-operated                              ClusterIP   None            <none>        9090/TCP                     97s
  # 
  # NAME                                                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
  # daemonset.apps/kube-prometheus-stack-prometheus-node-exporter   1         1         1       1            1           kubernetes.io/os=linux   98s
  # 
  # NAME                                                       READY   UP-TO-DATE   AVAILABLE   AGE
  # deployment.apps/kube-prometheus-stack-grafana              1/1     1            1           98s
  # deployment.apps/kube-prometheus-stack-kube-state-metrics   1/1     1            1           98s
  # deployment.apps/kube-prometheus-stack-operator             1/1     1            1           98s
  # 
  # NAME                                                                  DESIRED   CURRENT   READY   AGE
  # replicaset.apps/kube-prometheus-stack-grafana-86844f6b47              1         1         1       98s
  # replicaset.apps/kube-prometheus-stack-kube-state-metrics-7c8d64d446   1         1         1       98s
  # replicaset.apps/kube-prometheus-stack-operator-75fc8896c7             1         1         1       98s
  # 
  # NAME                                                               READY   AGE
  # statefulset.apps/alertmanager-kube-prometheus-stack-alertmanager   1/1     97s
  # statefulset.apps/prometheus-kube-prometheus-stack-prometheus       1/1     97s
```

Nous avons déployé la stack avec ses valeurs par défaut. Regardons tout de suite si nous pouvons effectivement nous connecter à Grafana avec le login et le mode de passe par défaut du compte d'administration.

Pour identifier le mot de passe, nous devons récupérer le fichier *'values.yaml'* du **Helm Chart** utilisé :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"
helm show values prometheus-community/kube-prometheus-stack > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.default.values.txt
cat ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.default.values.txt | yq .grafana.adminPassword

  # prom-operator
```

Le mot de passe proposé par défaut pour le compte ***'admin'*** de Grafana est donc : **'prom-operator'**.

!!! Note
    Le fichier *'values.yaml'* récupéré est enregistré en *'.txt'* et non en *'.yaml'* pour qu'il ne soit pas interprété plus tard par FluxCD.

Tentons une connexion à Grafana avec le compte d'administration :

```sh
# Identification du service Grafana (nom et port TCP) :
kubectl -n monitoring get services | grep -i grafana

  # kube-prometheus-stack-grafana                    ClusterIP   10.96.24.39     <none>        80/TCP                       25m

# Port-forwarding
kubectl -n monitoring port-forward service/kube-prometheus-stack-grafana 8080:80
```

Ouvrons enfin un navigateur à l'URL suivante :  ```http://localhost:8080```

![Grafana login page with default credentials](./images/grafana_default_login.png)

!!! Success
    nous accédons à Grafana avec le compte **'admin'** et le mot de passe par défaut **'prom-operator'**  :fontawesome-regular-face-laugh-wink:



#### Modification du mot de passe du compte d'administration de Grafana


Nous allons produire un fichier contenant le seul paramètre que nous souhaitons surcharger aux valeurs par défaut du *Helm chart* :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"
cat << EOF >> ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.txt
grafana:
  adminPassword: my-cleartext-custom-password
EOF
```

Appliquons ce nouveau mot de passe à notre Helm Release déjà déployée :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    flux create helmrelease kube-prometheus-stack \
      --source=HelmRepository/prometheus-community \
      --chart=kube-prometheus-stack \
      --namespace=monitoring \
      --values=${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.txt \
      --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/helm-release.yaml
    ```

=== "helm release avant modification"
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

=== "helm release après modification"
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
      values:
        grafana:
          adminPassword: my-cleartext-custom-password
    ```

Appliquons les changements :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: manually changed the password for grafana's admin account."
git push

flux reconcile kustomization flux-system --with-source
```

Nous observons que les pods Grafana redescendent :

```sh
kubectl -n monitoring get po -w

  # NAME                                                        READY   STATUS    RESTARTS   AGE
  # alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running   0          37m
  # kube-prometheus-stack-grafana-86844f6b47-s7wph              3/3     Running   0          37m
  # kube-prometheus-stack-kube-state-metrics-7c8d64d446-d4fgk   1/1     Running   0          37m
  # kube-prometheus-stack-operator-75fc8896c7-4stcp             1/1     Running   0          37m
  # kube-prometheus-stack-prometheus-node-exporter-xmb9j        1/1     Running   0          37m
  # prometheus-kube-prometheus-stack-prometheus-0               2/2     Running   0          37m
  # kube-prometheus-stack-admission-create-784kh                0/1     Pending   0          0s
  # kube-prometheus-stack-admission-create-784kh                0/1     Pending   0          1s
  # kube-prometheus-stack-admission-create-784kh                0/1     ContainerCreating   0          2s
  # kube-prometheus-stack-admission-create-784kh                1/1     Running             0          18s
  # kube-prometheus-stack-admission-create-784kh                0/1     Completed           0          24s
  # kube-prometheus-stack-admission-create-784kh                0/1     Completed           0          30s
  # kube-prometheus-stack-admission-create-784kh                0/1     Completed           0          30s
  # kube-prometheus-stack-admission-create-784kh                0/1     Completed           0          32s
  # kube-prometheus-stack-admission-create-784kh                0/1     Terminating         0          33s
  # kube-prometheus-stack-admission-create-784kh                0/1     Terminating         0          33s
  # kube-prometheus-stack-grafana-57595d7d49-wrt4s              0/3     Pending             0          0s
  # kube-prometheus-stack-grafana-57595d7d49-wrt4s              0/3     Pending             0          0s
  # kube-prometheus-stack-grafana-57595d7d49-wrt4s              0/3     ContainerCreating   0          1s
  # kube-prometheus-stack-grafana-57595d7d49-wrt4s              2/3     Running             0          30s
  # kube-prometheus-stack-grafana-57595d7d49-wrt4s              2/3     Running             1 (10s ago)   3m13s
  # kube-prometheus-stack-grafana-57595d7d49-wrt4s              3/3     Running             1 (30s ago)   3m33s
  # kube-prometheus-stack-grafana-86844f6b47-s7wph              3/3     Terminating         0             46m
  # kube-prometheus-stack-grafana-86844f6b47-s7wph              0/3     Terminating         0             46m
  # kube-prometheus-stack-grafana-86844f6b47-s7wph              0/3     Terminating         0             46m
  # kube-prometheus-stack-grafana-86844f6b47-s7wph              0/3     Terminating         0             46m
  # kube-prometheus-stack-grafana-86844f6b47-s7wph              0/3     Terminating         0             46m
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     Pending             0             0s
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     Pending             0             0s
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     ContainerCreating   0             0s
  # kube-prometheus-stack-admission-patch-grgxs                 1/1     Running             0             5s
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     Completed           0             6s
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     Completed           0             7s
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     Completed           0             8s
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     Completed           0             9s
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     Terminating         0             9s
  # kube-prometheus-stack-admission-patch-grgxs                 0/1     Terminating         0             9s
```


Discord nous informe également de la bonne mise à jour de la *Helm release* :

![Manual grafana password update](./images/discord_helm_release_cleartext_password.png)


Vérifions la bonne prise en compte de notre mot de passe 'custom' :

```sh
kubectl -n monitoring port-forward service/kube-prometheus-stack-grafana 8080:80
```

Ouvrons un navigateur sur l'adresse de port-forwarding **http://localhost:8080** :

![Grafana login page](./images/grafana_cleartext_custom_password.png)

!!! Success
    nous accédons à Grafana avec le compte **'admin'** et le mot de passe **'my-cleartext-custom-password'**  :fontawesome-regular-face-laugh-wink:



#### Protection du mot de passe avec Vault et External Secrets Operator (ESO)


Jusque-là, rien de bien sorcier : nous avons simplement demandé à FluxCD de déployer une *Helm Release* avec des *custom values*.

Mais nous n'avons pas réglé notre problème : si le mot de passe n'est plus celui par-défaut, il reste en clair dans un fichier au milieu de notre dépôt de code. Et c'est plutôt moche.

Pour le résoudre, nous allons faire usage de l'opérateur **'External Secrets'**.

!!! Info
    https://blog.gitguardian.com/how-to-handle-secrets-in-helm/#external-secrets-operator

    "ESO récupère automatiquement les *'secrets managers'* via des API externes **et les injecte dans Kubernetes Secrets**.

    Contrairement à helm-secrets qui fait référence à des secrets stockés dans des *'Cloud secrets managers'* dans le fichier *'values'*, ESO ne nécessite pas d'inclure *secrets.yaml* dans les *'Helm templates'*. Il utilise une autre ressource personnalisée *'ExternalSecret'*, qui contient la référence aux gestionnaires de secrets dans le Cloud."


!!! Info
    https://external-secrets.io/latest/guides/templating/#templatefrom

    https://fluxcd.io/flux/cmd/flux_create_helmrelease/#options

Il est possible de définir une *'Helm Release'* avec la CLI *'flux'* en surchargeant les *'default values'* à partir d'un objet Kubernetes de type *'Secret'* ou *'ConfigMap'*.


Nous allons (re)définir notre *'Helm Release'* **'kube-prometheus-stack'** en lui indiquant de récupérer ses *'custom values'* depuis un *'Secret Kubernetes'*. 

Ce *'Secret'* (ie. le fichier YAML qui surchargera les valeurs par défaut du *Helm Chart*) aura préalablement été forgé par l'***'External Secrets Operator'*** en récupérant le mot de passe du compte d'administration de Grafana depuis Vault et en l'appliquant à un *template* stocké dans un objet *ConfigMap*. Voyons ça de plus près...

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"

    # Définissons le template à partir duquel le fichier de *custom values* de la *Helm release* sera généré :
    cat << EOF > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.ESO.txt
    grafana:
      adminPassword: {{ .grafanaadminpassword }}
    EOF
    
    # Encodons ce fichier en base 64 :
    cat ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.ESO.txt | base64

      # Z3JhZmFuYToKICBhZG1pblBhc3N3b3JkOiB7eyAuZ3JhZmFuYWFkbWlucGFzc3dvcmQgfX0K
    ```

=== "kube-prometheus-stack.custom.values.ESO.txt"
    ```sh
    grafana:
      adminPassword: {{ .grafanaadminpassword }}

    ```

Définissons les objets nécessaires à la création du *Secret Kubernetes* contenant le fichier *'values.yaml'* qui viendra surcharger les valeurs par éfaut de notre *Helm release :

!!! Warning
    Il est important que la ConfigMap créée ait comme clé **'values.yaml'**, car c'est le fichier attendu par la *Helm Release* pour surcharger ses valeurs par défaut !

2 objets sont nécessaires :

* la ***ConfigMap*** qui contiendra le template de fichier YAML à produire ;
* l'***ExternalSecret*** permettant de générer le *Secret Kubernetes* avec le template et le mot de passe stocké dans Vault.

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"

    cat << EOF > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: kube-prometheus-stack-custom-values-configmap
      namespace: monitoring
    data:
      values.yaml: |
        grafana:
          adminPassword: "{{ .grafanaadminpassword }}"
    
    ---
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: kube-prometheus-stack-custom-values-externalsecret
      namespace: monitoring
    spec:
      secretStoreRef:
        kind: SecretStore
        name: grafana
      target:
        name: kube-prometheus-stack-custom-values
        template:
          engineVersion: v2
          templateFrom:
          - configMap:
              name: kube-prometheus-stack-custom-values-configmap
              items:
              - key: values.yaml
                templateAs: Values
      data:
      - secretKey: grafanaadminpassword
        remoteRef:
          key: kv/monitoring/grafana/admin-account
          property: password
    EOF
    ```

=== "kube-prometheus-stack.custom.values.yaml"
    ```sh
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: kube-prometheus-stack-custom-values-configmap
      namespace: monitoring
    data:
      values.yaml: |
        grafana:
          adminPassword: "{{ .grafanaadminpassword }}"
    
    ---
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: kube-prometheus-stack-custom-values-externalsecret
      namespace: monitoring
    spec:
      secretStoreRef:
        kind: SecretStore
        name: grafana
      target:
        name: kube-prometheus-stack-custom-values
        template:
          engineVersion: v2
          templateFrom:
          - configMap:
              name: kube-prometheus-stack-custom-values-configmap
              items:
              - key: values.yaml
                templateAs: Values
      data:
      - secretKey: grafanaadminpassword
        remoteRef:
          key: kv/monitoring/grafana/admin-account
          property: password
    ```


Il ne nous reste plus qu'à définir notre *'HelmRelease'* en lui indiquant qu'il doit récupérer ses *'custom values'* (values.yaml) depuis un objet Kubernetes de type *'ConfigMap'* que nous venons de définir plus haut :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    flux create helmrelease kube-prometheus-stack \
      --source=HelmRepository/prometheus-community \
      --chart=kube-prometheus-stack \
      --namespace=monitoring \
      --values-from=Secret/kube-prometheus-stack-custom-values \
      --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/helm-release.yaml
    ```
=== "version précédente"
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
      values:
        grafana:
          adminPassword: my-cleartext-custom-password
    ```

=== "nouvelle définition"
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
      valuesFrom:
      - kind: Secret
        name: kube-prometheus-stack-custom-values
    ```



Appliquons les modifications sur notre cluster :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: Helm release is now using vaulted custom values."
git push

flux reconcile kustomization flux-system --with-source
```

Discord nous informe de la bonne mise à jour de notre stack Prometheus :

![Mise à jour de la la Helm release 'kube-prometheus-stack' avec ses 'custom values' récupérées via ESO](./images/discord_helm_release_eso_upgrade.png)


Vérifions la bonne prise en compte du mot de passe stocké dans Vault :

```sh
kubectl -n monitoring port-forward service/kube-prometheus-stack-grafana 8080:80
```

![Mise à jour de la la Helm release 'kube-prometheus-stack' avec ses 'custom values' récupérées via ESO](./images/grafana_vaulted_custom_password.png)


!!! Success
    Nous accédons à Grafana avec le compte **'admin'** et le mot de passe **'my-vaulted-custom-password'** contenu dans Vault !  :fontawesome-regular-face-laugh-wink: