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





## Intégration de Vault et External-Secrets à la Helm Release 'kube-prometheus-stack'

La stack de monitoring définit un mot de passe par défaut pour le compte admin de Grafana. Et c'est moche.

Nous allons définir un nouveau mot de passe que nous allons placer dans Vault. Nous définirons une politique donnant accès à ce 'secret' que nous rattacherons à un compte
(...) A COMPLETER !


### Ajout du *'secret'* dans Vault

```sh
# Accès au pod du micro-service 'vault'
kubectl -n vault exec -it vault-0 -- sh

# Login sur Vault avec le Root token
vault login hvs.VPcxxUbQjWt66U3jRzMjfIaI

# Activation du 'secret engine' KVv2
vault secrets enable -version=2 kv

# Ecriture du secret 
vault kv put -mount kv monitoring/grafana/admin-account login=admin password=secretpassword


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
password    secretpassword

# Deconnexion du pod 
exit
```


### Définition d'une *'policy'* permettant d'accéder en lecture aux secrets dédiés à Grafana

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

!!! Info
    https://developer.hashicorp.com/vault/docs/auth/kubernetes#kubernetes-auth-method

    Use local service account token as the reviewer JWT :

    When running Vault in a Kubernetes pod the recommended option is to use the pod's local service account token.
    Vault will periodically re-read the file to support short-lived tokens. To use the local token and CA certificate,
    omit token_reviewer_jwt and kubernetes_ca_cert when configuring the auth method. Vault will attempt to load them
    from token and ca.crt respectively inside the default mount folder /var/run/secrets/kubernetes.io/serviceaccount/.

    Each client of Vault would need the **system:auth-delegator** ClusterRole

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

Notre Helm Release *'kube-prometheus-monitoring'* a créé plusieurs service-accounts Kubernetes, et plus spécifiquement pour Grafana, le service-account **'kube-prometheus-stack-grafana'**. Nous allons donner à ce compte le droit de déléguer son authentification en le rattachant au ClusterRole **'system:auth-delegator'**.


#### ClusterRoleBinding

Vault nécessite certaines autorisations Kubernetes supplémentaires pour effectuer ses opérations. Par conséquent, il est nécessaire d'attribuer un ClusterRole (avec les autorisations appropriées) à son ServiceAccount via un ClusterRoleBinding.


=== "code"
    ```sh
    kubectl create clusterrolebinding grafana-tokenreview-access \
      --clusterrole=system:auth-delegator \
      --serviceaccount=monitoring:kube-prometheus-stack-grafana
    ```

=== "output"
    ```sh
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      creationTimestamp: "2024-06-04T16:37:52Z"
      name: grafana-tokenreview-access
      resourceVersion: "864455"
      uid: 3f93e41e-3ec7-4df8-8233-32eceeefbb11
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: system:auth-delegator
    subjects:
    - kind: ServiceAccount
      name: kube-prometheus-stack-grafana
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
  bound_service_account_names=kube-prometheus-stack-grafana \
  bound_service_account_namespaces=monitoring \
  policies=monitoring-grafana--ro \
  ttl=1h

# Vérification
vault read auth/kubernetes/role/monitoring-grafana--ro

# Key                                         Value
# ---                                         -----
# alias_name_source                           serviceaccount_uid
# bound_service_account_names                 [kube-prometheus-stack-grafana]
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
# token_type                                  default
# ttl                                         1h

# Deconnexion du pod 
exit
```


#### Test de l'accès du service-account Kubernetes au secret Vault

Pour tester que le service-account Kubernetes *'kube-prometheus-stack-grafana'* du namespace *'monitoring'* accède bien au secret de Grafana dans Vault, nous allons déployer un pod temporaire qui s'exécutera avec ce service-account.


Voici ce que nous cherchons à vérifier :

1. Le pod est exécuté avec un service-account Kubernetes auquel est rattaché le ClusterRole 'system:auth-delegator';
2. L'application dans le pod s'authentifie à Vault (authentification Kubernetes) en utilisant le token de son service-account Kubernetes et en demandant le rôle Vault 'monitoring-grafana--ro' ;
3. Ce rôle Vault autorise précisément à ce service-account Kubernetes d'utiliser la policy Vault qui donne accès en lecture aux login et mot de passe du compte d'administration de Grafana;
4. Vault valide le token du service-account Kubernetes auprès de Kubernetes et renvoie à l'application du pod un token d'authentification à Vault, auquel est rattaché la policy d'accès aux credentials d'admin de Grafana;
5. L'application peut désormais de loguer à Vault avec le token ainsi récupéré et accéder ensuite au compte d'administration de Grafana.



##### Test en interrogeant directement l'API

```sh
# Lancement d'un pod Alpine avec le service-account 'monitoring:kube-prometheus-stack-grafana'
kubectl -n monitoring run --tty --stdin test --image=alpine --rm --overrides='{ "spec": { "serviceAccount": "kube-prometheus-stack-grafana" }  }' -- /bin/sh

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
#   "password": "secretpassword"
# }
```


##### Test avec la CLI *'vault'*


```sh
# Lancement d'un pod Alpine avec le service-account 'monitoring:kube-prometheus-stack-grafana'
kubectl -n monitoring run --tty --stdin fedora --image=fedora --rm --overrides='{ "spec": { "serviceAccount": "kube-prometheus-stack-grafana" }  }' -- /bin/bash

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
# token                                     hvs.CAESIIuNElbt2UPdepDg4VV0R_N_9EDIB5xlZO6MddPHe6UZGh4KHGh2cy55SGVoZE5nVndoTUZwZWNYVXNzN2p5WmQ
# token_accessor                            P3V1p0lTFoEh5eVRxqISChuq
# token_duration                            50m7s
# token_renewable                           true
# token_policies                            ["default" "monitoring-grafana--ro"]
# identity_policies                         []
# policies                                  ["default" "monitoring-grafana--ro"]
# token_meta_service_account_namespace      monitoring
# token_meta_service_account_secret_name    n/a
# token_meta_service_account_uid            50f4a2f7-2b95-4c4b-a7c3-a362b87eecff
# token_meta_role                           monitoring-grafana--ro
# token_meta_service_account_name           kube-prometheus-stack-grafana


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
# password    secretpassword


vault kv get -mount=kv -field=password monitoring/grafana/admin-account

# secretpassword
```




### Configuration d'External Secrets Operator (ESO)



#### Definition du Secret Store (ESO)

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/


cat << EOF > apps/monitoring/grafana.secretstore.yaml
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
        # Authenticate against Vault using a Kubernetes ServiceAccount
        # token stored in a Secret.
        # https://www.vaultproject.io/docs/auth/kubernetes
        kubernetes:
          # Path where the Kubernetes authentication backend is mounted in Vault
          mountPath: "kubernetes"
          # A required field containing the Vault Role to assume.
          role: "monitoring-grafana--ro"
          # Optional service account field containing the name
          # of a kubernetes ServiceAccount
          serviceAccountRef:
            name: "kube-prometheus-stack-grafana"
          # Optional secret field containing a Kubernetes ServiceAccount JWT
          #  used for authenticating with Vault
          #secretRef:
          #  name: "my-secret"
          #  key: "vault"
EOF
```



#### Définition de l'External Secret (ESO)

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/


cat << EOF > apps/monitoring/grafana.externalsecret.yaml
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
    NAME                                      AGE    STATUS   CAPABILITIES   READY
    secretstore.external-secrets.io/grafana   109s   Valid    ReadWrite      True
    
    NAME                                                 STORE     REFRESH INTERVAL   STATUS         READY
    externalsecret.external-secrets.io/grafana-secrets   grafana   15s                SecretSynced   True
    ```



#### Récupération de l'External Secret depuis un pod de test

```sh
# Création d'un pod Apline excuté avec le service-account dédié à l'application Grafana
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
  serviceAccount: kube-prometheus-stack-grafana
EOF
```

Le pod pase à l'état 'Completed'. Consultons ses logs :

=== "code"
    ```sh
    kubectl -n monitoring logs test
    ```
=== "output"
    ```sh
    secretpassword
    ```

!!! success
    Nous récupérons comme attendu le mot de passe du compte d'administration de Grafana présent dans Vault.  :fontawesome-regular-face-laugh-wink:




### Intégration de l'external secret de la Helm Release *'kube-prometheus-stack'*

Avançons à petits pas. Nous avions déployé *'kube-prometheus-stack'* avec les valeurs par défaut. Avant d'intégrer ESO, nous allons modifier manuellement le mot de passe du compte d'administration de Grafana dans notre *HelmRelease*.



#### Static custom values

La première étape consiste à récupérer les *'default values'* de notre Helm Chart :

```sh
# Lister les dépôts de Charts
helm repo list

# Rechercher une occurrence (ici, 'prometheus-community') parmi tous les dépôts de Charts référencés
helm search repo prometheus-community

# Lister les valeurs par défaut du Chart 'kube-prometheus-stack' présent dans le dépôt ' prometheus-community'
export LOCAL_GITHUB_REPOS="${HOME}/code/github"
helm show values prometheus-community/kube-prometheus-stack > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.default.values.txt 
```

Finalement, notre fichier de définition de *'custom values'* sera très simple :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"
cat << EOF >> ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.txt
grafana:
  adminPassword: my-custom-password
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

=== "'kube-prometheus-stack' helm release"
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
          adminPassword: my-custom-password
    ```

Appliquons la modification :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: manually changed the password for grafana's admin account."
git push

flux reconcile kustomization flux-system --with-source
```

Nous recevons immédiatement des alertes sur notre salon Discord :

![Manual grafana password update](./images/discord_helm_release_manual_update.png)


Vérifions la bonne prise en compte de notre mot de passe 'custom' :

```sh
kubectl -n monitoring port-forward service/kube-prometheus-stack-grafana 8080:80
```

Ouvrons un navigateur sur l'adresse de port-forwarding **http://localhost:8080** :

![Grafana login page](./images/grafana_login_page.png)

!!! Success
    nous accédons à Grafana avec le compte **'admin'** et le mot de passe **'my-custom-password'**



#### Dynamic custom values

Cette fois-ci, nous n'écrirons pas le mot de passe en clair dans la configuration de notre Helm Release et utiliserons **'External Secrets'**.

!!! Info
    https://blog.gitguardian.com/how-to-handle-secrets-in-helm/#external-secrets-operator

"ESO récupère automatiquement les *'secrets managers'* via des API externes **et les injecte dans Kubernetes Secrets**.

Contrairement à helm-secrets qui fait référence à des secrets stockés dans des *'Cloud secrets managers'* dans le fichier *'values'*, ESO ne nécessite pas d'inclure secrets.yaml dans les *'Helm templates'*. Il utilise une autre ressource personnalisée *'ExternalSecret'*, qui contient la référence aux gestionnaires de secrets dans le Cloud."


!!! Info
    https://external-secrets.io/latest/guides/templating/#templatefrom

!!! Info
    https://fluxcd.io/flux/cmd/flux_create_helmrelease/#options

Il est possible de définir une *'Helm Release'* avec la CLI *'flux'* en surchargeant les *'default vaules'* à partir d'un objet Kubernetes de type *'Secret'* ou *'ConfigMap'*.

Nous allons (re)définir notre *'Helm Release'* **'kube-prometheus-stack'** en lui indiquant de récupérer ses *'custom values'* depuis un *'Secret Kubernetes'*. Cet objet ne contiendra pas de *'secret'* à proprement parler, mais plutôt une référence à un *'ExternalSecret'* qui va l'utiliser comme un *'template'* pour forger un fichier final de type *'values.yaml'* en récupérant le secret demandé dans Vault.


=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"

    cat << EOF > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.ESO.txt
    grafana:
      adminPassword:{{ \`{{ .grafanaadminpassword }}\` }}
    EOF
    
    cat ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.ESO.txt | base64
    ```

=== "kube-prometheus-stack.custom.values.ESO.txt"
    ```sh
    grafana:
      adminPassword:{{ `{{ .grafanaadminpassword }}` }}
    ```

=== "encodage en base64"
    ```sh
    Z3JhZmFuYToKICBhZG1pblBhc3N3b3JkOnt7IGB7eyAuZ3JhZmFuYWFkbWlucGFzc3dvcmQgfX1gIH19Cg==
    ```

Créons les premiers objets :


=== "code"
    ```sh
    cat << EOF > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/kube-prometheus-stack.custom.values.yaml
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: kube-prometheus-stack-custom-values-configmap
      namespace: monitoring
    data:
      grafana.custom.values.yaml: |
        Z3JhZmFuYToKICBhZG1pblBhc3N3b3JkOnt7IGB7eyAuZ3JhZmFuYWFkbWlucGFzc3dvcmQgfX1gIH19Cg==
    
    ---
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: kube-prometheus-stack-custom-values-externalsecret
    spec:
      target:
        name: secret-to-be-created
        template:
          engineVersion: v2
          templateFrom:
          - target: Data
            secret:
              # name of the secret to pull in
              name: kube-prometheus-stack-custom-values-configmap
              # here you define the keys that should be used as template
              items:
              - key: grafana.custom.values.yaml
                templateAs: Values
      data:
      - secretKey: grafanaadminpassword
        remoteRef:
          key: kv/monitoring/grafana/admin-account
          property: password
    EOF
    ```

=== "output"
    ```sh
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: kube-prometheus-stack-custom-values-configmap
      namespace: monitoring
    data:
      grafana.custom.values.yaml: |
        grafana:
          adminPassword:{{ `{{ .grafanaadminpassword }}` }}
    
    ---
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: kube-prometheus-stack-custom-values-externalsecret
    spec:
      target:
        name: secret-to-be-created
        template:
          engineVersion: v2
          templateFrom:
          - target: Data
            secret:
              # name of the secret to pull in
              name: kube-prometheus-stack-custom-values-configmap
              # here you define the keys that should be used as template
              items:
              - key: grafana.custom.values.yaml
                templateAs: Values
      data:
      - secretKey: grafanaadminpassword
        remoteRef:
          key: kv/monitoring/grafana/admin-account
          property: password
    ```

Créons ces nouveaux objets sur notre cluster :

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: creating external secret and custom values secret for kube-prometheus-stack."
git push

flux reconcile kustomization flux-system --with-source
```



Il ne nous reste plus qu'à (re)définir notre *'HelmRelease'* en lui indiquant qu'il doit récupérer ses *'custom values'* depuis un objet Kubernetes de type *'Secret'* que nous venons de définir plus haut :

=== "code"
    ```sh
    export LOCAL_GITHUB_REPOS="${HOME}/code/github"
    
    flux create helmrelease kube-prometheus-stack \
      --source=HelmRepository/prometheus-community \
      --chart=kube-prometheus-stack \
      --namespace=monitoring \
      --values-from=Secret/kube-prometheus-stack-custom-values-configmap \
      --export > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/helm-release.2.yaml
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
          adminPassword: my-custom-password
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
        name: kube-prometheus-stack-custom-values-configmap
    ```

Appliquons les modifications : 

```sh
export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd

git add .
git commit -m "feat: using ESO advanced templating to define kube-prometheus-stack custom values."
git push

flux reconcile kustomization flux-system --with-source
```



export LOCAL_GITHUB_REPOS="${HOME}/code/github"


kubectl -n monitoring create serviceaccount vault-grafana --dry-run=client -o yaml > ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/apps/monitoring/vault-grafana.serviceaccount.yaml

EOF

k exec -it vault-0 -n vault -- sh
vault login hvs.VPcxxUbQjWt66U3jRzMjfIaI

vault write auth/kubernetes/role/monitoring-grafana--ro \
>   bound_service_account_names=kube-prometheus-stack-grafana,vault-grafana \
>   bound_service_account_namespaces=monitoring \
>   policies=monitoring-grafana--ro \
>   ttl=1h


export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd/


cat << EOF > apps/monitoring/grafana.secretstore.yaml
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
        # Authenticate against Vault using a Kubernetes ServiceAccount
        # token stored in a Secret.
        # https://www.vaultproject.io/docs/auth/kubernetes
        kubernetes:
          # Path where the Kubernetes authentication backend is mounted in Vault
          mountPath: "kubernetes"
          # A required field containing the Vault Role to assume.
          role: "monitoring-grafana--ro"
          # Optional service account field containing the name
          # of a kubernetes ServiceAccount
          serviceAccountRef:
            name: "vault-grafana"
          # Optional secret field containing a Kubernetes ServiceAccount JWT
          #  used for authenticating with Vault
          #secretRef:
          #  name: "my-secret"
          #  key: "vault"
EOF


export LOCAL_GITHUB_REPOS="${HOME}/code/github"

cd ${LOCAL_GITHUB_REPOS}/k8s-kind-fluxcd
git add .
git commit -m "feat: creating a kubernetes service-account allowed to access grafana's secrets in Vault."
git push

flux reconcile kustomization flux-system --with-source


kubectl -n monitoring get sa vault-grafana
NAME            SECRETS   AGE
vault-grafana   0         34s

![Helm Release successfull installation](./images/helm_release_install.png)


k get ss,es

NAME                                      AGE    STATUS   CAPABILITIES   READY
secretstore.external-secrets.io/grafana   3h1m   Valid    ReadWrite      True

NAME                                                                                    STORE     REFRESH INTERVAL   STATUS         READY
externalsecret.external-secrets.io/grafana-secrets                                      grafana   15s                SecretSynced   True
externalsecret.external-secrets.io/kube-prometheus-stack-custom-values-externalsecret   grafana   1h                 SecretSynced   True



kubectl -n monitoring get all

NAME                                                            READY   STATUS    RESTARTS   AGE
pod/alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running   0          6m19s
pod/kube-prometheus-stack-grafana-565c8b845d-bv8cp              3/3     Running   0          6m21s
pod/kube-prometheus-stack-kube-state-metrics-6dcd966b95-cz79d   1/1     Running   0          6m21s
pod/kube-prometheus-stack-operator-7db4d6cd65-msf9c             1/1     Running   0          6m21s
pod/kube-prometheus-stack-prometheus-node-exporter-9gv69        1/1     Running   0          6m21s
pod/prometheus-kube-prometheus-stack-prometheus-0               2/2     Running   0          6m18s

NAME                                                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/alertmanager-operated                            ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP   6m19s
service/kube-prometheus-stack-alertmanager               ClusterIP   10.96.40.95     <none>        9093/TCP,8080/TCP            6m21s
service/kube-prometheus-stack-grafana                    ClusterIP   10.96.212.102   <none>        80/TCP                       6m21s
service/kube-prometheus-stack-kube-state-metrics         ClusterIP   10.96.84.151    <none>        8080/TCP                     6m21s
service/kube-prometheus-stack-operator                   ClusterIP   10.96.238.7     <none>        443/TCP                      6m21s
service/kube-prometheus-stack-prometheus                 ClusterIP   10.96.36.156    <none>        9090/TCP,8080/TCP            6m21s
service/kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.96.97.125    <none>        9100/TCP                     6m21s
service/prometheus-operated                              ClusterIP   None            <none>        9090/TCP                     6m18s

NAME                                                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/kube-prometheus-stack-prometheus-node-exporter   1         1         1       1            1           kubernetes.io/os=linux   6m21s

NAME                                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kube-prometheus-stack-grafana              1/1     1            1           6m21s
deployment.apps/kube-prometheus-stack-kube-state-metrics   1/1     1            1           6m21s
deployment.apps/kube-prometheus-stack-operator             1/1     1            1           6m21s

NAME                                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/kube-prometheus-stack-grafana-565c8b845d              1         1         1       6m21s
replicaset.apps/kube-prometheus-stack-kube-state-metrics-6dcd966b95   1         1         1       6m21s
replicaset.apps/kube-prometheus-stack-operator-7db4d6cd65             1         1         1       6m21s

NAME                                                               READY   AGE
statefulset.apps/alertmanager-kube-prometheus-stack-alertmanager   1/1     6m19s
statefulset.apps/prometheus-kube-prometheus-stack-prometheus       1/1     6m18s


kubectl -n monitoring port-forward service/kube-prometheus-stack-grafana 8080:80
-> navigateur - l'URL http://localhost:8080
-> login avec admin / secretpassword


-> success ^^
