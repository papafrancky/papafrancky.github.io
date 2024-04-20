# Deploy WordPress on GKE with Persistent Disk and Cloud SQL

Doc de référence : https://cloud.google.com/kubernetes-engine/docs/tutorials/persistent-disk?hl=en


## Variables

    export PROJECT_ID="project-230903"
    export REGION="europe-west4"
    export CLUSTER_NAME="sandbox-cluster"
    export INSTANCE_NAME="mysql-wordpress-instance"
    export SA_NAME="cloudsql-proxy"


## Actions préalables

### Nettoyage des traces des workshops précédents

    rm -rf ~/.kube

### Configuration de l'environnement

    gcloud config set project ${PROJECT_ID}
    gcloud services enable compute.googleapis.com container.googleapis.com sqladmin.googleapis.com
    gcloud config set compute/region ${REGION}
    gcloud config list

### Récupération des manifests Kubernetes

    git clone https://github.com/papaFrancky/cluster_GKE_Wordpress_CloudSQL
    cd cluster_GKE_Wordpress_CloudSQL
    WORKING_DIR=$(pwd)


## Création du cluster GKE

    gcloud container clusters create-auto ${CLUSTER_NAME}

    
Une fois le cluster créé, on génère les informations de connexion à ce dernier :

    gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION}

-> La commande créé le fichier ~/.kube/config


## Création d'un Persistent Volume (PV) et d'un Persistent Volume Claim (PVC)

    kubectl apply -f ${WORKING_DIR}/wordpress.persistent_volume_claim.yaml
    kubectl get persistentvolumeclaim


## Création d'une instance MySQL dans Cloud SQL

    gcloud sql instances create ${INSTANCE_NAME} --region ${REGION}


## Création de la base de données pour WordPress

    export INSTANCE_CONNECTION_NAME=$( gcloud sql instances describe ${INSTANCE_NAME} --format='value(connectionName)' )
    gcloud sql databases create wordpress --instance ${INSTANCE_NAME}
    
    Creating Cloud SQL database...done.                            
    Created database [wordpress].
    instance: mysql-wordpress-instance
    name: wordpress
    project: project-230903


## Création du DB account 'wordpress' avec mot de passe pour s'authentifier à l'instance

    CLOUD_SQL_PASSWORD=$(openssl rand -base64 18)
    echo ${CLOUD_SQL_PASSWORD}          # exemple: H3nzTp+bBmZ/3xpVswovAPG+
    gcloud sql users create wordpress --host=% --instance ${INSTANCE_NAME}  --password ${CLOUD_SQL_PASSWORD}


## Déploiement de WordPress

### Service-account et secrets

#### Création du service-account 

    gcloud iam service-accounts create ${SA_NAME} --display-name ${SA_NAME}

#### Ajout du rôle cloudsql.client a uservice account

    SA_EMAIL=$( gcloud iam service-accounts list --filter=displayName:$SA_NAME --format='value(email)' )
    # exemple: cloudsql-proxy@project-230902-2.iam.gserviceaccount.com
    gcloud projects add-iam-policy-binding ${PROJECT_ID} --role roles/cloudsql.client --member serviceAccount:${SA_EMAIL}

#### Création d'une clé pour le service-account

    gcloud iam service-accounts keys create ${WORKING_DIR}/key.json --iam-account ${SA_EMAIL}
    
    cat key.json 
    {
      "type": "service_account",
      "project_id": "project-230903",
      "private_key_id": "8b541bab674bf3f252b2337a6fff83fe496dc628",
      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCiU+nwSgzLmOA4\nDY8AX1DtaWhrW4iqtNEOYHArdLmOZiS/Baknd4PiC/u3Y9Cn+j7vXg2rnjA4AvJM\nc1tSf4BJMsGT2RYbYluO/s0mysPMSz7/YLvWdATHDZEl9fPFJY6O8cEBg8kWwCal\nSo3ZqFHyPznf1E2QBcZFrLXDAxBjBDzTUOgxG1GiIh2v/oSYxU8PppLitUZ7rlV\nDrv2gz4PXaE9RLgiEPLAZ3HLtIM4KE6jLt1j6MVDKl7vzdONLjgWE7t+dZRzWPqo\nx9EccR4P9dYq9c4ZstUI6ZjMWg3JVD3JbnciEUuePX+WCK3usSKtDCsyKAgBHo/w\nwOEKej2ZAgMBAAECggEAFvEyMpZcqZfRNMrhx6UxDGTl76pvreTBWT1TDSlBonkY\nP3E+34eaOaQE7v3p+xu4sl8CIpvIZ9ouwZRaN1Yy3OWSC2HWqIcltpeXiiCFPMXz\nwOc8lQovtKxbs9hHnDj7JYPQifTEwnTk4V6gnr8V2d2KwfJBBhZy190ZkVbJBZ1V\nld4BVlSPDZVU/NIOLgke/ZG+d1qxR/NfRK7a/IrbZeiqyQuuif4y37o+bG+TT5Hy\nL4okx8aoy+8dyhxe6CNRfL4nWVCJaYZam0SCEPY4rb5C9i7EUdGQj+6fWg1l82BJ\nOa9WzPwotdDHkS7KoiZ0IzrYToWxjeTcyOGqLJvDKwKBgQDMqGHc+C6irnsIsHBu\n6dUkAsPBsTqwKASGogjeHoC2vWwALNJk/59gB7c0TvYUc2HaugSRqAfcZGaZOMBI\n6g4DJuFtBMyFoYXF2j8GU17VQ3APzpFQC+s4tf2TpW9srulHIBErMmgPq0Mpig6k\nla6d+EwMlvcYXa71LI9MCmOpwwKBgQDLDP+7UxLCKA7gNHCUrc98MPP5VgAkNWdE\n7N3T6R9QyEaK5HYKLaiCCzMMV2QFWiAo4w/WTQXcLn1prFMl781X9tkysxiSgDAY\nVgAcg0bVsziog1erC/HqFZ1zSTHokX2zEqafGtHGMl3dbyWdCOJIvViyKDc4wNFb\nO6JUv1xpcwKBgEdSOuCd4OqysYCpTwR40Rsbjn3AIPZPlKI71ww9xw4AQZCmIO4\nDZuStMbW6a0Q1L4761GzZCHrH1IwU9pVLtLsXsz2SiwbsRnVR/d1YGwj10665ysl\nLDEUQy2MDruqbQNranBKXbdwMLSuNxImU7cbi60rgysLougwQjP2vuqvAoGABe7k\nThn4U1oOTTjbDU0i4fMgPenoaSZyVQ5C0R1fv+GKRia02ElLQjmHjVXEY2+lvuwb\nm1x2zl9BZOQXLeWa73YUFKotDqLWRO/GYw7m8mfrzTfS+02bWuiRSsfXTdbH+9s\nlPuYo5z3JzBHPhZzXkLCI7qPGoZv16WfcbCBx8cCgYEArU7693uPHp/V23SWLeW8\nPU5qW9jkiFNtAF+sErLuFWtmxxz1uoEmRb8YvLPzZkyeI5v/wu7PD0a9hG4yHaGN\nwySgdAAF3AUgBZOPLMq4LqEGjqOT3lrT7fyjgaPcQ0civ1UKbiNVwSry+68GgFY\n9Jox8EDrq4vjW65sIer7XdY=\n-----END PRIVATE KEY-----\n",
      "client_email": "cloudsql-proxy@project-230903.iam.gserviceaccount.com",
      "client_id": "109534044814238678605",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/cloudsql-proxy%40project-230903.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    }

#### Création d'un 'secret' kubernetes pour les credentials MySQL

    kubectl create secret generic cloudsql-db-credentials --from-literal username=wordpress --from-literal password=${CLOUD_SQL_PASSWORD}

#### Création d'un 'secret' kubernetes pour pour les credentials du service account

    kubectl create secret generic cloudsql-sa-credentials --from-file ${WORKING_DIR}/key.json


### Déploiement de WordPress

    cat ${WORKING_DIR}/wordpress.deployment.yaml.template | envsubst > ${WORKING_DIR}/wordpress.deployment.yaml
    kubectl create -f ${WORKING_DIR}/wordpress.deployment.yaml
    kubectl get pod -l app=wordpress --watch


## Exposition du service WordPress

    kubectl create -f ${WORKING_DIR}/wordpress.service.yaml
    kubectl get svc -l app=wordpress --watch

    NAME        TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
    wordpress   LoadBalancer   34.118.227.43   34.90.114.238   80:32487/TCP   46s

Une fois l'EXTERNAL-IP visible, on peut se connecter au service.


## Configuration du blog WordPress

    http://34.91.93.136

-> Fin du workshop !


## Suppression des ressources

    kubectl delete service wordpress
    kubectl delete deployment wordpress
    kubectl delete pvc wordpress-persistent-volume-claim
    gcloud container clusters delete ${CLUSTER_NAME}
    gcloud sql instances delete ${INSTANCE_NAME}
    gcloud projects remove-iam-policy-binding ${PROJECT_ID} --role roles/cloudsql.client --member serviceAccount:${SA_EMAIL}
    gcloud iam service-accounts delete ${SA_EMAIL}



## Todo

* déployer le cluster GKE via __Terraform__ plutôt que via la CLI
* Exposer le service en __HTTPS__
* Certificat __wildcard__ créé manuellement ? Peut-être attendre Vault
* Idéalement, configurer un __Ingress__ capable de router vers __plusieurs services__
* Confier les secrets à __Vault__
* Tester le déploiement de WordPress via un __Helm Chart__
* Implémenter GitOps avec __FluxCD__


## Trucs utiles

* pour ouvrir un IDE : 

    https://shell.cloud.google.com/?pli=1&show=ide%2Cterminal
