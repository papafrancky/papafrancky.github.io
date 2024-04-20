# Auto-unsealed Vault Helm deployment managed with FluxCD


## Abstract

Dans un premier temps, nous tenterons de déployer Vault à partir du Helm chart officiel en mode auto-unseal.
Nous choisirons GCP KMS pour cela.
Lorsque nous arriverons à nos fins, nous configurerons FluxCD pour qu'il gère son déploiement tout seul.


### Docs de référence 

- https://developer.hashicorp.com/vault/docs/platform/k8s/helm
- https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-consul
- https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-gcp-kms
- https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide
- https://gist.github.com/sdeoras/96e78780561b1e941e8d5c4d3a78b7e9
- https://developer.hashicorp.com/vault/docs/configuration/seal/gcpckms


### Pré-requis Kubernetes (cluster local) 

- un cluster Kind opérationnel, 
- FluxCD déployé,
- Helm installé,
- kubectl installé.



### Pré-requis GCP

Accès à la console GCP :  https://console.cloud.google.com

- project
  - project name : vault
  - project ID : vault-415918
  - project number : 226383909329

- service account
  - service account name : sa-vault
  - service account ID : 114299537044679868050
  - email address : sa-vault@vault-415918.iam.gserviceaccount.com
  - private key (json file) : /Users/franck/Downloads/credentials.json 

``` 
    cat /Users/franck/Downloads/credentials.json

    #  {
    #    "type": "service_account",
    #    "project_id": "vault-415918",
    #    "private_key_id": "0f05bb392e8450a34f96b0fe813137ca06210a8b",
    #    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDWvrEgapjonPkm\n32zmC6Dyo/PyXSnyfaiNQ4TYL0HWvExXkal9P8rsvyK+I+tyEEZuCMzGjlzS9v1e\nlAwwE3gcTQ1wuS    #  +eaMVOTy4FD4cdjsJMenRTolfRVLFCO5McTAsHwwLhirOQbeNb\nLehLagxEN3q0rzG0eFHpVFL1p9T29hcnFmCLPUWBGyliAUY1d8DThyr7KoxT3ShG\n3vhOnsNVPMw+30EC    #  +JITZbqx3XBuiIAjLDctWOsWr34yHLkmdDQ6tepU7DW5Vv26\ngNjEoseXfs59gya2g15CYwMqex+1iE8v6lwFbP2y/iydr6jbK9xR9j5EQtQjjkr4\nwfD6Rg9BAgMBAAECggEAGzlQ5+TQ/mmquxSHZWFDWzS7ysBS1Ay9dIMtxou0fg5L\nDgLyXhAwn/    #  OElQmlYfAm7ZuB/Qiz7dl6uiXB/HT2Eihr3sbV/vAWALJ7CWXe4Y66\nmnV1D9vnOYDSJAJnc6aUSLyekzdBQmXGn/A29cXmSN5RA7JTdnyWbc0kje4On+wh\nWedadJMWzNFq9y1K6pLfWQINUzRYqlmexqfSYbEzoUgYHCk0PhHbk5+fTV8JU+Id\n1E    #  +jtxnnvowi6b9002Zeoxrb2u9kKm/vaxGug40LiWNLguR6UWAkGR377LDXOe2S\nxLJBz1IW9uKO5b7Mcn2xJD7+05UwRefe9JhqupqmLQKBgQDsLGF6gOW/60wXJ4Oe\nsBhjc6XYcdjKUtXfHTnHE5wMcUVJo+88dEmF0df+6Kr5GAYEsqn    #  +0CzgdeM1zQDY\nbkuogaN79A7h0tm+jzcIu4FuJG6OCqCekLlZ/b49DvQJWF0uqKXID8Q6Ai5zU4+2\nFL0oKzDT/OFKLNsjVFIy1A8KuwKBgQDoxcpNW1IbmoGVp/Bdv/a3xYnjEdQedgEU\nDdglCJK    #  +C2zvQJX4r6ZmhYzx6c6KWgd3naetUL7rPKFjUX2Tnu1f31tIhChiO8Eh\niaSpGiRdx9quq1qpvNkurbto0Ublt92siCPe0OcxIIAsOytqNzuD2YfJvQ2hfb8N\nf795sZQEMwKBgQDSp+NquX40aVQ9culbqgaW7piHL0UHckuB7zeR8lPGZWJABRFn\nAvJxgnL    #  +09lsxZjYp+QpfNYKgBxh6LFQW1DwxHFmJpL/qmq+JlAYYedYrvZNi/0o\ncj5hnosJO0VA8Khs7dCxWh7U/w0foPEWn/j4002CSJVK7Ceqo5ON8shX8QKBgGve\n9VCCCHv4TyMuj4qyokAp0CuloHp5Tyie/dKztWVS4CnD8Xws0l1ieJ3HL0sYS6uY\nKRN9fux    #  +zX+8TQizNugeFyx06k4TyP2kzuT6022OZ35YtIxCkxc5tcbubP+aBKWm\n9ZCVmP5ARIW66fSwIemJTo8kCIQVRQuZbv+TVrfXAoGAA46OjdCsPVbQOI/agbsK\nC3EGrBYz2g76i4t9wUoHMUjbZ1Jul/X7YXWBfKqAiimZuBBxkLKirKAfGLKGJovg\n/HWop    #  +llvqJxwZtQkMzkyVG/J9R2N41wBf5exT/aDSdsoZXqkqW2oiFlO5nBt+03\nQjcnzsHFcLrp3qzBco4aL04=\n-----END PRIVATE KEY-----\n",
    #    "client_email": "sa-vault@vault-415918.iam.gserviceaccount.com",
    #    "client_id": "114299537044679868050",
    #    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    #    "token_uri": "https://oauth2.googleapis.com/token",
    #    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    #    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/sa-vault%40vault-415918.iam.gserviceaccount.com",
    #    "universe_domain": "googleapis.com"
    #  }
``` 

- création du key ring : vault-helm-unseal-kr
- création de la clé : vault-helm-unseal-key
  -> grant access sur la clé vault-helm-unseal-key au principal 'sa-vault' avec les rôles ' Cloud KMS Viewer' et 'Cloud KMS CryptoKey Encrypter/Decrypter'

- activation des APIs :
  - Cloud Key Management Service (KMS) API : enabled
  - Compute Engine API : enabled (pour définir la région/zone)

- définition de la région et de la zone :
  - via la console :
    - https://console.cloud.google.com/compute/settings?hl=fr&project=vault-415918
    - région : europe-west9 (Paris)
    - zone: europe-west9-a

  - via la CLI :
  ``` 
    gcloud auth login
    gcloud compute project-info describe --project vault-415918
    gcloud config set project vault-415918
    gcloud services enable compute.googleapis.com cloudkms.googleapis.com
    gcloud config set compute/region europe-west9
    gcloud config set compute/zone europe-west9-a
    gcloud config list

- création d'un secret Kubernetes pour la clé privée du service account 'sa-vault'  
``` 
    kubectl -n vault create secret generic kms-creds --from-file=/Users/franck/Downloads/credentials.json
    kubectl get secret kms-creds -o yaml | yq -r '.data' | awk '{print $2}' | base64 -d | jq -r '.'
      
    -> même sortie que : cat /Users/franck/Downloads/credentials.json 
```  


## Déploiement manuel de Vault ne mode auto-unseal depuis le Helm Chart officiel


### Helm repository HashiCorp

    helm repo add hashicorp https://helm.releases.hashicorp.com
    
    helm search repo hashicorp
    helm show values hashicorp/vault
    
    kubectl create namespace vault
    kubens vault
    
    helm search repo hashicorp/vault --versions
    helm install vault hashicorp/vault --namespace vault --dry-run




### Ecriture des custom values pour activer l'auto-unseal

    cat custom-values.txt
    
    global:
      enabled: false
      namespace: "vault"
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
        GOOGLE_APPLICATION_CREDENTIALS: /vault/userconfig/kms-creds/credentials.json
      extraVolumes:
        - type: secret
          name: kms-creds
          path: /vault/userconfig # default is `/vault/userconfig`
      standalone:
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
             project     = "vault-415918"
             region      = "europe-west9"
             key_ring    = "vault-helm-unseal-kr"
             crypto_key  = "vault-helm-unseal-key"
          }
      #ha:
      #  enabled: true
      #  replicas: 1
      #  raft:
      #    enabled: true
      serviceAccount:
        create: true
        name: "vault"
    ui:
      # True if you want to create a Service entry for the Vault UI.
      #
      # serviceType can be used to control the type of service created. For
      # example, setting this to "LoadBalancer" will create an external load
      # balancer (for supported K8S installations) to access the UI.
      enabled: false


### Déploiement manuel de Vault en mode auto-unseal

    helm instal vault hashicorp/vault -f values.yml --dry-run
    kubens vault
    kubectl get all
    
    kubectl logs vault-0
    
      # 2024-03-02T13:42:57.055Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
      # 2024-03-02T13:42:57.245Z [INFO]  incrementing seal generation: generation=1
      # 2024-03-02T13:42:57.246Z [INFO]  core: Initializing version history cache for core
      # 2024-03-02T13:42:57.246Z [INFO]  events: Starting event system
      # 2024-03-02T13:42:57.247Z [INFO]  core: stored unseal keys supported, attempting fetch
      # 2024-03-02T13:42:57.247Z [WARN]  failed to unseal core: error="stored unseal keys are supported, but none were found"
      # 2024-03-02T13:43:01.821Z [INFO]  core: security barrier not initialized
      # 2024-03-02T13:43:01.821Z [INFO]  core.autoseal: recovery seal configuration missing, but cannot check old path as core is sealed
    
    kubectl exec -it vault-0 -- vault status
    
      # Key                      Value
      # ---                      -----
      # Recovery Seal Type       gcpckms
      # Initialized              false
      # Sealed                   true
      # Total Recovery Shares    0
      # Threshold                0
      # Unseal Progress          0/0
      # Unseal Nonce             n/a
      # Version                  1.15.2
      # Build Date               2023-11-06T11:33:28Z
      # Storage Type             file
      # HA Enabled               false
      # command terminated with exit code 2
    
    kubectl exec vault-0 -- vault operator init
    
      # Recovery Key 1: BE9yVRP/GNAbb2cIOccb+0e9S8hF9QTOYxqfDq14JdsU
      # Recovery Key 2: LDbM7aYBpEWsW28Ul+aLiaSzzTqMplk8KviKI9IJNE5V
      # Recovery Key 3: 3c6lgD82bct7/maaS5HJ+Z/Q3y5IAmeAU+UcNW3eoDOy
      # Recovery Key 4: XuG7btTetf/ZAIaDxQoM8+qn79GDFA0uXArBq5OBM+kx
      # Recovery Key 5: 7xRR+XEYZRNwfhrQiaflUVj+6BPLzUlqHuwG4aqxZMOT
      # 
      # Initial Root Token: hvs.G145zNl012ApNOap3sn2zhIG
      # 
      # Success! Vault is initialized
      # 
      # Recovery key initialized with 5 key shares and a key threshold of 3. Please
      # securely distribute the key shares printed above.
    
    
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
    
    kubectl delete pod vault-0
    kubectl exec -it vault-0 -- vault status

-> l'auto-unseal a fonctionné !

### Conclusion

Nous savons désormais comment installer Vault via Helm sur notre cluster Kubernetes en mode auto-unseal.
Voyons comment confier sa gestion à FluxCD maintenant.




## Déploiement de Vault en mode auto-unseal depuis le Helm Chart officiel et piloté par FluxCD


### Clonage en local du repository Git de FluxCD

Nous devons ajouter les manifests dans le repo Git piloté par FluxCD.
Pour identifier ce dernier : kubectl get gitrepository -n flux-system -> https://github.com/papaFrancky/kubernetes-development.git

Mettons à jour la copie locale de ce repo : 
```
    cd ~/code/github
    git clone git@github.com:papafrancky/kubernetes-development.git
    cd kubernetes-development
    mkdir -p products/vault
```


### alerting Discord


#### création du salon privé sur le client Discord

Création d'un nouveau salon (privé) : 
  - nom : vault-development
  - webhook :
    - nom : FluxCD
    - URL : https://discord.com/api/webhooks/1213494413511237642/7gRzmfYCwDqWwI2D-1jfLZCNvDBotoe_rY2sson57G1Ya40-EtEMWAZy9FsxmjCZTJ4C


#### on place le webhook du salon discord dans un secret kubernetes

    DISCORD_WEBHOOK="https://discord.com/api/webhooks/1213494413511237642/7gRzmfYCwDqWwI2D-1jfLZCNvDBotoe_rY2sson57G1Ya40-EtEMWAZy9FsxmjCZTJ4C"
    kubectl -n vault create secret generic discord-vault-development-webhook --from-literal=address=${DISCORD_WEBHOOK} --dry-run=client -o yaml > products/vault/discord-vault-development-webhook.secret.yaml


#### définition de l'alert-provider Discord

    flux create alert-provider discord \
      --type=discord \
      --secret-ref=discord-vault-development-webhook \
      --channel=vault-development \
      --username=FluxCD \
      --namespace=vault \
      --export > products/vault/notification-provider.yaml


#### configuration des alertes Discord

    flux create alert discord \
      --event-severity=info \
      --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*,HelmRelease/*' \
      --provider-ref=discord \
      --namespace=vault \
      --export > products/vault/notification-alert.yaml


#### Poussons les manifests sur le repo central pour que FluxCD les gère :

    git add .
    git commit -m 'feat: configuring discord alerting for vault.'
    git push

    flux reconcile kustomization flux-system --with-source
    flux events -w


### Gestion du repo Helm

    flux create source helm hashicorp \
      --url=https://helm.releases.hashicorp.com \
      --namespace=vault \
      --interval=1m \
      --export > products/vault/helm-repository.yml


### Déploiement de Vault (helm release)

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



