# Cluster GKE en mode autopilot, load-balancer HTTPS et application 'stateless'

Pour me former à Google Kubernetes Engine (GKE), j'ai suivi le tutoriel suivant mais avec beaucoup de difficulté car il comporte des erreurs. Sur la base du tutoriel de Google, j'ai documenté la manière dont je m'y suis pris pour arriver à déployer un cluster GKE avec un load-balancer exposé à internet permettant d'accéder en HTTPS à une petite application 'stateless'.

      # Tutoriel Google : Configurer la mise en réseau pour un cluster de production de base
      https://cloud.google.com/kubernetes-engine/docs/tutorials/configure-networking?hl=en.


## Pré-requis
- Disposer d'un compte Google et accéder à la console GCP ( https://console.cloud.console.com )
- Avoir créé un projet (renseigner son ID dans la variable ${PROJECT_ID} ci-après)
- Lancer CloudShell (les commandes qui suivent seront exécutées dans CloudShell)

## Variables
- Se connecter à la console GCP
- Sélectionner le projet souhaité et dont l'ID est renseigné dans la variable ${PROJECT_ID} ci-dessous.

      PROJECT_ID="project-230902"                   # ID du projet GCP
      REGION="europe-west4"                         # Netherlands
      CLUSTER_NAME="sandbox-cluster"                # nom du cluster
      RESERVED_DOMAIN_NAME="vanille-fraise.net"     # Nom de domaine réservé auprès d'un 'registrar'
      APPLICATION_NAME="hello"                      # Nom de l'application


## Configurer votre environnement

      rm -rf ~/.kube                                    # nettoyage
      rm -rf .terraform* terraform.tfstate              # nettoyage

      # configuration de kubectl
      gcloud config set project ${PROJECT_ID}
      gcloud services enable compute.googleapis.com     # nécessaire pour définir la région (la commande prend du temps)
      gcloud config set compute/region ${REGION} 
    
      gcloud config list


## Activer les API Google Kubernetes Engine, Cloud DNS. 

      gcloud services enable container.googleapis.com
      gcloud services enable dns.googleapis.com
      gcloud services list --enabled --project ${PROJECT_ID}


## Récupération du code depuis GitHub
      git clone https://github.com/papaFrancky/cluster_GKE_SSL_load-balancer
      cd cluster_GKE_SSL_load-balancer

( Via la WUI GitHub : https://github.com/papaFrancky/cluster_GKE_SSL_load-balancer.git )



## Déploiement du cluster GKE

( doc. utile :  HashiCorp - provider Google https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)

Nous allons surcharger la valeur par défaut de certaines variables en écrivant un fichier '.auto.tfvars' :

      cat << EOF > cluster.auto.tfvars
      region               = "${REGION}"
      reserved_domain_name = "${RESERVED_DOMAIN_NAME}"
      cluster_name         = "${CLUSTER_NAME}"
      application_name     = "${APPLICATION_NAME}"
      EOF

Nous pouvons ensuite exécuter le code Terraform :

      terraform init
      terraform plan
      terraform apply --auto-approve


Exemple de sortie : 

      Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
      
      Outputs:
      
      cluster_name = "sandbox-cluster"
      dns_zone_name_servers = tolist([
        "ns-cloud-c1.googledomains.com.",
        "ns-cloud-c2.googledomains.com.",
        "ns-cloud-c3.googledomains.com.",
        "ns-cloud-c4.googledomains.com.",
      ])
      domain = "hello.vanille-fraise.net"
      region = "europe-west4"


## Vérification du déploiement

### DNS 
Via la console :

      https://console.cloud.google.com/net-services/dns/zones/${APPLICATION_NAME}/details?organizationId=0&project=${PROJECT_ID}

### Cluster Kubernetes
Via la console :

      https://console.cloud.google.com/kubernetes/list/overview?organizationId=0&project=${PROJECT_ID}

### IP statique publique
Via la console :

      https://console.cloud.google.com/networking/addresses/list?organizationId=0&project=${PROJECT_ID}


## Modification des 'Name Servers (NS) du domaine DNS auprès du 'registrar'

Même si vous avez réservé votre nom de domaine chez le 'registrar' _Google Domains_, vous devez modifier directement auprès de votre 'registrar' les serveurs de noms (NS) de votre zone et les remplacer par ceux listés en sortie du 'terraform apply'.
Dans notre exemple :

      ns-cloud-c1.googledomains.com
      ns-cloud-c2.googledomains.com
      ns-cloud-c3.googledomains.com
      ns-cloud-c4.googledomains.com

Dans mon cas, j'ai réservé mon nom de domaine auprès du registrar _Google Domains_ :

      https://domains.google.com/registrar/${RESERVED_DOMAIN_NAME}/dns 
          -> cliquer sur 'Serveurs de noms personnalisés'
          -> puis cliquer sur 'Gérer les serveurs de noms'
          -> Renseigner les serveurs de noms issus de la sortir de la commande 'terraform apply' (dns_zone_name_servers)

Vérifier la résolution de noms :

      dig ${APPLICATION_NAME}.${RESERVED_DOMAIN_NAME}
          ;; ANSWER SECTION:
          hello.vanille-fraise.net. 300 IN  A       34.36.92.137
    
      dig www.${APPLICATION_NAME}.${RESERVED_DOMAIN_NAME}
          ;; ANSWER SECTION:
          www.hello.vanille-fraise.net. 300 IN CNAME hello.vanille-fraise.net.
          hello.vanille-fraise.net. 300 IN  A       34.36.92.137


  Vérifier également dans CloudDNS dans la zone '${APPLICATION_NAME}' les entrées de type NS et SOA et s'assurer qu'elles correspondent bien aux serveurs de noms attendus :
  
        https://console.cloud.google.com/net-services/dns/zones/${APPLICATION_NAME}/details?organizationId=0&project=${PROJECT_ID}



## Déploiement du Load-Balancer applicatif externe
( ManagedCertificate, FrontendConfig, Deployment, Service et Ingress)



### Configuration de kubectl pour se connecter au cluster récemment créé

      gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project=${PROJECT_ID}
      -> génère le fichier de configuration de kubectl : ~/.kube/config

#### Vérifier que nous utilisons le bon contexte kubernetes :

      kubectl config view | grep current-context 
      -> current-context: gke_${PROJECT_ID}_${REGION}_${CLUSTER_NAME}

#### Vérifier que nous pouvons bien nous connecter au cluster

      kubectl get pods -A 
      -> retourne la liste de tous les pods du cluster



### Création du certificat SSL, du load-balancer, de l'ingress 

      kubectl apply -f kubernetes-manifests.yaml
      ( note : la validation du certificat TLS prend 30 minutes environ )

#### Vérification de la création de l'ingress

      kubectl describe ingress frontend

#### Vérification du provisioning du certificat TLS (peut prendre 30 minutes)
##### avec kubectl

      kubectl get      managedcertificates.networking.gke.io frontend-managed-cert
      kubectl describe managedcertificates.networking.gke.io frontend-managed-cert

##### via la console : Security / Certificate Manager

      https://console.cloud.google.com/apis/library/certificatemanager.googleapis.com?project=${PROJECT_ID}
      -> activer Secret Manager API
      -> cliquer sur 'CLASSIC CERTIFICATES' -> on voit le certificat en status : provisioning
      
      ( note : activer l'API 'Certificate Manager' pour accéder au certificat )

##### Documentation de troubleshooting Google-managed SSL certificates :

      https://cloud.google.com/load-balancing/docs/ssl-certificates/troubleshooting?hl=en
      https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs?hl=en#caa
      https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs?hl=en



#### Vérification de l'adresse IP publique réservée

      gcloud compute addresses describe ${APPLICATION_NAME} --global

#### Vérification de l'Ingress

      k get ingress

      NAME       CLASS    HOSTS   ADDRESS          PORTS   AGE
      frontend   <none>   *       34.117.157.187   80      5m41s

L'IP du load-balancer est ici **34.117.157.187**.




## Test application

      curl -Lv https://${APPLICATION_NAME}.${RESERVED_DOMAIN_NAME}
      curl -Lv https://www.${APPLICATION_NAME}.${RESERVED_DOMAIN_NAME}

En accédant plusieurs fois à l'URL, on constate que le 'hostname' (ie. le pod) change. 

## Nettoyage

      gcloud projects delete ${PROJECT_ID} --quiet
      gcloud projects list

ou :

    kubectl delete -f kubernetes-manifests.yaml
    terraform destroy --auto-approve




## Divers 
https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_gke_with_terraform

Debug Cloud DNS :

      gcloud dns managed-zones describe ${APPLICATION_NAME}
      gcloud dns record-sets list --zone ${APPLICATION_NAME}
      gcloud dns record-sets list --zone=${APPLICATION_NAME} --name ${APPLICATION_NAME}.${RESERVED_DOMAIN_NAME}


## Next step
https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/
