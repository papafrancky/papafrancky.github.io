# Cluster [kind|minikube] - HashiCorp Vault with Raft integrated storage


| Description | URL |
| :--- | :--- |
| Vault installation to minikube via Helm with Integrated Storage | https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-raft |
| Vault : Kubernetes auth method | https://developer.hashicorp.com/vault/docs/auth/kubernetes |
| Configure Hashicorp's Vault for Kubernetes Auth | https://docs.armory.io/continuous-deployment/armory-admin/secrets/vault-k8s-configuration/ |



## Installation de Vault avec Helm


### Déploiement de la Helm release

    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    helm search repo hashicorp/vault
    helm show values hashicorp/vault # affiche toutes les 'values' surchargeables. 
    
    cat > helm-vault-raft-values.yml <<EOF
    server:
      affinity: ""
      ha:
        enabled: true
        raft: 
          enabled: true
    EOF
    
    helm install vault hashicorp/vault --values helm-vault-raft-values.yml


### Vérification du bon fonctionnement des pods Vault

    kubectl get po -l app.kubernetes.io/name=vault
    
    NAME      READY   STATUS    RESTARTS   AGE
    vault-0   0/1     Running   0          4m8s
    vault-1   0/1     Running   0          4m6s
    vault-2   0/1     Running   0          4m5s



## Vault init | Vault unseal


### Initialisation de vault-0 avec 1 'key share' et 1 'key threshold'
__note :__ cette approche n'est pas compatible avec de la production '

    kubectl exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json

    cat cluster-keys.json 
    {
      "unseal_keys_b64": [
        "4HrwZMZahnLrsdpxI8WHyNDRwc/S7kHZyILIL5HT5Mw="
      ],
      "unseal_keys_hex": [
        "e07af064c65a8672ebb1da7123c587c8d0d1c1cfd2ee41d9c882c82f91d3e4cc"
      ],
      "unseal_shares": 1,
      "unseal_threshold": 1,
      "recovery_keys_b64": [],
      "recovery_keys_hex": [],
      "recovery_keys_shares": 0,
      "recovery_keys_threshold": 0,
      "root_token": "hvs.O8Lr0M0YtUG2T8WUJYDNerLs"
    }
    
    VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)        # -> 4HrwZMZahnLrsdpxI8WHyNDRwc/S7kHZyILIL5HT5Mw=
    
    kubectl exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
    kubectl exec -ti vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
    kubectl exec -ti vault-2 -- vault operator raft join http://vault-0.vault-internal:8200
    kubectl exec -ti vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
    kubectl exec -ti vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY


## Création d'un Secret 

    ROOT_TOKEN=$( jq -r ".root_token" cluster-keys.json )       # hvs.O8Lr0M0YtUG2T8WUJYDNerLs
    kubectl exec --stdin=true --tty=true vault-0 -- /bin/sh
    
      # Dans le pod 'vault-0' :
      
      vault login ${ROOT_TOKEN}                                   # entrer le token root 
      vault secrets enable -path=secret kv-v2
      vault kv put secret/wordpress/mysql username="mysql-account" password="mysql-account-password"
      
      ======= Secret Path =======
      secret/data/wordpress/mysql
      
      ======= Metadata =======
      Key                Value
      ---                -----
      created_time       2023-09-05T13:35:01.042933683Z
      custom_metadata    <nil>
      deletion_time      n/a
      destroyed          false
      version            1


      vault kv get secret/wordpress/mysql
      
      ======= Secret Path =======
      secret/data/wordpress/mysql
      
      ======= Metadata =======
      Key                Value
      ---                -----
      created_time       2023-09-05T13:35:01.042933683Z
      custom_metadata    <nil>
      deletion_time      n/a
      destroyed          false
      version            1
      
      ====== Data ======
      Key         Value
      ---         -----
      password    mysql-account-password
      username    mysql-account
      
      exit                    # exit session from pod vault-0


## Configuration de l'authentification Kubernetes

    kubectl exec --stdin=true --tty=true vault-0 -- /bin/sh
    
      # Dans le pos 'vault-0' :
    
      vault auth enable kubernetes
      vault write auth/kubernetes/config kubernetes_host="https://${KUBERNETES_PORT_443_TCP_ADDR}:443"
      vault read auth/kubernetes/config
    
      Key                       Value
      ---                       -----
      disable_iss_validation    true
      disable_local_ca_jwt      false
      issuer                    n/a
      kubernetes_ca_cert        n/a
      kubernetes_host           https://10.96.0.1:443
      pem_keys                  []


      vault policy write wordpress - <<EOF
      path "secret/*" {
          capabilities = ["list"]
      }
      path "secret/data/wordpress/*" {
        capabilities = ["read","list"]
      }
      EOF


    vault policy read wordpress
    path "secret/data/wordpress/mysql" {
     capabilities = ["read"]
    }


    vault write auth/kubernetes/role/wordpress \
      bound_service_account_names=vault \
      bound_service_account_namespaces=default \
      policies=wordpress ttl=24h
    


## Déploiement d'un pod avec le service-account 'vault'  


    echo > fedora.deployment.yml << EOF
    
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      labels:
        app: fedora
      name: fedora
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: fedora
      template:
        metadata:
          creationTimestamp: null
          labels:
            app: fedora
        spec:
          serviceAccountName: vault
          containers:
          - image: fedora
            name: fedora
            command: ['sleep', '10000']
    EOF

    # Vérification :
    kubectl get deployments,pods -l app=fedora
    
    NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/fedora   1/1     1            1           168m
    
    NAME                         READY   STATUS    RESTARTS       AGE
    pod/fedora-5c4dc7445-697pm   1/1     Running   1 (106s ago)   168m


## S'assurer que le pod peut bien accéder au secret 'wordpress/mysql' dans Vault 

    # Connexion au pod :
    kubectl exec --tty --stdin fedora-5c4dc7445-697pm -- /bin/bash
   
    # Installation de Vault : 
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
    dnf -y install vault

    # Test du bon accès au secret 'wordpress/mysql'
    
    export VAULT_ADDR="http://${VAULT_SERVICE_HOST}:${VAULT_SERVICE_PORT}"
    SA_TOKEN=$( cat /var/run/secrets/kubernetes.io/serviceaccount/token )
    VAULT_TOKEN=$( vault write auth/kubernetes/login role=wordpress jwt=${SA_TOKEN} | grep -w ^token | awk '{print $2}' )

    vault login ${VAULT_TOKEN}
    vault kv list -mount=secret wordpress
    vault kv get -mount=secret wordpress/mysql      # même chose que "vault kv get /secret/wordpress/mysql"

