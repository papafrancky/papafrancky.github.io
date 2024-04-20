# Mise à jour des clusters Kubernetes

|||
|---|---|
|Doc opsfi|https://github.com/dktunited/finance-doc-opsfi/blob/master/docs/platforms/kubernetes/exploit/upgrade/README.md|

Ces notes visent à montrer par l'exemple comment mettre à jour un cluster Kubernetes dans notre contexte professionnel.

Pour notre exemple :

|||
|---|---|
|environnement|hors production|
|version cible de GKE|1.28.6-gke.1289000|


## Login et contexte Kubernetes

    gcloud config list
    gcloud config set project finance-6ztj
    gcloud config set compute/region europe-west4
    
    gcloud auth login
    kubecxt gke_finance-6ztj_europe-west4_hp


## Mise à jour du control-plane
Nous passons par la UI pour effectuer cette mise à jour.

## Mise à jour des node-pools

### Procédure 

* création de nouveaux node pools à la version GKE cible;
* marquer les noeuds comme non planifiables (kubectl cordon)
* déplacer les pods vers les noeuds aux versions plus récentes (kubectl drain)


### Création de nouveaux node pools à la version GKE cible

Nous disposons de 2 node-pools :
|NODE POOL|NUMBER OF NODES|MACHINE TYPE|
|---|---|---|
|petit|3 (1 par zone)|n2-standard-4|
|grand|6 (2 par zone)|n2-standard-8|

**Note** - nous nous posons la question de maintenir 2 node pools différents puisqu'aucune de nos applications ne sont rattachées spécifiquement à un node pool plutôt qu'un autre.


#### Création du _petit_ node pool à la version de GKE cible

    CLUSTER="hp"                        # nom du cluster (correspond à l'environnement servi)
    PROJECT="finance-6ztj"              # projet gcp
    REGION="europe-west4"               # région gcp
    NEXT_VERSION=28                     # valeur incrémentée par nos soins à chaque màj
    NODE_VERSION="1.28.6-gke.1289000"   # la version cible de GKE
    NODE_TYPE="n2-standard-4"           # valeur correspondant au petit node-pool 
    NUM_NODES=1                         # valeur correspondant au petit node-pool (nombre de noeuds par zone)
    NUM_CPUS=4                          # dépend du type de node retenu.
    TAGS="\"rt-default-zscaler-valpha0\",\"net-main-gkenodes\",\"net-main-gkenodesfinance-europe-west4\""
    SCOPES="\"https://www.googleapis.com/auth/devstorage.read_only\",\"https://www.googleapis.com/auth/logging.write\",\"https://www.googleapis.com/auth/monitoring\",\"https://www.googleapis.com/auth/cloud-platform\",\"https://www.googleapis.com/auth/servicecontrol\",\"https://www.googleapis.com/auth/service.management.readonly\",\"https://www.googleapis.com/auth/trace.append\""
    
        gcloud container node-pools create "app-${NUM_CPUS}-cpu-v${NEXT_VERSION}-200go" \
            --project ${PROJECT} \
            --region ${REGION} \
            --cluster ${CLUSTER} \
            --node-version "${NODE_VERSION}" \
            --machine-type "${NODE_TYPE}" \
            --image-type "COS_CONTAINERD" \
            --disk-type "pd-standard" \
            --disk-size "200" \
            --node-labels type=app \
            --metadata disable-legacy-endpoints=true \
            --scopes ${SCOPES} \
            --num-nodes "${NUM_NODES}" \
            --no-enable-autoupgrade \
            --shielded-integrity-monitoring \
            --shielded-secure-boot \
            --enable-autorepair \
            --max-surge-upgrade 1 \
            --max-unavailable-upgrade 0 \
            --tags ${TAGS}

Vérification

    gcloud container node-pools list --region ${REGION} --cluster ${CLUSTER}

        NAME                   MACHINE_TYPE   DISK_SIZE_GB  NODE_VERSION
        app-4-cpu-v27-9-200go  n2-standard-4  200           1.27.9-gke.1092000
        app-8-cpu-v27-9-200go  n2-standard-8  200           1.27.9-gke.1092000
        app-4-cpu-v28-200go    n2-standard-4  200           1.28.6-gke.1289000


#### Création du _grand_ node pool à la version de GKE cible

    CLUSTER="hp"                        # nom du cluster (correspond à l'environnement servi)
    PROJECT="finance-6ztj"              # projet gcp
    REGION="europe-west4"               # région gcp
    NEXT_VERSION=28                   # valeur incrémentée par nos soins à chaque màj
    NODE_VERSION="1.28.6-gke.1289000"   # la version cible de GKE
    NODE_TYPE="n2-standard-8"           # valeur correspondant au petit node-pool 
    NUM_NODES=2                         # valeur correspondant au petit node-pool (nombre de noeuds par zone)
    NUM_CPUS=8                          # dépend du type de node retenu.
    TAGS="\"rt-default-zscaler-valpha0\",\"net-main-gkenodes\",\"net-main-gkenodesfinance-europe-west4\""
    SCOPES="\"https://www.googleapis.com/auth/devstorage.read_only\",\"https://www.googleapis.com/auth/logging.write\",\"https://www.googleapis.com/auth/monitoring\",\"https://www.googleapis.com/auth/cloud-platform\",\"https://www.googleapis.com/auth/servicecontrol\",\"https://www.googleapis.com/auth/service.management.readonly\",\"https://www.googleapis.com/auth/trace.append\""
    
        gcloud container node-pools create "app-${NUM_CPUS}-cpu-v${NEXT_VERSION}-200go" \
            --project ${PROJECT} \
            --region ${REGION} \
            --cluster ${CLUSTER} \
            --node-version "${NODE_VERSION}" \
            --machine-type "${NODE_TYPE}" \
            --image-type "COS_CONTAINERD" \
            --disk-type "pd-standard" \
            --disk-size "200" \
            --node-labels type=app \
            --metadata disable-legacy-endpoints=true \
            --scopes ${SCOPES} \
            --num-nodes "${NUM_NODES}" \
            --no-enable-autoupgrade \
            --shielded-integrity-monitoring \
            --shielded-secure-boot \
            --enable-autorepair \
            --max-surge-upgrade 1 \
            --max-unavailable-upgrade 0 \
            --tags ${TAGS}

Vérification

    gcloud container node-pools list --region ${REGION} --cluster ${CLUSTER}

        NAME                   MACHINE_TYPE   DISK_SIZE_GB  NODE_VERSION
        app-4-cpu-v27-9-200go  n2-standard-4  200           1.27.9-gke.1092000
        app-8-cpu-v27-9-200go  n2-standard-8  200           1.27.9-gke.1092000
        app-4-cpu-v28-200go    n2-standard-4  200           1.28.6-gke.1289000
        app-8-cpu-v28-200go    n2-standard-8  200           1.28.6-gke.1289000


**Note** - Si on s’est trompé sur le nombre de noeuds par node pools, il est possible de corriger la chose comme suit :

    gcloud container clusters resize ${CLUSTER} \
        --num-nodes ${NUM_NODES} \
        --node-pool app-${NUM_CPUS}-cpu-v${NEXT_VERSION}-200go \
        --region ${REGION}
    
    ex :
    gcloud container clusters resize hp \
        --num-nodes 2 \
        --node-pool app-8-cpu-v28-200go \
        --region europe-west4



## Marquage des noeuds comme non planifiables (kubectl cordon)

Marquer un nœud comme non planifiable empêche la planification de nouveaux pods sur ce nœud, mais n'affecte pas les pods existants sur le nœud.

    PRINT_COMMAND=true
    PREVIOUS_VERSION="27-9"
    
    for NODE in $( kubectl get nodes | grep "v${PREVIOUS_VERSION}" | awk '{print $1}' ); do
      if ${PRINT_COMMAND}; then
        echo "kubectl cordon ${NODE}"
      else
        kubectl cordon ${NODE}
      fi
    done

        kubectl cordon  gke-hp-app-4-cpu-v27-9-200go-42347f56-j5t0
        kubectl cordon  gke-hp-app-4-cpu-v27-9-200go-479d4396-xdwz
        kubectl cordon  gke-hp-app-4-cpu-v27-9-200go-62b65060-lhkz
        kubectl cordon  gke-hp-app-8-cpu-v27-9-200go-352e9832-090l
        kubectl cordon  gke-hp-app-8-cpu-v27-9-200go-352e9832-70p2
        kubectl cordon  gke-hp-app-8-cpu-v27-9-200go-858d2ea9-0bkq
        kubectl cordon  gke-hp-app-8-cpu-v27-9-200go-858d2ea9-t0r2
        kubectl cordon  gke-hp-app-8-cpu-v27-9-200go-d1ae30d5-nkbx
        kubectl cordon  gke-hp-app-8-cpu-v27-9-200go-d1ae30d5-pwt8

Si la commande renvoie bien les commandes attendues, passer la variable PRINT_COMMAND à false et rejour le script.


Surveillance :

    watch -n 1 kubectl get pods -A --field-selector=status.phase!=Running



## Déplacement les pods vers les noeuds aux versions plus récentes (kubectl drain)


### Identification des éventuels problèmes liés aux Pods Disruption Budgets (PDB)

    kubectl get pdb -A
    
        NAMESPACE        NAME                                      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
        istio-system     istiod                                    1               N/A               0                     432d
        nginx-internal   nginx-internal-ingress-nginx-controller   1               N/A               1                     74d

-> le PDB _**'istiod'**_ dans le namespace 'istio-system' a un **'allowed disruptions' positionné à 0**, ce qui peut être source de problèmes.

    kubectl get pods -n istio-system -o wide

        NAME                      READY   STATUS    RESTARTS   AGE   IP             NODE                                         NOMINATED     NODE   READINESS GATES
        istiod-7589db68cc-xxcpb   1/1     Running   0          11d   10.41.204.26   gke-hp-app-8-cpu-v27-9-200go-d1ae30d5-nkbx   <none>        <none>

-> le pod auquel est rattaché le PDB se trouve sur un noeud du 'grand' node pool (8 cpu). Nous pouvons faire le 'drain' sur le 'petit' node pool.


### Drainage le 'petit' node pool (pas de problèmes éventuels avec le PDB d'Istiod)

    CLUSTER="hp"                        # nom du cluster (correspond à l'environnement servi)
    NUM_CPUS=4                          # 4 pour le petit node pool; 8 pour le grand.
    PRINT_COMMAND=true
    PREVIOUS_VERSION="27-9""
    NODE_PREFIX=gke-${CLUSTER}-app-${NUM_CPUS}-cpu-v${PREVIOUS_VERSION}-200go
    
    for NODE in $( kubectl get nodes | grep ${NODE_PREFIX} | awk '{print $1}' ); do
      if ${PRINT_COMMAND}; then
        echo "kubectl drain ${NODE} --ignore-daemonsets --delete-emptydir-data"
      else
        kubectl drain ${NODE} --ignore-daemonsets --delete-emptydir-data
      fi
    done

        kubectl drain gke-hp-app-4-cpu-v27-9-200go-42347f56-j5t0 --ignore-daemonsets --delete-emptydir-data
        kubectl drain gke-hp-app-4-cpu-v27-9-200go-479d4396-xdwz --ignore-daemonsets --delete-emptydir-data
        kubectl drain gke-hp-app-4-cpu-v27-9-200go-62b65060-lhkz --ignore-daemonsets --delete-emptydir-data

**Note** - Il est peut-être préférable de faire les 'drain' un à un manuellement pour gérer les problèmes éventuels de PDB.


Vérification du bon déroulement de l'opération :

    kubectl get nodes
    -> avec le cordon, les anciens noeuds pasent au statut ‘schedulingdisabled’

        NAME                                         STATUS                     ROLES    AGE   VERSION
        gke-hp-app-4-cpu-v27-9-200go-42347f56-j5t0   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-4-cpu-v27-9-200go-479d4396-xdwz   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-4-cpu-v27-9-200go-62b65060-lhkz   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-4-cpu-v28-200go-8d133288-qmg4     Ready                      <none>   33m   v1.28.6-gke.1289000
        gke-hp-app-4-cpu-v28-200go-984857d0-3521     Ready                      <none>   33m   v1.28.6-gke.1289000
        gke-hp-app-4-cpu-v28-200go-fb63cd12-0jhk     Ready                      <none>   33m   v1.28.6-gke.1289000
        gke-hp-app-8-cpu-v27-9-200go-352e9832-090l   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-9-200go-352e9832-70p2   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-9-200go-858d2ea9-0bkq   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-9-200go-858d2ea9-t0r2   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-9-200go-d1ae30d5-nkbx   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-9-200go-d1ae30d5-pwt8   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v28-200go-28e2b668-s4z4     Ready                      <none>   25m   v1.28.6-gke.1289000
        gke-hp-app-8-cpu-v28-200go-77e1408b-ccpw     Ready                      <none>   25m   v1.28.6-gke.1289000
        gke-hp-app-8-cpu-v28-200go-c6a37d33-ws6h     Ready                      <none>   25m   v1.28.6-gke.1289000


### Bascule d'Istiod sur le nouveau node-pool (qui n'est pas en 'cordon')

Pour gérer sereinement le problème de PDB, nous allons **forcer le re-déploiement d'Istiod**.

Ce dernier ne pourra aller ailleurs que sur le nouveau node pool provisionné car les autres sont toujours en _**'cordon'**_.

    kubectl -n istio-system rollout restart deploy istiod
    
    kubectl -n istio-system get pod -o wide

    kubectl -n istio-system get po

        NAME                      READY   STATUS    RESTARTS   AGE
        istiod-6f4d65d7f8-6t5bz   1/1     Running   0          87s

-> Maintenant qu'Istiod a basculé sur le nouveau node-pool, nous pouvons 'drainer' le node pool restant.


### Drainage le 'petit' node pool (pas de problèmes éventuels avec le PDB d'Istiod)

Pour identifier les labels rattachés aux noeuds du cluster :

    kubectl get nodes --show-labels

-> Le label qui nous intéresse est le suivant : 

    cloud.google.com/gke-nodepool=app-8-cpu-v27-9-200go

Identifions les noeuds des clusters à 'drainer' :

    kubectl get nodes -l cloud.google.com/gke-nodepool=app-8-cpu-v27-9-200go
    
        NAME                                         STATUS                     ROLES    AGE   VERSION
        gke-hp-app-8-cpu-v27-200go-352e9832-090l   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-200go-352e9832-70p2   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-200go-858d2ea9-0bkq   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-200go-858d2ea9-t0r2   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-200go-d1ae30d5-nkbx   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000
        gke-hp-app-8-cpu-v27-200go-d1ae30d5-pwt8   Ready,SchedulingDisabled   <none>   11d   v1.27.9-gke.1092000

Lançons le drainage :

    PRINT_COMMAND=true
    
    for NODE in $( kubectl get nodes -l cloud.google.com/gke-nodepool=app-8-cpu-v27-9-200go --no-headers | awk '{print $1}' ); do
      if ${PRINT_COMMAND}; then
        echo kubectl drain ${NODE}} --ignore-daemonsets --delete-emptydir-data
      else
        kubectl drain ${NODE}} --ignore-daemonsets --delete-emptydir-data
    done

        kubectl drain gke-hp-app-8-cpu-v27-9-200go-352e9832-090l --ignore-daemonsets --delete-emptydir-data
        kubectl drain gke-hp-app-8-cpu-v27-9-200go-352e9832-70p2 --ignore-daemonsets --delete-emptydir-data
        kubectl drain gke-hp-app-8-cpu-v27-9-200go-858d2ea9-0bkq --ignore-daemonsets --delete-emptydir-data
        kubectl drain gke-hp-app-8-cpu-v27-9-200go-858d2ea9-t0r2 --ignore-daemonsets --delete-emptydir-data
        kubectl drain gke-hp-app-8-cpu-v27-9-200go-d1ae30d5-nkbx --ignore-daemonsets --delete-emptydir-data
        kubectl drain gke-hp-app-8-cpu-v27-9-200go-d1ae30d5-pwt8 --ignore-daemonsets --delete-emptydir-data


**Note** - le **_'drain'_** ne gère que les pods qui ont été générés par un autre objet : deployment, replicaset, daemonset. Si un pod qui a été généré directement avec la commande _'kubectl create pod'_, **le drain tombera en erreur**.

Voici un exemple :

    kubectl drain gke-hp-app-4-cpu-v27-9-200go-479d4396-xdwz --ignore-daemonsets --delete-emptydir-data

        node/gke-hp-app-4-cpu-v27-9-200go-479d4396-xdwz already cordoned
        error: unable to drain node "gke-hp-app-4-cpu-v27-9-200go-479d4396-xdwz" due to error:cannot delete Pods declare no controller (use --force to override): ns-autodiag/pgclient, ns-masterfi-preprod/pgclient, continuing command...
        There are pending nodes to be drained:
         gke-hp-app-4-cpu-v27-9-200go-479d4396-xdwz
        cannot delete Pods declare no controller (use --force to override): ns-autodiag/pgclient, ns-masterfi-preprod/pgclient

-> il faut forcer l’opération 

    kubectl drain gke-hp-app-4-cpu-v27-9-200go-479d4396-xdwz --ignore-daemonsets --delete-emptydir-data —force

Vérification :

    kubectl get pod -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName --all-namespaces | grep v27-9

-> on ne voir plus que des daemonsets.


## Suppression des anciens node pools

### Vérification des node pools 

    gcloud container node-pools list --region europe-west4 --cluster hp

        NAME                   MACHINE_TYPE   DISK_SIZE_GB  NODE_VERSION
        app-4-cpu-v27-9-200go  n2-standard-4  200           1.27.9-gke.1092000
        app-8-cpu-v27-9-200go  n2-standard-8  200           1.27.9-gke.1092000
        app-4-cpu-v28-200go    n2-standard-4  200           1.28.6-gke.1289000
        app-8-cpu-v28-200go    n2-standard-8  200           1.28.6-gke.1289000

### Suppression des anciens node pools

    gcloud container node-pools delete app-4-cpu-v27-9-200go --region europe-west4 --cluster hp
    gcloud container node-pools delete app-8-cpu-v27-9-200go --region europe-west4 --cluster hp


Fin