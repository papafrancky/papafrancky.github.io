# Déploiement de Vault (auto-unsealed) et ESO via FluxCD sur un cluster KinD

## Abstract

Ce howto fait suite au howto ['kube-prometheus-stack' managed with FluxCD](https://papafrancky.github.io/Prometheus_and_Grafana/kube-prometheus-stack_managed_with_fluxcd/).

Jusqu'à présent, nous disposons d'un cluster KinD piloté par FluxCD et sur lequel nous avons déployé une stack de monitoring Prometheus complète. Nous continuons l'enrichissement de notre cluster en lui ajoutant cette fois-ci une solution de protection de nos données sensibles (ie. des _*'secrets'*_) : HashiCorp Vault OSS.

Pour interagir avec ce dernier, nous déploierons également l'**External Secrets Operator** (ESO).

Pour illustrer le bon fonctionnement de ces outils, nous confierons à Vault le login et le mot de passe du compte d'administration de Grafana.

!!! tip
    Nous nous inspirerons fortement des _**howtos**_ que nous avons déjà produits sur **Vault** et **External Secrets Operator**.



## Préparatifs

Nous commencerons par préparer notre environnement local, un namespace dédié à la gestion des secrets, l'alerting Discord et définir les dépôts Helm avant de nous atteler à Vault et ESO.


### Préparation de notre environnement de développement (local)

```sh
# Répertoire accueillant nos dépôts Git en local
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

# Mise à jour des copies locales des dépôts dédiés à FluxCD et aux applications qu'il gère
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-apps   && git pull
cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd && git pull

# Création d'un répertoire dédié à la gestion des secrets
mkdir -p ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault
```



### Namespace dédié à la gestion des secrets

```sh
kubectl create ns vault --dry-run=client -o yaml > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault/namespace.yaml
kubectl apply -f ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault/namespace.yaml
```


### Alerting Discord

Nous passerons vite sur cette partie, car nous l'avons déjà bien documentée dans les howtos précédents.

Nous utiliserons notre serveur Discord _*'k8s-kind'*_ déjà existant et partirons du principe que vous avez déjà créé un salon textuel privé nommé **'vault'** ainsi qu'un webhook **'FluxCD'** associé.



#### webhook du salon Discord

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    export WEBHOOK_VAULT="https://discord.com/api/webhooks/1243971721745399809/G49lALsZgmXriz5xzJ0GqJ9WizUt9ADc38VrVN_yjENerABboe8k_JGcfG8MXSsiTLyJ"
    
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    kubectl -n vault create secret generic discord-webhook --from-literal=address=${WEBHOOK_VAULT} --dry-run=client -o yaml > apps/vault/discord-webhook.secret.yaml
    kubectl apply -f apps/vault/discord-webhook.secret.yaml
    ```

=== "'discord-webhook' secret"
    ```sh
    apiVersion: v1
    data:
      address: aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTI0Mzk3MTcyMTc0NTM5OTgwOS9HNDlsQUxzWmdtWHJpejV4ekowR3FKOVdpelV0OUFEYzM4VnJWTl95akVOZXJBQmJvZThrX0pHY2ZHOE1YU3NpVEx5Sg==
    kind: Secret
    metadata:
      creationTimestamp: null
      name: discord-webhook
      namespace: vault
    ```



#### Alert-provider

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
      --export > apps/vault/notification-provider.yaml
    ```

=== "'discord-webhook' alert-provider"
    ```sh
    ---
    apiVersion: notification.toolkit.fluxcd.io/v1beta2
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



#### Alert

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    flux create alert discord \
      --event-severity=info \
      --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*,HelmRelease/*' \
      --provider-ref=discord \
      --namespace=vault \
      --export > apps/vault/notification-alert.yaml
    ```

=== "'discord' alert"
    ```sh
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



#### Activation de l'alerting

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: setting up 'vault' Discord alerting."
git push

flux reconcile kustomization flux-system --with-source
```

Vérification :

=== "code"
    ```sh
    kubectl -n vault get providers,alerts
    ```

=== "output"
    ```sh
    NAME                                              AGE   READY   STATUS
    provider.notification.toolkit.fluxcd.io/discord   70s   True    Initialized
    
    NAME                                           AGE   READY   STATUS
    alert.notification.toolkit.fluxcd.io/discord   70s   True    Initialized
    ```



### Helm repositories

Nous allons définir au niveau de FluxCD les _*'Helm registries'*_ pour installer sur notre cluster l'**External Secrets Operator** et **HashiCorp Vault OSS** :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    flux create source helm hashicorp \
      --url=https://helm.releases.hashicorp.com \
      --namespace=vault \
      --interval=1m \
      --export > apps/vault/vault.helm-repository.yaml

    flux create source helm external-secrets \
      --url=https://charts.external-secrets.io \
      --namespace=vault \
      --interval=1m \
      --export > apps/vault/external-secrets.helm-repository.yaml
    ```

=== "'hashicorp' helm repository"
    ```sh
    ---
    apiVersion: source.toolkit.fluxcd.io/v1beta2
    kind: HelmRepository
    metadata:
      name: hashicorp
      namespace: vault
    spec:
      interval: 1m0s
      url: https://helm.releases.hashicorp.com
    ```

=== "'external-secrets' helm repository"
    ```sh
    ---
    apiVersion: source.toolkit.fluxcd.io/v1beta2
    kind: HelmRepository
    metadata:
      name: external-secrets
      namespace: vault
    spec:
      interval: 1m0s
      url: https://charts.external-secrets.io
    ```

### Prise en compte des changements

Il est temps de soumettre nos changements à FluxCD :


```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: preparing vault -> discord alerting, helm repositories." 
git push

flux reconcile kustomization flux-system --with-source
```

Discord nous informe tout de suite de la bonne création du _*'Helm registry'*_ :

![Discord initialisation du namespace 'vault'](./images/discord_vault_init.png)



### Google Cloud Platform

Le mécanisme d'auto-unseal de Vault repose sur les service d'un Cloud Service Provider (CSP). Notre choix s'est porté sur Google Cloud Platform (CGP) mais tout autre CSP proposant un service de gestion de clés aurait pu faire l'affaire.


#### Compte GCP, projet, etc...

Nous disposons d'un compte GCP et avons préalablement créé un projet dont voici les informations essentielles :

|KEY|VALUE|
|---:|---|
|Project Name|vault|
|Project ID|vault-415918|
|||



#### Activation des APIs

Pour consommer les services GCP, il faut activer leurs APIs.

!!! tip
    APIs & Services > Enabled APIs & Services > + ENABLE APIS AND SERVICES

|APIs activées|
|---|
|Cloud Key Management Service (KMS) API|
|Compute Engine API|



#### Service-account

Vault utilisera un service-account GCP (en fournissant ses credentials) qui disposera des droits d'accès à une clé hébergée chez GCP (via Key Management Service KMS). Paramétré en mode auto-unseal, Vault se servira de cette clé comme "root key" qui protège l'"encryption key".


##### Service-account

!!! tip
    IAM & Admin > Service Accounts > + CREATE SERVICE ACCOUNT

|KEY|VALUE|
|---|---|
|Name|k8s-kind-vault|
|Email|k8s-kind-vault@vault-415918.iam.gserviceaccount.com|
|Key|yes|



##### Service-account key

Vault aura besoin de la clé privée du service account créé précédemment pour consommer les APIs de GCP avec les privilèges associés à ce compte.

!!! tip
    IAM & Admin > Service Accounts > KEYS > ADD KEY (key type: JSON)

La création d'une clé déclenche le téléchargement d'un fichier texte au format JSON que nous placerons temporairement à l'endroit suivant : **~/tmp/k8s-kind-vault.creds.json**

=== "service-account key"
    ```json
    {
      "type": "service_account",
      "project_id": "vault-415918",
      "private_key_id": "75f932e7ca96f31247f5328055a7d7d3802bab92",
      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDIGOQ0njkgaciE\nNZfVZ0yObQ9nt8l7CzqCeKPcmk5gaxPxm1/fiXhjynqxdcgpzppzJE5gLA3uwhOf\nVmRVrF9aobinFXZ8iKVbi6tSPSnxEPXreOuhuwicFfsX81UeG    +MozSodj04nKKuL\nmJdqkesTuRcFRu/2hSojtOG1dyyaOQSZ1hDCRq+dlnoVaJR7ADGJOvwuoPs1EeHo\nnRavuvTGsSDHqLQwUe20sfTJSVKTXF1S21RDmpxZqEHrETHNzHc8irMMvUteDA28\nLw6lIy9Ahn6+nxtrBRGyv5K7l1LQg4mdYkAw/REOW83UEWff2Job6v/VWm1lwef8\nDJsytsPbAgMBAAECggEAATxU+QNa1qv5tJhy/    N9ik8lxfDJXWuWYbQvWiFs4u0Gy\nmIvK8ergaU5+FOdTKB3LOGDPKWG8Q7gxGWaoLWRoZla9Cwn1mzb8PUnFqO3sn2HE\nt5TUlWXQJMxUPMV7xhSKSwIRVvEbLuAm/edE5vbck8Z11hOBpCPxhj812sJQEuoD\nkd0NwiqBtCjJRz/S7f9c6z9zu3RxhqppleqFG5L3T50OCpJxIIDC976SQlkCeml6\nHxGScFZjua    +VTcZVuM8NVVx71iRVUi77DTBqGaCMGjiWo4oxo9YyhD62q7oBdRu9\nfbS3beSlr1scijFwNr0uzcjpowCz+OjUXzhGds//OQKBgQDvCKkhMDHxF5deoeCf\n5ib+ywIeLRWDwZB8249P/WNhiILvsW144iBuWwZFGJ2N/FMulC7MKlVFsfKrlvMm\nedLh+/    LG9xmxzpOUDvtKPXzwWqvt70hhv4Oo1rpm7LkXfZVxUctFPEzToxqiN56I\nxtDso30w8oXJo2apb7ro4bHd5wKBgQDWTLzDPmraS6xUFjYQKjcMZ2tNe7IQXiDR\nXqz7UbJfdZzsvKWCRpU7cDEPhtfimFRMfaAaF9feVV+ocip4qt3uoatQzjwcn0Ys\nwpg/0LG2Uwcc+RoohtSXenZzMB+J3jxsJD2dlgeG4fC47YTG8uqwYe1QysJ    +DTZg\n8gVEpmRj7QKBgCWG9Y6ZU23nZ0NbJLnV109vLcDxEQyjafzAN6q2PFEGro/VCjvN\nPIw2zDAy4iF1eNW6O/Kfvs13V4Lq6veibqI9/OqRxr3skazQAVGxf5j4kz+Crply\nCMiMFa2tAo4WkEy/K6uOAP3FAJxxIPmWRRyxuijiGnECr05wlSaUsGkHAoGAe0Wr\nM9i82JO9LqWUNdpCzkTTab/k3xt2X1nJwcvuApGCUn/    16Sm3AHj6D8duei9MFrAR\nH9FlYMTVgO0jV0Ra48Fl7dakp4ZLdMX/lH31LD84kUcN8BAXTIeqiXo+Oi13rnFu\nbC74Z3Oi6I3g2hy0OgAq5lWsaZwqErxFoYbhqsUCgYEAtpoLNzhMqGj31yUUP05p\n2mDn62OKfwtO0pHqv++unJ9edzjGHBGlVcHk4E2TvagHdaWLBhkyhD4dEvTHAW4G\nIJ5Xf4FgdAeh0ypdM7g7UlluatQC/2z    +S32jlTATpx412mq1SXWJy6AzXHPFdDv8\nm3ADd7UI+ACitGZW+vFSlmQ=\n-----END PRIVATE KEY-----\n",
      "client_email": "k8s-kind-vault@vault-415918.iam.gserviceaccount.com",
      "client_id": "117555050512332525003",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/k8s-kind-vault%40vault-415918.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    }
    ```


Nous allons tout de suite intégrer cette clé sous la forme de _*secret Kubernetes*_ dans le namespace dédié à Vault :

```sh
kubectl -n vault create secret generic kms-sa --from-file=/Users/franck/tmp/k8s-kind-vault.creds.json
kubectl -n vault get secret kms-sa -o jsonpath='{.data.k8s-kind-vault\.creds\.json}' | base64 -d
kubectl -n vault get secret kms-sa -o jsonpath='{.data.k8s-kind-vault\.creds\.json}' | base64 -d | yq -r '.private_key'
```


#### KMS key

Il faut d'abord créer un trousseau (ie. un _*'key ring'*_) avant d'y ajouter une clé.


##### Key ring

!!! tip
    Security > Key Management > + CREATE KEY RING

|KEY|VALUE|
|---|---|
|Key ring name|k8s-kind-vault|
|Single/multi region|single|
|Region|europe-west9|


##### KMS key

!!! tip
    Security > Key Management > k8s-kind-vault > + CREATE KEY

|KEY|VALUE|
|---|---|
|Key name|k8s-kind-vault|
|Protection level|software|
|Key material|generated|
|Purpose and algorithm|symmetric encrypt/decrypt|
|Key rotation|180d|


#### Accès du service account à la clé

Il nous reste à autoriser notre service account ***'k8s-kind-vault@vault-415918.iam.gserviceaccount.com'*** à accéder à la clé que nous venons de créer et de rattacher à son trousseau.

!!! tip
    Security > Key Management > k8s-kind-vault (key ring) > k8s-kind-vault (key) > PERMISSIONS > + GRANT ACCESS

|KEY|VALUE|
|---|---|
|Principal|k8s-kind-vault@vault-415918.iam.gserviceaccount.com|
|Role|Cloud KMS Viewer|
|Role|Cloud KMS CryptoKey Encrypter/Decrypter|

Nous en avons fini avec les préparatifs côté GCP ^^


--- reprendre ici ---

Nous allons maintenant créer un service-account dans GCP et lui donner accès à une clé KMS que Vault utilisera pour son auto-unsealing.

!!! info
    https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-gcp-kms







## Mise en place de Vault en mode 'auto-unseal'

Nous couvrirons dans cette section l'installation de Vault, son initialisation et son _*unsealing*_.


### 'Custom values'

Pour configurer Vault en mode _*'auto-unseal'*_, nous devons modifier la configuration par défaut du Helm Chart.


#### Récupération des 'Default values'

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

helm show values hashicorp/vault > apps/vault/vault.default.values.txt
```

!!! warning
    Bien que le fichier récupéré soit en **YAML**, nous modifierons son extention en **.TXT** pour qu'il ne soit pas interprété par FluxCD.



#### Création du fichier 'Custom values'

Dans le même répertoire, nous créerons notre fichier 'values' sur la base du fichier que nous venons de récupérer, et le nommerons ***'vault.custom.values.txt'***

Nous déploierons ici Vault en mode *'standalone'*, ce qui ne se prête pas à un contexte de production.

La clé privée du service-account GCP 'k8s-kind-vault est transmise dans les 'extraEnvironmentVars', récupérés depuis le secret Kubernetes *'kms-sa'* et monté dans '/vault/userconfig'.



```yaml
  global:
    enabled: false
    namespace: "vault"

  injector:
    enabled: false

  server:
    enabled: true
    extraEnvironmentVars:
      GOOGLE_REGION: europe-west9
      GOOGLE_PROJECT: vault-415918
      GOOGLE_APPLICATION_CREDENTIALS: /vault/userconfig/kms-sa/k8s-kind-vault.creds.json
    extraVolumes:
      - type: secret
        name: kms-sa
        path: /vault/userconfig
    dataStorage:
      size: 1Gi
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

        seal "gcpckms" {
           project     = "vault-helm-dev-246514"
           region      = "euope-west9"
           key_ring    = "k8s-kind-vault"
           crypto_key  = "k8s-kind-vault"
        }
    serviceAccount:
      create: true
      name: "vault"

  ui:
    enabled: true
```



### Helm release


#### Installation de la Release

Nous pouvons désormais définir notre 'helm release' pour que FluxCD puiss egérer le déploiement de Vault :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"

    cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
    
    flux create helmrelease vault \
      --source=HelmRepository/hashicorp \
      --chart=vault \
      --namespace=vault \
      --from-values=ConfigMap/vault-values
      --export > ./apps/vault/vault.helm-release.yaml
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

cd ${HOME}/code/github/k8s-kind-fluxcd

git add .
git commit -m "feat: vault helm release with custom values"
git push

flux reconcile kustomization flux-system --with-source
```

Discord nous informe tout de suite de la création de la Helm Release nommée *'vault'* dans le namespace *'vault'* ("helmrelease/vault.vault") :

![Vault Helm release installation](./images/vault_helm_release.png)

Regardons l'état de nos objets dans le namespace 'vault' :

=== " code"
    ```sh
    kubectl -n vault get all
    ```

=== "output"
    ```sh
    NAME                                        READY   STATUS    RESTARTS   AGE
    pod/vault-0                                 0/1     Running   0          9s
    pod/vault-agent-injector-755c8bb799-j7f9w   1/1     Running   0          10s
    
    NAME                               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
    service/vault                      ClusterIP   10.96.166.217   <none>        8200/TCP,8201/TCP   10s
    service/vault-active               ClusterIP   10.96.17.218    <none>        8200/TCP,8201/TCP   10s
    service/vault-agent-injector-svc   ClusterIP   10.96.181.53    <none>        443/TCP             10s
    service/vault-internal             ClusterIP   None            <none>        8200/TCP,8201/TCP   10s
    service/vault-standby              ClusterIP   10.96.123.15    <none>        8200/TCP,8201/TCP   10s
    
    NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/vault-agent-injector   1/1     1            1           10s
    
    NAME                                              DESIRED   CURRENT   READY   AGE
    replicaset.apps/vault-agent-injector-755c8bb799   1         1         1       10s
    
    NAME                     READY   AGE
    statefulset.apps/vault   0/1     10s
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
    Version                  1.16.1
    Build Date               2024-04-03T12:35:53Z
    Storage Type             raft
    HA Enabled               true
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
    Recovery Key 1: xhiaiaNYaJG6IjCSgvtlDOktdl1D8pEQiuuflLF4TFn6
    Recovery Key 2: i6Z/xCFSOottTsabjYemf182h80c4gz8S8pP0Uv5kmws
    Recovery Key 3: iCYiSqb8MwMIb34GGyy2+pUMfL7774gAXb6BVV24v+EZ
    Recovery Key 4: cMFdU8okh5OZ2VSdhpRk7965EE+hO+N+M9OlHEtZBfdl
    Recovery Key 5: QmMRWjhJrzEJ+Oc0UnWhN9hlJff4seCmBkr7Ne8uP3ay
    
    Initial Root Token: hvs.VPcxxUbQjWt66U3jRzMjfIaI
    
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
    Version                  1.16.1
    Build Date               2024-04-03T12:35:53Z
    Storage Type             raft
    Cluster Name             vault-cluster-877de470
    Cluster ID               8a3d7616-1771-aa7d-bf00-e587e88f9f4d
    HA Enabled               true
    HA Cluster               https://vault-0.vault-internal:8201
    HA Mode                  active
    Active Since             2024-06-01T16:21:00.144765355Z
    Raft Committed Index     67
    Raft Applied Index       67
    ```

Vault est bien initialisé. Assurons-nous malgré tout que le pod est désormais bien 'ready' :

=== " code"
    ```sh
    kubectl -n vault get pod vault-0
    ```

=== "output"
    ```sh
    NAME      READY   STATUS    RESTARTS   AGE
    vault-0   1/1     Running   0          25m
    ```

Tout est comme attendu ! :fontawesome-regular-face-laugh-wink:



### Test de l'auto-unseal

Vault est installé en *'statefulset'*, sa configuration est pérenne, aussi allons-nous le désinstaller et attendre que FluxCD le réinstalle pour nous assurer que Vault sera réinstallé dans un état initialisé et *'unsealed'*.

helm -n vault list

NAME 	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART       	APP VERSION
vault	vault    	1       	2024-06-01 16:13:04.681229835 +0000 UTC	deployed	vault-0.28.0	1.16.1


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
    Version                  1.16.1
    Build Date               2024-04-03T12:35:53Z
    Storage Type             raft
    Cluster Name             vault-cluster-877de470
    Cluster ID               8a3d7616-1771-aa7d-bf00-e587e88f9f4d
    HA Enabled               true
    HA Cluster               https://vault-0.vault-internal:8201
    HA Mode                  active
    Active Since             2024-06-01T16:45:14.602109688Z
    Raft Committed Index     109
    Raft Applied Index       109
    ```

!!! Success
    Nous venons de valider le bon fonctionnement de l'**'auto-unsealing'** de Vault.



## External Secrets Operator

!!! Info
    https://external-secrets.io/latest/introduction/overview/


### Helm repository

Commençons par définir le Helm repository :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
        
    flux create source helm external-secrets \
      --url=https://charts.external-secrets.io \
      --namespace=vault \
      --interval=1m \
      --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault/external-secrets.helm-repository.yaml
    ```

=== "'external-secrets' Helm repository"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1beta2
    kind: HelmRepository
    metadata:
      name: external-secrets
      namespace: vault
    spec:
      interval: 1m0s
      url: https://charts.external-secrets.io
    ```


#### Helm release

Nous avions déjà défini le **Helm repository** [dans la première partie](http://lpapafrancky.github.io/Vault/kind_helm_vault_auto-unseal_ESO/kind_vault_auto-unsealed_eso_fluxcd/#helm-repositories)  de ce howto. 

Il nous reste à définir la **Helm release** asociée :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
        flux create helmrelease external-secrets \
          --source=HelmRepository/external-secrets \
          --chart=external-secrets \
          --namespace=vault \
          --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault/external-secrets.helm-release.yaml
    ```

=== "'external-secrets' Helm release"
    ```yaml
    ---
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: external-secrets
      namespace: vault
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

### Déploiement sur le cluster

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: deploying external-secrets operator on the cluster."
git push

flux reconcile kustomization flux-system --with-source
```

Nous recevons tout de suite des alertes dans notre salon Discord dédié à Vault : 

![ESO helm release deployment](./images/eso_helm_release.png)


Regardons quels objets ont été déployés sur le cluster :

=== "code"
    ```sh
    kubectl -n vault  get all -l app.kubernetes.io/name=external-secrets
    ```

=== "output"
    ```sh
    NAME                                    READY   STATUS    RESTARTS   AGE
    pod/external-secrets-7f9f5fd4d6-gfc6h   1/1     Running   0          16m
    
    NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/external-secrets   1/1     1            1           16m
    
    NAME                                          DESIRED   CURRENT   READY   AGE
    replicaset.apps/external-secrets-7f9f5fd4d6   1         1         1       16m
    ```

Faisons une dernière vérification :

=== "code"
    ```sh
    kubectl -n vault get externalsecret,secretstore
    ```
=== "output"
    ```sh
    No resources found in vault namespace.
    ```

Même si la dernière commande ne retourne aucun objet, au moins nous sommes sûrs que les objets de type *'externalsecret'* et *'secretstore'* sont bien définis au niveau de notre cluster.

!!! Success
    **'External-Secrets Operator (ESO)'** est déployé correctement sur notre cluster ! :fontawesome-regular-face-laugh-wink:





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
vault login hvs.VPcxxUbQjWt66U3jRzMjfIaI

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