# Kind - Vault - External-secrets operator



|Description|URL|
|---:|:---|
|Kind install|https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries|
| Helm installation|https://helm.sh/docs/intro/install/|
|External-secrets operator installation|https://external-secrets.io/latest/introduction/getting-started/|
|Vault helm installation|https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-raft#install-the-vault-helm-chart|
|Kubectl installation|https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/|
|kubens & kubectx installation|https://github.com/ahmetb/kubectx#manual-installation-macos-and-linux|
|External-secrets - Vault provider|https://external-secrets.io/latest/provider/hashicorp-vault/|
|Tutorial: How to Set External-Secrets with Hashicorp Vault|https://blog.container-solutions.com/tutorialexternal-secrets-with-hashicorp-vault|
|Vault - Kubernetes authentication|https://external-secrets.io/latest/provider/hashicorp-vault/#kubernetes-authentication|


## Prerequisites


### 'Kind' installation and cluster creation

    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    kind --version
    kind create cluster --name sandbox
    kind get clusters



### Helm installation

    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    helm version



### kubectl installation

    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    kubectl version
    printf "\nalias k=kubectl\n" >> ~/.bashrc && source ~/.bashrc
    k get po -A



### kubens and kubectx installation

    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
    sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens



### External-secrets operator installation

    helm repo add external-secrets https://charts.external-secrets.io
    helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
    
    # NAME: external-secrets
    # LAST DEPLOYED: Tue Sep 19 16:14:00 2023
    # NAMESPACE: external-secrets
    # STATUS: deployed
    # REVISION: 1
    # TEST SUITE: None
    # NOTES:
    # external-secrets has been deployed successfully!
    # 
    # In order to begin using ExternalSecrets, you will need to set up a SecretStore
    # or ClusterSecretStore resource (for example, by creating a 'vault' SecretStore).
    # 
    # More information on the different types of SecretStores and how to configure them
    # can be found in our Github: https://github.com/external-secrets/external-secrets



### Vault installation

    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    helm search repo hashicorp/vault
    helm show values hashicorp/vault
    cat << EOF > custom-values.yaml
    server:
      affinity: ""
      ha:
        enabled: true
        replicas: 1
        raft:
          enabled: true
    EOF
    
    helm install vault hashicorp/vault --values custom-values.yaml -n vault --create-namespace

    # NAME: vault
    # LAST DEPLOYED: Mon Sep 18 20:23:23 2023
    # NAMESPACE: vault
    # STATUS: deployed
    # REVISION: 1
    # NOTES:
    # Thank you for installing HashiCorp Vault!
    # 
    # Now that you have deployed Vault, you should look over the docs on using
    # Vault with Kubernetes available here:
    # 
    # https://www.vaultproject.io/docs/
    # 
    # 
    # Your release is named vault. To learn more about the release, try:
    #
    # helm status vault
    # helm get manifest vault


    helm list -A

    # NAME                    NAMESPACE               REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
    # external-secrets        external-secrets        1               2023-09-26 19:45:58.063107607 +0000 UTC deployed        external-secrets-0.9.5  v0.9.5     
    # vault                   vault                   1               2023-09-26 19:46:44.752525469 +0000 UTC deployed        vault-0.25.0            1.14.0    



    k -n vault get po

    # NAME                                    READY   STATUS    RESTARTS   AGE
    # vault-0                                 0/1     Running   0          78s
    # vault-agent-injector-67c48f8f4c-psznb   1/1     Running   0          79s
export VAULT_ADDR=http://127.0.0.1:8200
k -n vault exec --tty --stdin vault-0 -- /bin/sh 

vault status




## Vault initialization and unsealing operations



### Loging into the Vault pod

In namespace 'vault', the pod 'vault-0' is running but not ready.
One must initialize Vault and unseal it.
To do so, one must connect to the pod and interact with Vault using the provided CLI :

    k -n vault --tty --stdin exec vault-0 -- /bin/sh

All the following operations will be executed in this pod :

    vault status
    
    # Key                Value
    # ---                -----
    # Seal Type          shamir
    # Initialized        false
    # Sealed             true
    # Total Shares       0
    # Threshold          0
    # Unseal Progress    0/0
    # Unseal Nonce       n/a
    # Version            1.14.0
    # Build Date         2023-06-19T11:40:23Z
    # Storage Type       raft
    # HA Enabled         true


### Vault initialization

    vault operator init -key-shares=1 -key-threshold=1 -format=json

    # {
    #   "unseal_keys_b64": [
    #     "/yNqVmr967kJfM2vCjiRC+XFI304XApJDy8b2RVQaLs="
    #   ],
    #   "unseal_keys_hex": [
    #     "ff236a566afdebb9097ccdaf0a38910be5c5237d385c0a490f2f1bd9155068bb"
    #   ],
    #   "unseal_shares": 1,
    #   "unseal_threshold": 1,
    #   "recovery_keys_b64": [],
    #   "recovery_keys_hex": [],
    #   "recovery_keys_shares": 0,
    #   "recovery_keys_threshold": 0,
    #   "root_token": "hvs.fJuVStEaM1h2G66LnefKsDlI"
    # }


### Vault unsealing

    vault operator unseal /yNqVmr967kJfM2vCjiRC+XFI304XApJDy8b2RVQaLs=

    # Key                     Value
    # ---                     -----
    # Seal Type               shamir
    # Initialized             true
    # Sealed                  false
    # Total Shares            1
    # Threshold               1
    # Version                 1.14.0
    # Build Date              2023-06-19T11:40:23Z
    # Storage Type            raft
    # Cluster Name            vault-cluster-58870b24
    # Cluster ID              39288dfb-5e4e-93f6-a085-83472f00350d
    # HA Enabled              true
    # HA Cluster              https://vault-0.vault-internal:8201
    # HA Mode                 active
    # Active Since            2023-09-26T19:59:18.358850261Z
    # Raft Committed Index    36
    # Raft Applied Index      36

Vault is fully operational from now.
Let's quit the Vault-0 pod :

    exit



## Workshop


### Vault 'read all' policy

    # Login into the Vault pod :
    k -n vault --tty --stdin exec vault-0 -- /bin/sh

    # Connect to Vault using the root token :
    vault login hvs.fJuVStEaM1h2G66LnefKsDlI

    # Write a policy allowing every paths to be read :
    vault policy write read-all - << EOF     
    path "*"                                                  
    {  capabilities = ["read"]                
    }                         
    EOF

    # Quit the pod :
    exit



### Enable Kubernetes authentication on Vault

    # Login into the Vault pod :
    k -n vault --tty --stdin exec vault-0 -- /bin/sh

    # Enable Kubernetes authentication :
    vault auth enable kubernetes

    vault auth list

    # Path           Type          Accessor                    Description                Version
    # ----           ----          --------                    -----------                -------
    # kubernetes/    kubernetes    auth_kubernetes_9a149aa4    n/a                        n/a
    # token/         token         auth_token_b498fd96         token based credentials    n/a



### Configuration of the Kubernetes authentication

    # source: https://developer.hashicorp.com/vault/docs/auth/kubernetes#kubernetes-auth-method
    #
    #   Use local service account token as the reviewer JWT
    #   
    #   When running Vault in a Kubernetes pod the recommended option is to use the pod's local service account token.
    #   Vault will periodically re-read the file to support short-lived tokens. To use the local token and CA certificate,
    #   omit token_reviewer_jwt and kubernetes_ca_cert when configuring the auth method. Vault will attempt to load them
    #   from token and ca.crt respectively inside the default mount folder /var/run/secrets/kubernetes.io/serviceaccount/.


    # Login into the Vault pod :
    k -n vault --tty --stdin exec vault-0 -- /bin/sh

    # Configuration of the Kubernetes authentication :
    vault write auth/kubernetes/config kubernetes_host=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}

    # Success! Data written to: auth/kubernetes/config
    # This role authorizes the "vault" service account in the vault namespace and it gives it the read-all policy.

    # Leave the pod :
    exit


### Role definition for the Kubernetes authentication + role binding


    # Kubernetes namespace dedicated to our application "app1" :
    kubectl create namespace ns-app1
    
    # Kubernetes service-account dedicated to "app1" :
    kubectl create sa sa-app1 -n ns-app1
    
    # Role binding 
    kubectl create clusterrolebinding sa-app1-tokenreview-access \
        --clusterrole=system:auth-delegator \
        --serviceaccount=ns-app1:sa-app1
    
      # clusterrolebinding.rbac.authorization.k8s.io/sa-app1-tokenreview-access created


    # Login to the Vault pod :
    k -n vault --tty --stdin exec vault-0 -- /bin/sh

    # Role definition allowing our service-account from namespace 'ns-app1' to read secrets from Vault :  
    vault write auth/kubernetes/role/vault-read \
        bound_service_account_names=sa-app1 \
        bound_service_account_namespaces=ns-app1 \
        policies=read-all \
        ttl=1h
    
      # Success! Data written to: auth/kubernetes/role/vault-read


    # Let's check our role 'vault-read' :
    vault read auth/kubernetes/role/vault-read
    
    # Key                                 Value
    # ---                                 -----
    # alias_name_source                   serviceaccount_uid
    # bound_service_account_names         [sa-app1]
    # bound_service_account_namespaces    [ns-app1]
    # policies                            [read-all]
    # token_bound_cidrs                   []
    # token_explicit_max_ttl              0s
    # token_max_ttl                       0s
    # token_no_default_policy             false
    # token_num_uses                      0
    # token_period                        0s
    # token_policies                      [read-all]
    # token_ttl                           1h
    # token_type                          default
    # ttl                                 1h



### Vault Secret provisioning

    # Login into the Vault pod :
    k -n vault --tty --stdin exec vault-0 -- /bin/sh

    # KV version 2 secrets engine activation :
    vault secrets enable -version=2 kv

    # Secret provisioning :
    vault kv put kv/path/to/my/secret password=secretpassword
    
        # ====== Secret Path ======
        # kv/data/path/to/my/secret
        # 
        # ======= Metadata =======
        # Key                Value
        # ---                -----
        # created_time       2023-09-26T20:34:22.588811864Z
        # custom_metadata    <nil>
        # deletion_time      n/a
        # destroyed          false
        # version            1
        # Let's leave the pod 'vault-0'    
    

    # Secrets retrieval :
    vault kv get kv/path/to/my/secret 
    
    # Let's leave the pod :
    exit



### Configuration of the External Secrets Operator (ESO)


    cat << EOF | kubectl apply -f -
    apiVersion: external-secrets.io/v1beta1
    kind: SecretStore
    metadata:
      name: ss-app1
      namespace: ns-app1
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
              role: "vault-read"
              # Optional service account field containing the name
              # of a kubernetes ServiceAccount
              serviceAccountRef:
                name: "sa-app1"
              # Optional secret field containing a Kubernetes ServiceAccount JWT
              #  used for authenticating with Vault
              #secretRef:
              #  name: "my-secret"
              #  key: "vault"
    EOF

        # secretstore.external-secrets.io/ss-app1 created


    # Check the status of our newly created secret store :
    k -n ns-app1 get ss ss-app1

        # NAME      AGE   STATUS   CAPABILITIES   READY
        # ss-app1   38m   Valid    ReadWrite      True



## Testing the good accessibility to secrets from a pod using the relevant service-account


### Executing a pod in the namespace and with the service-account both dedicated to our application 'app1'

    # Execute an Alpine pod using the service-account dedicated to our application :
    kubectl -n ns-app1 run --tty --stdin app1 --image=alpine --overrides='{ "spec": { "serviceAccount": "sa-app1" }  }' -- /bin/sh

    # Install cURL
    apk update && apk add curl

    # Find the service-account token on ths pod :
    SA_JWT_TOKEN=$( cat /var/run/secrets/kubernetes.io/serviceaccount/token )
        # -> One can check the JWT token copying and pasting it in https://jwt.io/ website.

    # Login to Vault using the JWT token :
    CLIENT_TOKEN=$( curl --silent --request POST --data '{"jwt": "'"${SA_JWT_TOKEN}"'", "role": "vault-read"}' http://vault.vault:8200/v1/auth/kubernetes/login
 | jq -r .auth.client_token )

        # {
        #   "request_id": "34b9adcd-2c2a-ec3f-c634-a011cbb49327",
        #   "lease_id": "",
        #   "renewable": false,
        #   "lease_duration": 0,
        #   "data": null,
        #   "wrap_info": null,
        #   "warnings": null,
        #   "auth": {
        #     "client_token": "hvs.CAESINcxRZaOtzL_ULx0qHhYFRJ0AaesHUPuu7w4eCQXk-SaGh4KHGh2cy5jTXkwd0FwU2U1SEI0bnhhY3ZPSHFLbGg",
        #     "accessor": "oTMgsFmcPUx2E0ziAPUkT4tM",
        #     "policies": [
        #       "default",
        #       "read-all"
        #     ],
        #     "token_policies": [
        #       "default",
        #       "read-all"
        #     ],
        #     "metadata": {
        #       "role": "vault-read",
        #       "service_account_name": "sa-app1",
        #       "service_account_namespace": "ns-app1",
        #       "service_account_secret_name": "",
        #       "service_account_uid": "3c78185b-bd8b-445c-a0b7-445d2fd28a42"
        #     },
        #     "lease_duration": 3600,
        #     "renewable": true,
        #     "entity_id": "b13136aa-8355-1bbd-6972-32033cb5fab3",
        #     "token_type": "service",
        #     "orphan": true,
        #     "mfa_requirement": null,
        #     "num_uses": 0
        #   }
        # }

    echo ${CLIENT_TOKEN}
        # -> hvs.CAESIFXYSgDelsWHSEPm_RNsbl-Oxd3tVA4D0hC8rnGaKC42Gh4KHGh2cy5kcUVRamgwOWFTTFZSaDE1dXRiMUxxZEg


#### Retrieving the secret from Vault

    curl --silent --header "X-Vault-Token:${CLIENT_TOKEN}"  http://vault.vault:8200/v1/kv/data/path/to/my/secret | jq

        # {
        #   "request_id": "b3fefd63-0005-0a36-7721-e33eeff6de9c",
        #   "lease_id": "",
        #   "renewable": false,
        #   "lease_duration": 0,
        #   "data": {
        #     "data": {
        #       "password": "secretpassword"
        #     },
        #     "metadata": {
        #       "created_time": "2023-09-26T20:34:22.588811864Z",
        #       "custom_metadata": null,
        #       "deletion_time": "",
        #       "destroyed": false,
        #       "version": 1
        #     }
        #   },
        #   "wrap_info": null,
        #   "warnings": null,
        #   "auth": null
        # }

        # -> password : secretpassword ^^
