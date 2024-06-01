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
  serverTelemetry:
    prometheusOperator: true

injector:
  enabled: false

server:
  enabled: true
  # Used to define commands to run after the pod is ready.
  # This can be used to automate processes such as initialization
  # or boostrapping auth methods.
  postStart: []
  # - /bin/sh
  # - -c
  # - /vault/userconfig/myscript/run.sh
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
        telemetry {
          unauthenticated_metrics_access = "true"
        }
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
      telemetry {
        prometheus_retention_time = "30s"
        disable_hostname = true
      }
  serviceAccount:
    create: true
    name: "vault"

ui:
  enabled: true

serverTelemetry:
  serviceMonitor:
    enabled: true
  prometheusRules:
      enabled: true
```



### Helm release


#### Installation de la Release

Nous pouvons désormais définir notre 'helm release' pour que FluxCD puiss egérer le déploiement de Vault :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    flux create helmrelease vault \
      --source=HelmRepository/hashicorp \
      --chart=vault \
      --namespace=vault \
      --values=${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault/vault.custom.values.txt \
      --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/vault/vault.helm-release.yaml
    ```

=== "'vault' helm release"
    ```yaml
    ---
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
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
      values:
        global:
          serverTelemetry:
            prometheusOperator: true
        injector:
          affinity: {}
        server:
          extraEnvironmentVars:
            GOOGLE_APPLICATION_CREDENTIALS: /vault/userconfig/kms-sa/k8s-kind-vault.creds.json
            GOOGLE_PROJECT: vault-415918
            GOOGLE_REGION: europe-west9
          extraVolumes:
          - name: kms-sa
            path: /vault/userconfig
            type: secret
          ha:
            enabled: true
            raft:
              config: |
                ui = true
    
                listener "tcp" {
                  tls_disable = 1
                  address = "[::]:8200"
                  cluster_address = "[::]:8201"
                  # Enable unauthenticated metrics access (necessary for Prometheus Operator)
                  telemetry {
                    unauthenticated_metrics_access = "true"
                  }
                }
    
                storage "raft" {
                  path = "/vault/data"
                }
    
                service_registration "kubernetes" {}
    
                # Example configuration for using auto-unseal, using Google Cloud KMS. The
                # GKMS keys must already exist, and the cluster must have a service account
                # that is authorized to access GCP KMS.
                seal "gcpckms" {
                   project     = "vault-415918"
                   region      = "europe-west9"
                   key_ring    = "k8s-kind-vault"
                   crypto_key  = "k8s-kind-vault"
                }
                # Example configuration for enabling Prometheus metrics.
                # If you are using Prometheus Operator you can enable a ServiceMonitor resource below.
                # You may wish to enable unauthenticated metrics in the listener block above.
                telemetry {
                  prometheus_retention_time = "30s"
                  disable_hostname = true
                }
              enabled: true
            replicas: 1
        serverTelemetry:
          serviceMonitor:
            enabled: true
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