# Protect the secrets of your application using HashiCorp Vault and the External Secrets Operator (ESO)


## Abstract

Notre cluster Kubernetes est opérationnel, avec FluxCD qui gère notamment des repos et des charts Helm.
Nous avons également un service Vault initialisé et descellé.

Nous allons déployer via Flux et à partir de son Helm Chart l'opérateur External Secrets.

Ensuite nous appliquerons la protection des secrets avec Vault via ESO sur une application (MySQL).



### Docs de référence 

- https://external-secrets.io/latest/introduction/getting-started/
- https://external-secrets.io/latest/provider/hashicorp-vault/
- https://github.com/jeffsanicola/vault-policy-guide?tab=readme-ov-file#kv-policies
- https://external-secrets.io/latest/guides/common-k8s-secret-types/
- https://external-secrets.io/latest/guides/templating/
- https://external-secrets.io/latest/provider/hashicorp-vault/#kubernetes-authentication
- https://support.hashicorp.com/hc/en-us/articles/4404389946387-Kubernetes-auth-method-Permission-Denied-error
- https://external-secrets.io/main/guides/templating/#helm

- https://medium.com/@stefanprodan/automate-helm-chart-repository-publishing-with-github-actions-and-pages-8a374ce24cf4
- https://github.com/stefanprodan/helm-gh-pages




### Pré-requis Kubernetes (cluster local) 

Avoir suivi la partie : 'Auto-unsealed Vault Helm deployment managed with FluxCD'. Nous devrions donc déjà avoir à notre disposition :
- un cluster Kind opérationnel, 
- FluxCD déployé,
- Helm installé,
- kubectl installé,
- HashiCorp Vault déployé depuis le Helm Chart officiel en mode auto-unseal via FluxCD.

Commençons par déployer l'External Secrets Operator (ESO)



## Vault

### Déploiement manuel de Vault en mode auto-unseal

    helm install vault hashicorp/vault -f values.yml --dry-run
    kubens vault
    kubectl get all
    
    kubectl logs vault-0
    
 
    kubectl exec -it vault-0 -- vault status
    

### Déploiement de Vault en mode auto-unseal depuis le Helm Chart officiel et piloté par FluxCD

#### alerting Discord


##### création du salon privé sur le client Discord

Création d'un nouveau salon (privé) : 
  - nom : vault-development
  - webhook :
    - nom : FluxCD
    - URL : https://discord.com/api/webhooks/1213494413511237642/7gRzmfYCwDqWwI2D-1jfLZCNvDBotoe_rY2sson57G1Ya40-EtEMWAZy9FsxmjCZTJ4C


##### on place le webhook du salon discord dans un secret kubernetes

    DISCORD_WEBHOOK="https://discord.com/api/webhooks/1213494413511237642/7gRzmfYCwDqWwI2D-1jfLZCNvDBotoe_rY2sson57G1Ya40-EtEMWAZy9FsxmjCZTJ4C"
    kubectl -n vault create secret generic discord-vault-development-webhook --from-literal=address=${DISCORD_WEBHOOK} --dry-run=client -o yaml > products/vault/discord-vault-development-webhook.secret.yaml


##### définition de l'alert-provider Discord

    flux create alert-provider discord \
      --type=discord \
      --secret-ref=discord-webhook \
      --channel=vault-development \
      --username=FluxCD \
      --namespace=vault \
      --export > products/vault/notification-provider.yaml


##### configuration des alertes Discord

    flux create alert discord \
      --event-severity=info \
      --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*,HelmRelease/*' \
      --provider-ref=discord \
      --namespace=vault \
      --export > products/vault/notification-alert.yaml


##### Poussons les manifests sur le repo central pour que FluxCD les gère :

    git add .
    git commit -m 'feat: configuring discord alerting for vault.'
    git push

    flux reconcile kustomization flux-system --with-source
    flux events -w


#### Gestion du repo Helm

    flux create source helm hashicorp \
      --url=https://helm.releases.hashicorp.com \
      --namespace=vault \
      --interval=1m \
      --export > products/vault/helm-repository.yml


#### Déploiement de Vault (helm release)

Recopier le fichier 'values.yaml' en 'custom-values.txt' (FluxCD ne gère que les manifests en YAML)

    flux create helmrelease vault \
      --source=HelmRepository/hashicorp \
      --chart=vault \
      --values=products/vault/custom-values.txt \
      --namespace=vault \
      --export > products/vault/helm-release.yaml

    git status
      # Sur la branche main
      # Votre branche est à jour avec 'origin/main'.
      # 
      # Fichiers non suivis:
      #   (utilisez "git add <fichier>..." pour inclure dans ce qui sera validé)
      # 	products/vault/custom-values.txt
      # 	products/vault/helm-release.yaml
      # 	products/vault/helm-repository.yml

    git add .
    git commit -m 'feat: managing vault helm deployment.'
    git push
    
    kubectl get all
      # NAME          READY   STATUS    RESTARTS   AGE
      # pod/vault-0   1/1     Running   0          17s
      # 
      # NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
      # service/vault            ClusterIP   10.96.102.150   <none>        8200/TCP,8201/TCP   17s
      # service/vault-internal   ClusterIP   None            <none>        8200/TCP,8201/TCP   17s
      # 
      # NAME                     READY   AGE
      # statefulset.apps/vault   1/1     17s
    
    kubectl exec -it vault-0 -- vault status
      # Key                      Value
      # ---                      -----
      # Recovery Seal Type       shamir
      # Initialized              true
      # Sealed                   false
      # Total Recovery Shares    5
      # Threshold                3
      # Version                  1.15.2
      # Build Date               2023-11-06T11:33:28Z
      # Storage Type             file
      # Cluster Name             vault-cluster-6fa0df73
      # Cluster ID               b26de2f1-d9e7-8225-ad55-f114b37eeffb
      # HA Enabled               false

-> C'est GOOD !!!
Note : pas besoin d'initialiser notre Vault car la config a été récupérée depuis le volume du statefulset créé préalablement.



## Déploiement de l'External Secrets Operator (ESO)

### Clonage en local du repository Git de FluxCD

Nous devons ajouter les manifests dans le repo Git piloté par FluxCD.
Pour identifier ce dernier : 

    kubectl get gitrepository -n flux-system -> https://github.com/papaFrancky/kubernetes-development.git

Mettons à jour la copie locale de ce repo : 

    cd ~/code/github/kubernetes-development
    git pull
    mkdir -p products/external-secrets


### Commençons par créer le namespace dédié à ESO

    kubectl create ns external-secrets --dry-run=client -o yaml | \
      grep -vE "creationTimestamp:|^spec:|^status:" > products/external-secrets/namespace.yaml
    kubectl apply -f products/external-secrets/namespace.yaml


### Définissons ensuite le Helm repository pour FluxCD

    flux create source helm external-secrets \
      --url=https://charts.external-secrets.io \
      --namespace=external-secrets \
      --interval=1m \
      --export > products/external-secrets/helm-repository.yml


### Déploiement de l'opérateur External Secrets

    flux create helmrelease vault \
      --source=HelmRepository/external-secrets \
      --chart=external-secrets \
      --namespace=external-secrets \
      --export > products/external-secrets/helm-release.yaml


### Mise à jour du repo Git distant pour prise en compte par FluxCD

    git add .
    git commit -m 'feat: installing External Secrets Operator (ESO.)'
    git push

    flux reconcile kustomization flux-system --with-source
    flux events -w

    kubectl -n external-secrets get helmrepo,helmrelease

      # NAME                                                       URL                                  AGE     READY   STATUS
      # helmrepository.source.toolkit.fluxcd.io/external-secrets   https://charts.external-secrets.io   9m27s   True    stored artifact:       # revision 'sha256:35986103ade32186cf3d151ce19bae8939cfcbf7f64011cf5c5678ad2c8df860'
      # 
      # NAME                                       AGE     READY   STATUS
      # helmrelease.helm.toolkit.fluxcd.io/vault   9m27s   True    Helm install succeeded for release external-secrets/vault.v1 with chart external-secrets@0.9.13



## Configuration de Vault

Dans la partie 'helm_vault_auto-unseal', nous avons décrit l'installation de Vault en mode descellé à partir d'un Helm Chart et piloté par FluxCD.

Lors de l'initialisation de Vault, nous avions récupéré le 'root token' dont nous aurons besoin pour la suite des opérations :

    Initial Root Token: hvs.G145zNl012ApNOap3sn2zhIG



### Activation de l'authentification Kubernetes sur Vault

    kubectl -n vault exec -it vault-0 -- sh    # ouverture d'une session shell sur le pod vault-0
    vault login hvs.G145zNl012ApNOap3sn2zhIG   # login à Vault avec le token root

    vault auth enable kubernetes
    vault auth list
    exit


### Configuration of the Kubernetes authentication

    # source: https://developer.hashicorp.com/vault/docs/auth/kubernetes#kubernetes-auth-method
    #
    #   Use local service account token as the reviewer JWT
    #   
    #   When running Vault in a Kubernetes pod the recommended option is to use the pod's local service account token.
    #   Vault will periodically re-read the file to support short-lived tokens. To use the local token and CA certificate,
    #   omit token_reviewer_jwt and kubernetes_ca_cert when configuring the auth method. Vault will attempt to load them
    #   from token and ca.crt respectively inside the default mount folder /var/run/secrets/kubernetes.io/serviceaccount/.


    kubectl -n vault exec -it vault-0 -- sh    # ouverture d'une session shell sur le pod vault-0
    vault login hvs.G145zNl012ApNOap3sn2zhIG   # login à Vault avec le token root

    vault write auth/kubernetes/config kubernetes_host=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}
    vault read auth/kubernetes/config
    exit


Vault est désormais configuré pour permettre à notre cluster Kubernetes de s'y authentifier.
Les pods utiliseront leur propre (short-lived) token JWT, raison pour laquelle nous n'avons pas précisé dans la dernière commande les paramètres *token_reviewer_jwt* et *kubernetes_ca_cert*.


## Déploiement de l'application 'silly-webapp'

Nous prendrons comme exemple le déploiement d'une appli 'custom' qui affichera des secrets dans une page web. Le Helm Chart attend que nous renseignions les variables suivantes :

    BGCOLOR:  DarkOliveGreen
    COLOR:    PaleGreen
    LOGIN:    admin
    PASSWORD: m%K@W5JeVyQ4jik2@#Lv3fV@D7PGPv

Nous prévoyons de définir un service account nommé 'silly-webapp', de déployer l'application dans un namespace également nommé 'silly-webapp'.
Mais commençons par préparer Vault à héberger et délivrer les secrets à l'application.


### Opérations sur Vault

Nous utiliserons le KVv2 engine (moteur de clés/valeurs).

    # Login avec le root token sur Vault (dans le pod vault-0) :
    kubectl -n vault exec -it vault-0 -- sh    # ouverture d'une session shell sur le pod vault-0
    vault login hvs.G145zNl012ApNOap3sn2zhIG   # login à Vault avec le token root

    # Activation de KVv2 secrets engine :
    vault secrets enable -version=2 kv
    vault secrets list

    # Ecriture des secrets dans le path /kv/silly-webapp :
    vault kv put -mount=kv silly-webapp \
      BGCOLOR=DarkOliveGreen \
      COLOR=PaleGreen \
      LOGIN=admin \
      PASSWORD=m%K@W5JeVyQ4jik2@#Lv3fV@D7PGPv
    vault kv get -mount kv silly-webapp

    # Ecriture d'une policy d'accès en lecture sur le path /kv/silly-webapp :
    vault policy write kv-silly-webapp-read - << EOF
    path "kv/metadata/silly-webapp" {
      capabilities = ["list","read"]
    }
    path "kv/data/silly-webapp" {
      capabilities = ["list","read"]
    }
    EOF
    vault policy read kv-silly-webapp-read

    # Fin de session
    exit

    # Définition d'un rôle autorisant le service-account 'silly-webapp' du namespace 'silly-webapp' de lire les secrets précédents dans Vault :
    vault write auth/kubernetes/role/silly-webapp \
        bound_service_account_names=silly-webapp \
        bound_service_account_namespaces=silly-webapp \
        policies=kv-silly-webapp-read \
        ttl=1h
    vault read auth/kubernetes/role/silly-webapp


### Création du Helm Chart pour l'application 'silly-webapp'

#### L'application en question

##### Création 'manuelle'

Notre application sera très simple : un serveur web Apache qui affiche une page web contenant nos secrets protégés dans Vault.

Pour ce faire, nous devrons créer :
* 1 namespace dédié;
* 1 service account;
* 1 ClusterRoleBinding affectant au service account le ClusterRole qui permette à Kubernetes de déléguer les contrôles d'authentification et d'autorisation à l'application (cf. doc : https://kubernetes.io/docs/reference/access-authn-authz/rbac/#other-component-roles)
* 1 Deployment qui lancera 1 pod avec pour image Apache 2.4;
* 1 SecretStore ouvrant l'accès à Vault au service account de l'application;
* 1 ExternalSecret qui génèrera la page web affichée par l'application avec les secrets récupérés depuis Vault;
* 1 service pour exposer l'application.

Les manifests YAML se trouvent dans le répertoire ./silly-webapp/manifests


Testons l'application en la déployant à la main : 

    cd silly-webapp/manifests
    kubectl apply -f namespace.yaml
    kubectl apply -f serviceaccount.yaml
    kubectl apply -f clusterrolebinding.yaml
    kubectl apply -f secretstore.yaml
    kubectl apply -f externalsecret.yaml
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    
    kubectl port-forward service/silly-webapp 8080:80
    curl http://localhost:8080 
    <table border=1 style="background-color:DarkOliveGreen;color:PaleGreen"
      <tr>
        <th>SECRET</th>
        <th>VALUE</th>
      </tr>
      <tr>
        <td>BGCOLOR</td>
        <td>DarkOliveGreen</td>
      </tr>
      <tr>
        <td>COLOR</td>
        <td>PaleGreen</td>
      </tr>
      <tr>
        <td>LOGIN</td>
        <td>admin</td>
      </tr>
      <tr>
        <td>PASSWORD</td>
        <td>m%K@W5JeVyQ4jik2@#Lv3fV@D7PGPv</td>
      <tr>
    </table>

Top, ça marche !
Faison le ménage.

    kubectl delete ns silly-webapp
    kubectl get clusterrolebinding external-secret-silly-webapp

##### Packaging de l'application avec Helm

Sortons du répertoire contenant les manifests :

    cd ...
    pwd

Nous allons créer un Helm Chart from scratch :

    # Création d'un Helm Chart par défaut 
    helm create silly-webapp
    
    # Remplacement des templates par les manifests YAML que nous venons de produire :
    rm -rf silly-webapp/templates/*.yaml
    cp manifests/*.yaml silly-webapp/templates/.
    helm instal silly-webapp ./silly-webapp --dry-run


        silly-webapp
        ├── Chart.yaml
        ├── charts
        ├── templates
        │   ├── clusterrolebinding.yaml
        │   ├── deployment.yaml
        │   ├── externalsecret.yaml
        │   ├── namespace.yaml
        │   ├── secret.yaml
        │   ├── secretstore.yaml
        │   ├── service.yaml
        │   ├── serviceaccount.yaml
        │   └── tests
        │       └── test-connection.yaml
        └── values.yaml


Le Helm Chart fonctionnera en l'état. Mais il est plus intéressant de 'templatiser' les manifests si l'on souhaite pouvoir créer des Helm releases différentes à partir du même Helm chart.
Cette partie sort du périmètre de cete doc. Je laisse les manifests originaux dans le répertoire 'manifests' et le Helm chart 'templatisé' dans le répertoire 'silly-webapp', pour comparer l'avant et l'après.


TODO : 
Expliquer comment on passe des manifests 'manuels' à des templates variabilisés Helm.
Détailler la particularité de Helm avec External Secrets (lequel des 2 doit interpréter les variables et comment).

Ensuite :

    helm install silly-webapp ./silly-webapp --create-namespace
    helm test silly-webapp -n silly-webapp

    helm package ./silly-webapp
    Successfully packaged chart and saved it to: (...)/silly-webapp-0.1.0.tgz




## Création d'un repository de Helm Charts avec GitHub et GitHub Actions
Maintenant que nous avons créé notre Helm Chart, nous allons le publier pour pouvoir le rendre utilisable autrement qu'en local.

### Création d'un GitHub Repository dédié à nos Helm harts

Une fois logué sur le site GitHub, créer un nouveau repository :
* name : papafrancky/helm-charts
* accessibility : public

Nous allons placer les Helm Charts sous la forme de manifests dans un répertoire 'charts', et ces mêmes charts packagés en .tgz dans un répertoire 'packages'.
La page d'index du repo Helm (index.yaml) se trouvera donc dans le répertoire 'packages' et sera accessible à l'adresse suivante : 

    https://raw.githubusercontent.com/papafrancky/helm-charts/main/packages/index.yaml

Nous préciserons cela dans le README du repository.

    mkdir ~/code/github/helm-charts
    cd ~/code/github/helm-charts
    mkdir charts templates
    touch charts/.gitkeep packages/.gitkeep

    printf "# Papa Francky's Helm Charts Repository\n\nTo add the papaFrancky Helm repository :\n\n    helm repo add papafrancky https://raw.githubusercontent.com/papafrancky/helm-charts/main/packages\n\nTo upgrade an existing installation :\n\n    helm repo upgrade papafrancky\n\nTo search for stable release versons matching the keyword "papafrancky" :\n\n    helm search repo papafrancky\n" > README.md

### La GitHub Action

    cd ~/code/github/helm-charts
    mkdir -p .github/{workflows,scripts}

    cat << EOF >> .github/workflows/helmchart_release.yml
    name: Helm Chart Release
    
    on:
      push:
        branches: [ "main" ]
        paths: [ 'charts/**' ]
      # Allows you to run this workflow manually from the Actions tab
      workflow_dispatch:
    
    jobs:
      helm_repo_update:
        runs-on: ubuntu-latest
        steps:

          - uses: actions/checkout@v3
    
          - name: Helm tool installer
            uses: Azure/setup-helm@v4
            with:
              version: latest
    
          - name: Helm packaging and reposotiry indexing
            run: ./.github/scripts/helm_packaging_and_repo_indexing.sh     
    
          - name: GIT Commit and Push
            run: |
              cd ${GITHUB_WORKSPACE}
              git config user.name "${GITHUB_ACTOR}"
              git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
              git add .
              git commit -a -m "Helm packages publication is up-to-date."
              git push
    EOF
    
    vi .github/scripts/helm_packaging_and_repo_indexing.sh

      #!/bin/sh
      
      HelmChartsDir="${GITHUB_WORKSPACE}/charts"       # Helm Charts Directory (files)
      HelmPackagesDir="${GITHUB_WORKSPACE}/packages"   # Helm packaged Charts (.tgz)
      
      # Package Helm Charts
      ChartsList=$( find ${HelmChartsDir} -type d -maxdepth 1 | grep -v charts$ )
      printf "Packaging the Helm charts ...\n"
      for Chart in $( echo ${ChartsList} ); do
        helm package ${Chart} --destination ${HelmPackagesDir}
      done

      # Repo Index
      printf "Indexing the Helm charts ...\n"
      helm repo index ${HelmPackagesDir}

    chmod +x .github/scripts/helm_packaging_and_repo_indexing.sh



Notre GitHub Action va récupérer le contenu de notre repo sur le runner, installer Helm, packager les Charts en fichiers .tgz et créer un helm repository index.
Pour intégrer les nouveaux fichiers créés à notre code, la GitHub Action devra les pousser sur notre repo de code.
Nous devons modifier les paramètres de notre repo pour autoriser les GitHub Actions à écrire :

https://github.com/papafrancky/helm-charts/settings/actions
-> Workflow permissions : Read and write permissions 


    git init
    git add .
    git commit -m "first commit"
    git branch -M main
    git remote add origin git@github.com:papafrancky/helm-charts.git
    git push -u origin main


### Copie de notre Helm Chart 'silly-webapp' dans notre Helm repo

    cp -r ../../tmp/protect_secrets_using_Vault_and_External_Secrets_Operator/silly-webapp/silly-webapp charts
    tree
        .
        ├── README.md
        ├── charts
        │   └── silly-webapp
        │       ├── Chart.yaml
        │       ├── charts
        │       ├── templates
        │       │   ├── NOTES.txt
        │       │   ├── clusterrolebinding.yaml
        │       │   ├── deployment.yaml
        │       │   ├── externalsecret.yaml
        │       │   ├── secretstore.yaml
        │       │   ├── service.yaml
        │       │   ├── serviceaccount.yaml
        │       │   └── tests
        │       │       └── test-connection.yaml
        │       └── values.yaml
        └── packages

    git add .
    git commit -m 'added silly-webapp helm chart.'
    git push

    -> la GitHub Action s'exécute, créé le package silly-webapp-0.1.0.tgz, met l'index à jour.
    git pull
    tree
      .
      ├── README.md
      ├── charts
      │   └── silly-webapp
      │       ├── Chart.yaml
      │       ├── charts
      │       ├── templates
      │       │   ├── NOTES.txt
      │       │   ├── clusterrolebinding.yaml
      │       │   ├── deployment.yaml
      │       │   ├── externalsecret.yaml
      │       │   ├── secretstore.yaml
      │       │   ├── service.yaml
      │       │   ├── serviceaccount.yaml
      │       │   └── tests
      │       │       └── test-connection.yaml
      │       └── values.yaml
      └── packages
          ├── index.yaml
          └── silly-webapp-0.1.0.tgz

    cat packages/index.yaml

        apiVersion: v1
        entries:
          silly-webapp:
          - apiVersion: v2
            appVersion: "2.4"
            created: "2024-03-14T20:10:32.534365859Z"
            description: A simple web application exposing credentials retrieved from a Vault
              instance through the External Secrets Operator (ESO).
            digest: 95e29f48321a31eee8793ccc94a0da08dad9ddc7bd36fb6730f8f30e0bb59de8
            name: silly-webapp
            type: application
            urls:
            - silly-webapp-0.1.0.tgz
            version: 0.1.0
        generated: "2024-03-14T20:10:32.53390382Z"


### Utilisation de notre Helm repo

Pour cela, rien de plus simple, il suffit de suivre les indications dans le README.md :

    helm repo add papafrancky https://raw.githubusercontent.com/papafrancky/helm-charts/main/packages
    helm search repo papafrancky

        NAME                    	CHART VERSION	APP VERSION	DESCRIPTION
        papafrancky/silly-webapp	0.1.0        	2.4        	A simple web application exposing credentials r...


    helm test silly-webapp
    
        NAME: silly-webapp
        LAST DEPLOYED: Mon Mar 11 21:31:21 2024
        NAMESPACE: silly-webapp
        STATUS: deployed
        REVISION: 1
        TEST SUITE:     silly-webapp-test-connection
        Last Started:   Sat Mar 16 11:15:43 2024
        Last Completed: Sat Mar 16 11:15:46 2024
        Phase:          Succeeded
        NOTES:
        'silly-webapp' really is... a silly webapp : it consists in a simple Apache 2.4 webserver exposing a webpage     which     contains credentials retrieved from Vault through the 'External Secrets Operator (ESO)'.
        
        To see it in action :
        
            kubectl --namespace silly-webapp port-forward service/silly-webapp 8080:80
            Visit http://127.0.0.1:8080 to see the secrets.
        
L'application est correctement déployée et fonctionne comme attendu.
Nous pouvons désormais la confier à FluxCD.

Commençons par faire du ménage :

    kubectl delete ns silly-webapp

### Gestion de 'silly-webapp' par FluxCD

#### alerting Discord

##### création du salon privé sur le client Discord

Création d'un nouveau salon (privé) : 
  - nom : silly-webapp-development
  - webhook :
    - nom : FluxCD
    - URL : https://discord.com/api/webhooks/1218504455075401788/2NJmyKGT86cz6dC18-o3D2B9d4dT69OUzLLtnHZZqIiZeUP4zHfNxxV-b8UBKQVXGicM


##### on place le webhook du salon discord dans un secret kubernetes

    # Travaillons sur la copie locale du repo git de notre cluster de développement
    cd ~/code/github/kubernetes-development
    git pull
    mkdir products/silly-webapp

    # Création du namespace de l'application :
    kubectl create ns silly-webapp --dry-run=client -o yaml | grep -vE "creationTimestamp|spec|status" > products/silly-webapp/namespace.yaml
    kubectl apply -f products/silly-webapp/namespace.yaml

    # Création du secret contenant le webhook du salon Discord :
    DISCORD_WEBHOOK="https://discord.com/api/webhooks/1218504455075401788/2NJmyKGT86cz6dC18-o3D2B9d4dT69OUzLLtnHZZqIiZeUP4zHfNxxV-b8UBKQVXGicM"
    kubectl -n silly-webapp create secret generic discord-webhook --from-literal=address=${DISCORD_WEBHOOK} --dry-run=client -o yaml > products/silly-webapp/discord-webhook.secret.yaml

##### définition de l'alert-provider Discord

    flux create alert-provider discord \
      --type=discord \
      --secret-ref=discord-webhook \
      --channel=silly-webapp-development \
      --username=FluxCD \
      --namespace=silly-webapp \
      --export > products/silly-webapp/notification-provider.yaml

##### configuration des alertes Discord

    flux create alert discord \
      --event-severity=info \
      --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*,HelmRelease/*' \
      --provider-ref=discord \
      --namespace=silly-webapp \
      --export > products/silly-webapp/notification-alert.yaml

##### Poussons les manifests sur le repo central pour que FluxCD les gère :

    git add products/silly-webapp
    git commit -m 'feat: configuring discord alerting for silly-webapp.'
    git push

    flux reconcile kustomization flux-system --with-source
    flux events -w

#### Gestion du repo Helm

    flux create source helm papafrancky \
      --url=https://raw.githubusercontent.com/papafrancky/helm-charts/main/packages \
      --namespace=silly-webapp \
      --interval=1m \
      --export > products/silly-webapp/helm-repository.yml


#### Déploiement de silly-webapp (helm release)

Nous installerons l'application avec les paramètres par défaut, raison pour laquelle le paramètre --values est commenté.

    flux create helmrelease silly-webapp \
      --source=HelmRepository/papafrancky \
      --chart=silly-webapp \
      #--values=products/silly-webapp/custom-values.txt \
      --namespace=silly-webapp \
      --export > products/silly-webapp/helm-release.yaml


    git status
    git add products/silly-webapp
    git commit -m 'feat: managing silly-webapp helm deployment.'
    git push

    flux reconcile kustomization flux-system --with-source
    flux events -w
    helm test silly-webapp
    kubectl --namespace silly-webapp port-forward service/silly-webapp 8080:80


Tout fonctionne comme attendu ! ^^



## Protection de webhook utilisé pour la notification Discord

Si on regarde bien, nous avons 1 secret qui n'est pas 'protégé' dans Vault : discord-webhook (le webhook utilisé pour nos notifications Discord)

Commençons par créer insérer ce secret dans Vault.


### Ajout du webhook dans Vault

    # Login avec le root token sur Vault (dans le pod vault-0) :
    kubectl -n vault exec -it vault-0 -- sh    # ouverture d'une session shell sur le pod vault-0
    vault login hvs.G145zNl012ApNOap3sn2zhIG   # login à Vault avec le token root

    # Ecriture des secrets dans le path /kv/silly-webapp/discord-notifications :
    vault kv put -mount=kv silly-webapp/discord-notifications \
      WEBHOOK=https://discord.com/api/webhooks/1218504455075401788/2NJmyKGT86cz6dC18-o3D2B9d4dT69OUzLLtnHZZqIiZeUP4zHfNxxV-b8UBKQVXGicM
    vault kv get -mount kv silly-webapp/discord-notifications


### Modification de la Vault policy pour silly-webapp

    # Nous devons modifier la policy d'accès en lecture sur le path /kv/silly-webapp qui était trop restrictive :
    vault policy write kv-silly-webapp-read - << EOF
    path "kv/metadata/silly-webapp" {
      capabilities = ["list","read"]
    }
    path "kv/data/silly-webapp" {
      capabilities = ["list","read"]
    }
    path "kv/metadata/silly-webapp/*" {
      capabilities = ["list","read"]
    }
    path "kv/data/silly-webapp/*" {
      capabilities = ["list","read"]
    }    
    EOF

    vault policy read kv-silly-webapp-read

    # Fin de session
    exit


    cat << EOF >> products/silly-webapp/discord-webhook.externalsecret.yaml
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: discord-webhook
      namespace: silly-webapp
    spec:
      secretStoreRef:
        name: vault
        kind: SecretStore
      target:
        name: discord-webhook
      data:
      - secretKey: discord-webhook
        remoteRef:
          key: silly-webapp/discord-notifications
          property: WEBHOOK
    EOF
    
    k delete secret discord-silly-webapp-development-webhook
    rm -f products/silly-webapp/discord-webhook.secret.yaml

Pour tester : 

    helm uninstall silly-webapp

-> Si lors du reconcile on est alerté par Discord que le Helm Release sille-webapp est réinstallée, tout aura bien marché.

    k get externalsecret,secret
    
        NAME                                                 STORE   REFRESH INTERVAL   STATUS         READY
        externalsecret.external-secrets.io/discord-webhook   vault   1h0m0s             SecretSynced   True
        externalsecret.external-secrets.io/webindex          vault   1h                 SecretSynced   True
        
        NAME                                              TYPE                 DATA   AGE
        secret/discord-silly-webapp-development-webhook   Opaque               1      2m38s
        secret/discord-webhook                            Opaque               1      35m
        secret/sh.helm.release.v1.silly-webapp.v1         helm.sh/release.v1   1      2m24s
        secret/webindex                                   Opaque               1      2m24s

L'external secret 'discord-webhook' aura créé un secret 'discord-webhook'.
Vérifions qu'il correspond bien à notre webhook :

    k get secret discord-webhook -o yaml | yq .data | awk '{print $2}' | base64 -d

        https://discord.com/api/webhooks/1218504455075401788/2NJmyKGT86cz6dC18-o3D2B9d4dT69OUzLLtnHZZqIiZeUP4zHfNxxV-b8UBKQVXGicM%

C'est bon ^^