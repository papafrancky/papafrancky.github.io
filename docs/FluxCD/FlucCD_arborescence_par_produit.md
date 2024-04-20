
# FluxCD - Proposition de nouvelle organisation des manifests

Nous voulons tester une manière d'organiser notre repo Flux en suivant une approche par produit/application.

Nous décrirons comment installer from scratch un cluster kubernetes (kind) de développement qui hébergera dans un premier temps une application 'podinfo' récupérée depuis un repo Git dédié.

## Pre-requis
- un cluster Kubernetes pret ( kind create cluster --name=development )
- un repo GitHub nommé _'kubernetes-development'_ dans lequel FluxCD sera bootsrapé;
- un channel Discord avec un channel nommé _'podinfo-development'_ (dédié aux notifications de l'appli podinfo pour l'environnement de développement) et un webhook déjà configuré.


## Bootstrap de FluxCD

```bash
export GITHUB_USER=papaFrancky
export GITHUB_TOKEN=<my_github_personal_access_token>

flux bootstrap github \
  --token-auth \
  --owner papaFrancky \
  --repository kubernetes-development \
  --branch=main \
  --path=. \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller
```

-> Vérification avec un navigateur :

```
https://github.com/papaFrancky/kubernetes-development/tree/main
```

-> Vérification avec kubectl :

```bash
kubectl -n flux-system get all
```

## Organisation des manifests dans le repository Git dédié à FluxCD

Nous allons organiser les manifests en les regroupant par produit.

Au même niveau que le répertoire _'kubernetes-development'_ (ie. le nom donné à notre cluster Kubernetes de développement), nous allons créer un répertoire _'products'_ qui contiendra les repos Git clonés des produits gérés par FluxCD.
Dans le repo Git de FluxCD, nommé kubernetes-development car il correspond au cluster de développement dans notre exemple, nous décrirons comment Flux gèrera nos produits sur le cluster dans le répertoire products et et dans autant de sous-répertoires qu'il y aura de produits à gérer.

L'arborescence ressemblera à quelque-chose comme ceci :

```
${WORKING_DIRECTORY}
├── kubernetes-development
│   ├── README.md
│   ├── flux-system
│   │   ├── gotk-components.yaml
│   │   ├── gotk-sync.yaml
│   │   └── kustomization.yaml
│   └── products
│       ├── nginxhello
│       │   ├── ...
│       │   ├── ...
│       │   └── ...
│       └── podinfo
│           ├── git-repository.yaml
│           ├── image-policy.yaml
│           ├── image-repository.yaml
│           ├── image-update-automation.yaml
│           ├── namespace.yaml
│           ├── notification-alert.yaml
│           ├── notification-provider.yaml
│           └── sync.yaml
├── products
│   ├── nginxhello
│   │   ├── ...
│   │   └── ...
│   └── podinfo
│       ├── ...
│       ├── ...
│       ├── ...
```

## Mise en place de la gestion d'une application par FluxCD

Nous prendrons comme exemple l'application podinfo de Stefan Prodan.
La première chose à faire est de cloner en local notre repo Git dédié à FluxCD pour notre cluster de développement :

```bash
cd ${WORKING_DIRECTORY}
git clone git@github.com:${GITHUB_USERNAME}/kubernetes-development.git
```
 
Nous allons rassembler tous les manifests de paramétrage dans un répertoire dédié à l'application :

```bash
cd kubernetes-development
mkdir -p products/podinfo
cd products/podinfo
```

### Namespace dédié à l'application

Podinfo disposera de son propre namespace.

```bash
kubectl create namespace podinfo --dry-run=client -o yaml > namespace.yaml

cat namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: podinfo

git add .
git commit -m 'created namespace podinfo.'
git push


kubectl get namespace podinfo

  # NAME      STATUS   AGE
  # podinfo   Active   21s
```

### Configuration des notifications (provider: Discord) 

Nous souhaitons être informés via un service de messagerie des modifications apportées à l'application. Notre choix se porte sur Discord.


#### Création du channel Discord dédié à l'application podinfo

Créer un channel nommé podinfo-development dans son 'serveur' Discord et recopier le webhook créé par défaut.


#### Enregistrement du webhook du channel Discord dans un Secret Kubernetes

```bash
DISCORD_WEBHOOK=https://discord.com/api/webhooks/1204170006032818296/D6-rBzJHb1EAfPOtuVbzIqs2goJTuoCn-1AUCef-HZN2xZvK9Mkjolg29dc3z1vqIPuf

kubectl -n podinfo create secret generic discord-podinfo-development-webhook --from-literal=address=${DISCORD_WEBHOOK} 

kubectl -n podinfo get secret discord-podinfo-development-webhook
    
  # NAME                                  TYPE     DATA   AGE
  # discord-podinfo-development-webhook   Opaque   1      134m 
```

#### Création du 'notification provider'

!!! info
    https://fluxcd.io/flux/components/notification/providers/#discord

```bash
flux create alert-provider discord \
  --type=discord \
  --secret-ref=discord-webhook \
  --channel=kubernetes-development \
  --username=FluxCD \
  --namespace=podinfo \
  --export > notification-provider.yaml


cat notification-provider.yaml

  ---
  apiVersion: notification.toolkit.fluxcd.io/v1beta3
  kind: Provider
  metadata:
    name: discord
    namespace: podinfo
  spec:
    channel: kubernetes-development
    secretRef:
      name: discord-podinfo-development-webhook
    type: discord
    username: FluxCD
```

#### Configuration des alertes Discord

```bash
flux create alert discord \
  --event-severity=info \
  --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*' \
  --provider-ref=discord \
  --namespace=podinfo \
  --export > notification-alert.yaml


cat notifications/alerts/discord.yaml

  ---
  apiVersion: notification.toolkit.fluxcd.io/v1beta3
  kind: Alert
  metadata:
    name: discord
    namespace: podinfo
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
    providerRef:
      name: discord
```

#### Enregistrement des modifications

```bash
cd ${WORKING_DIRECTORY}/kubernetes-development
git st
git add .
git commit -m 'configuring discord alerting.'
git push


kubectl get providers,alerts -n podinfo
    
  NAME                                              AGE
  provider.notification.toolkit.fluxcd.io/discord   54s

  NAME                                              AGE
  alert.notification.toolkit.fluxcd.io/discord      54s
```


## Création du repository Git dédié à l'application '_podinfo_'

Pour simuler le développement d'une application, nous allons créer un repository Git sur notre compte à partir d'une application existante : 'podinfo' de Stefan Prodan.

Dans GitHub, on créé un nouveau repository nommé _'podinfo-development'_ ( https://github.com/${GITHUB_USERNAME}/podinfo-development.git ).

Ensuite on utilise le bouton **'import'** pour récupérer le projet https://github.com/stefanprodan/podinfo
-> Nous avons désormais une copie de l'application 'podinfo' dans notre propre repo GitHub 'podingo-development'.

### Récupérons le repository localement dans le répertoire dédié aux produits et renommons-le

Le repository s'appelle podinfo-development car nous partons du principe que le produit disposera d'un repo par environnement.

```bash
cd ${WORKING_DIRECTORY}
mkdir products && cd products
git clone git@github.com:${GITHUB_USERNAME}/podinfo-development.git
mv podinfo-development podinfo
```

-> Nous avons désormais un répertoire _'products/podinfo'_. Dans le répertoire _'kustomize'_ se trouvent les manifests qui nous intéressent pour déployer le produit.

### Modification des manifests pour déployer l'application dans le namespace éponyme

Notez que nous voulons que le produit soit déployé dans le namespace 'podinfo'.

Il est donc nécessaire d'ajouter dans les manifests deployment.yaml, hpa.yaml et service.yaml le paramètre suivant : 

```
.data.namespace=podinfo
```

Une fois les manifests modifiés, il faut les commiter et les pousser sur la branche main du repository.

!!! ce serait intéressant de passer par Flux pour gérer ce paramètre sans modifier les manifests dans leur repo Github !!!

Nous allons également profiter de ce moment pour 'downgrader' la version de l'image du conteneur : dans le manifest _'deployment.yaml'_, nous allons modifier  _''.spec.template.spec.containers[].image''_ comme suit :

```
    cr.io/stefanprodan/podinfo:6.5.4 -> ghcr.io/stefanprodan/podinfo:6.5.0
```

Cela nous servira plus tard avec l'ImageAutomation.



### Génération des deploy keys pour le repo GitHub de l'application

Nous devons désormais créer une paire de clés SSH pour permettre à FluxCD de se connecter avec les droits d'écriture au repo applicatif.

```bash
flux create secret git podinfo-gitrepository \
  --url=ssh://github.com/${GITHUB_USERNAME}/podinfo-development \
  --namespace=podinfo
```

 La clé publique (deploy key) doit être ajoutée dans les settings du repo GitHub :  https://github.com/${GITHUB_USERNAME}/podinfo-development/settings/keys/new

!!! warning
    Cocher la case 'Allow write access' !!!

Cliquer sur le bouton "Add Key" et renseigner son mot de passe pour confirmer


### Création du GitRepository 'podinfo-development'

```bash
cd ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo/
    
flux create source git podinfo-development \
  --url=ssh://git@github.com/${GITHUB_USERNAME}/podinfo-development.git \
  --branch=main \
  --secret-ref=podinfo-gitrepository \
  --namespace=podinfo \
  --export > gitrepository.yaml


cat gitrepository.yaml

  ---
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: GitRepository
  metadata:
    name: podinfo-development
    namespace: podinfo
  spec:
    interval: 1m0s
    ref:
      branch: main
    secretRef:
      name: podinfo-gitrepository
    url: ssh://git@github.com/papaFrancky/podinfo-development.git
```

### Définition de la Kustomization liée au GitRepo

!!! tip
    Nommer le manifest _'kustomize.yml'_ pose des problèmes, le nom doit être réservé pour les besoins internes de Flux. Nous le nommerons _'sync.yaml'_.

```bash
flux create kustomization podinfo \
    --source=GitRepository/podinfo-development.podinfo \
    --path="./kustomize" \
    --prune=true \
    --namespace=podinfo \
    --export > sync.yaml
    

cat kustomize.yaml

  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: podinfo
    namespace: podinfo
  spec:
    interval: 1m0s
    path: ./kustomize
    prune: true
    sourceRef:
      kind: GitRepository
      name: podinfo-development
      namespace: podinfo
    
git add .
git commit -m "feat: added podinfo GitRepo + Kustomization."
git push
    
flux reconcile kustomization flux-system --with-source
    

kubectl get GitRepositories -n podinfo

  NAME                  URL                                                        AGE    READY   STATUS
  podinfo-development   ssh://git@github.com/papaFrancky/podinfo-development.git   105m   True    stored artifact for     revision     'main@sha1:dc830d02a6e0bcbf63bcc387e8bde57d5627aec2'
    

kubectl get kustomizations -n podinfo

  NAME                  AGE    READY   STATUS
  podinfo-development   106m   True    Applied revision: main@sha1:dc830d02a6e0bcbf63bcc387e8bde57d5627aec2
    
    
kubectl get all -n podinfo

  NAME                           READY   STATUS    RESTARTS   AGE
  pod/podinfo-664f9748d8-2d4nf   1/1     Running   0          2m16s
  pod/podinfo-664f9748d8-n5gwn   1/1     Running   0          2m1s
        
  NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)             AGE
  service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP             3h50m
  service/podinfo      ClusterIP   10.96.175.42   <none>        9898/TCP,9999/TCP   2m16s
        
  NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
  deployment.apps/podinfo   2/2     2            2           2m16s
        
  NAME                                 DESIRED   CURRENT   READY   AGE
  replicaset.apps/podinfo-664f9748d8   2         2         2       2m16s
        
  NAME                                          REFERENCE            TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
  horizontalpodautoscaler.autoscaling/podinfo   Deployment/podinfo   <unknown>/99%   2         4         2          2m16s
```


### Mise à jour automatique de l'image

Nous allons maintenant mettre en place la mise à jour automatique de l'image du conteneur utilisée pour l'application podinfo.
Pour ce faire, nous allons définir un ImageRepository et une ImagePolicy :

```bash
cd ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo
    
flux create image repository podinfo \
  --image=ghcr.io/stefanprodan/podinfo \
  --interval=5m \
  --namespace=podinfo \
  --export > imagerepository.yaml
    

cat imagerepository.yaml

  ---
  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImageRepository
  metadata:
    name: podinfo
    namespace: podinfo
  spec:
    image: ghcr.io/stefanprodan/podinfo
    interval: 5m0s
          
git add .
git commit -m "feat: defined the podinfo image repository."
git push
    

kubectl describe imagerepository podinfo
    
  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImageRepository
  metadata:
    creationTimestamp: "2024-02-04T20:45:06Z"
    finalizers:
    - finalizers.fluxcd.io
    generation: 1
    labels:
      kustomize.toolkit.fluxcd.io/name: flux-system
      kustomize.toolkit.fluxcd.io/namespace: flux-system
    name: podinfo
    namespace: podinfo
    resourceVersion: "34713"
    uid: d1124c6d-58f5-4ba4-9202-0bdc67b6a37f
  spec:
    exclusionList:
    - ^.*\.sig$
    image: ghcr.io/stefanprodan/podinfo
    interval: 5m0s
    provider: generic
  status:
    canonicalImageName: ghcr.io/stefanprodan/podinfo
    conditions:
    - lastTransitionTime: "2024-02-04T20:45:07Z"
      message: 'successful scan: found 51 tags'
      observedGeneration: 1
      reason: Succeeded
      status: "True"
      type: Ready
    lastScanResult:
      latestTags:
      - latest
      - 6.5.4
      - 6.5.3
      - 6.5.2
      - 6.5.1
      - 6.5.0
      - 6.4.1
      - 6.4.0
      - 6.3.6
      - 6.3.5
      scanTime: "2024-02-04T20:45:07Z"
      tagCount: 51
    observedExclusionList:
    - ^.*\.sig$
    observedGeneration: 1


flux create image policy podinfo \
  --image-ref=podinfo \
  --select-semver='>=5.4.x' \
  --namespace=podinfo \
  --export > imagepolicy.yaml
    

cat imagepolicy.yaml
    
  ---
  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImagePolicy
  metadata:
    name: nginxhello
    namespace: podinfo
  spec:
    imageRepositoryRef:
      name: podinfo
    policy:
      semver:
        range: '>=5.4.x'


git add .
git commit -m "feat: defined the podinfo image policy."
git push


kubectl get imagepolicy podinfo -n podinfo
    
  NAME      LATESTIMAGE
  podinfo   ghcr.io/stefanprodan/podinfo:6.5.4
```


### Ajout d'un marqueur dans le manifest de déploiement

Nous pouvons enfin ajouter un marqueur à notre deployment pour permettre la mise à jour de l'application podinfo via image automation.

```sh    
cd ${WORKING_DIRECTORY}/products/podinfo-development/kustomize
vi deployment.yaml
```

Nous allons ajouter un marquer sur le paramètre .spec.template.spec.containers[].image comme suit :

```
    ghcr.io/stefanprodan/podinfo:6.5.0 -> ghcr.io/stefanprodan/podinfo:6.5.0 # {"$imagepolicy": "podinfo:podinfo"}
```

!!! note
    *"podinfo.podinfo"* correspond à *"<namespace\>.<imagepolicy\>"*

!!! info
    https://fluxcd.io/flux/guides/image-update/#configure-image-update-for-custom-resources


### Définition d'une Image Update Automation

Il nous reste à dfinir une ImageUpdateAutomation

!!! info
    https://fluxcd.io/flux/cmd/flux_create_image_update/#examples

```sh
    cd ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo

    flux create image update podinfo \
        --namespace=podinfo \
        --git-repo-ref=podinfo-development \
        --git-repo-path="./kustomize" \
        --checkout-branch=main \
        --author-name=FluxCD \
        --author-email=flux@example.com \
        --commit-template="{{range .Updated.Images}}{{println .}}{{end}}" \
        --export > image-update-automation.yaml
    

    cat image-update-automation.yaml
    
        ---
        apiVersion: image.toolkit.fluxcd.io/v1beta1
        kind: ImageUpdateAutomation
        metadata:
          name: podinfo
          namespace: podinfo
        spec:
          git:
            checkout:
              ref:
                branch: main
            commit:
              author:
                email: flux@example.com
                name: FluxCD
              messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}'
          interval: 1m0s
          sourceRef:
            kind: GitRepository
            name: podinfo-development
          update:
            path: ./kustomize
            strategy: Setters
          update:
            path: ./kustomize
            strategy: Setters
    
    
    cd ${WORKING_DIRECTORY}/products/podinfo-development/kustomize
    git fetch     # si le manifest a été modifié, nous aurons 1 commit de retard sur notre copie locale.
    git pull
    grep "image:" deployment.yaml
        image: ghcr.io/stefanprodan/podinfo:6.5.4 # {"$imagepolicy": "podinfo:podinfo"}
        -> la version a bien changé


    git log

      commit 9a10ef5790264c1b415323bc3713c1ee7d5591cb (HEAD -> main, origin/main, origin/HEAD)
      Author: FluxCD <flux@example.com>
      Date:   Sun Feb 4 21:35:24 2024 +0000
      
          ghcr.io/stefanprodan/podinfo:6.5.4


    kubectl get gitrepository podinfo-development

        NAME                  URL                                                        AGE     READY   STATUS
        podinfo-development   ssh://git@github.com/papaFrancky/podinfo-development.git   4h17m   True    stored artifact for     revision     'main@sha1:9a10ef5790264c1b415323bc3713c1ee7d5591cb'
```       

-> nous retrouvons le même SHA1.


-----

## Ajout d'un nouveau produit : nginxhello

### Création du repository Git dédié à l'application '_nginxhello_'

Nous créons un nouveau repository Git sur notre compte GitHub qui hébergera l'application _'nginxhello'_ de Nigel Brown.

-> https://github.com/papafrancky/nginxhello-development

Nous clonons le repository en local : 

```sh
cd ${WORKING_DIRECTORY}/products/
git clone git@github.com:papafrancky/nginxhello-development.git
```

Nous allons y déposer les manifests suivants récupérés depuis le repo git de Nigel Brown :
https://github.com/nbrownuk/gitops-nginxhello/

- deployment.yaml
- service.yaml

!!! tip
    Modifier les 2 manifests et ajouter : .metadata.namespace:nginxhello !!!

Une fois les manifests recopiés, on pousse les ajouts dans GitHub :

```sh
cd ${WORKING_DIRECTORY}/products/nginxhello-development
git add deployment
git commit -m "added nginxhello application."
git push
```


### Création du namespace dédié à l'application

```sh
kubectl create ns nginxhello
```


### Créations de la paire de clés SSH

FluxCD les utilisera pour interagir avec le repo GitHub nouvellement créé.


```sh
flux create secret git nginxhello-gitrepository \
  --url=ssh://github.com/papafrancky/nginxhello-development \
  --namespace=nginxhello

  ✚ deploy key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBFbZqQ6mc2ZAljuZoxlRNJmv1/lUWbmL2sdPGGNf10ynh/BtH4DSZHGFz3RWIHOpGXmGJjX1ZN2pLvi/uGzvSVTAJFBMWrbqljnGWCpbB9fL8UlfokYrdRdIr/7aZnR9ZQ==

  ► git secret 'nginxhello-gitrepository' created in 'podinfo' namespace


kubectl -n nginxhello get secret nginxhello-gitrepository

  NAME                       TYPE     DATA   AGE
  nginxhello-gitrepository   Opaque   3      116s
```

 La clé publique (deploy key) doit être ajoutée dans les settings du repo GitHub :
 ```  
 https://github.com/papafrancky/nginxhello-development/settings/keys/new
````

!!! warning
    Cocher la case **'Allow write access'** !!!

Cliquer sur le bouton __'Add Key'__ et renseigner son mot de passe pour confirmer


### Configuration des notifications (provider: Discord) 

#### Création du channel Discord dédié à l'application podinfo

Créer un channel nommé **_'nginxhello-development'_** dans son 'serveur' Discord et recopier le webhook créé par défaut.


#### Enregistrement du webhook du channel Discord dans un Secret Kubernetes

```sh
DISCORD_WEBHOOK=https://discord.com/api/webhooks/1204543090371592212/mCphzp07-orqFvRKGdtxjbq0T9OHC8whuUgSpzuhn2PGol8Kr2MHm4OKAorFSQCom7Ou

kubectl -n nginxhello create secret generic discord-nginxhello-development-webhook --from-literal=address=${DISCORD_WEBHOOK} 


kubectl -n nginxhello get secret discord-nginxhello-development-webhook
    
  NAME                                     TYPE     DATA   AGE
  discord-nginxhello-development-webhook   Opaque   1      11s
```

#### Création du 'notification provider'

!!! info
    https://fluxcd.io/flux/components/notification/providers/#discord

```sh
flux create alert-provider discord \
  --type=discord \
  --secret-ref=discord-nginxhello-development-webhook \
  --channel=nginxello-development \
  --username=FluxCD \
  --namespace=nginxhello \
  --export > notification-provider.yaml


cat notification-provider.yaml

  ---
  apiVersion: notification.toolkit.fluxcd.io/v1beta3
  kind: Provider
  metadata:
    name: discord
    namespace: nginxhello
  spec:
    channel: nginxello-development
    secretRef:
      name: discord-nginxhello-development-webhook
    type: discord
    username: FluxCD
```


#### Configuration des alertes Discord

```sh
flux create alert discord \
  --event-severity=info \
  --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*' \
  --provider-ref=discord \
  --namespace=nginxhello \
  --export > notification-alert.yaml


cat notifications/alerts/discord.yaml

  ---
  apiVersion: notification.toolkit.fluxcd.io/v1beta3
  kind: Alert
  metadata:
    name: discord
    namespace: nginxhello
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
    providerRef:
      name: discord
```


#### Enregistrement des modifications

```sh
cd ${WORKING_DIRECTORY}/kubernetes-development
git st
git add .
git commit -m 'configuring discord alerting.'
git push


kubectl get providers,alerts -n nginxhello
    
  NAME                                              AGE
  provider.notification.toolkit.fluxcd.io/discord   9s

  NAME                                           AGE
  alert.notification.toolkit.fluxcd.io/discord   9s
```


### Définition du GitRepository

```sh
cd ${WORKING_DIRECTORY}/kubernetes-development/products/nginxhello
vi git-repository.yaml

  ---
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: GitRepository
  metadata:
    name: nginxhello-development
    namespace: nginxhello
  spec:
    interval: 1m0s
    ref:
      branch: main
    secretRef:
      name: nginxhello-gitrepository
    url: ssh://git@github.com/papafrancky/nginxhello-development.git

git add .
git commit -m "defined nginxhello namespace and git repository."
git push
```

### Définition de la Kustomization liée au GitRepo

```sh
cd ${WORKING_DIRECTORY}/kubernetes-development/products/nginxhello

flux create kustomization nginxhello \
  --source=GitRepository/nginxhello-development.nginxhello \
  --path="." \
  --prune=true \
  --namespace=nginxhello \
  --export > sync2.yaml


cat sync.yaml

  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: nginxhello
    namespace: nginxhello
  spec:
    interval: 1m0s
    path: ./
    prune: true
    sourceRef:
      kind: GitRepository
      name: nginxhello-development
      namespace: nginxhello


git add .
git commit -m "feat: added nginxhello GitRepo + Kustomization."
git push
    
flux reconcile kustomization flux-system --with-source
    

kubectl get GitRepositories -n nginxhello

  NAME                  URL                                                        AGE    READY   STATUS
  podinfo-development   ssh://git@github.com/papaFrancky/podinfo-development.git   105m   True    stored artifact for     revision     'main@sha1:dc830d02a6e0bcbf63bcc387e8bde57d5627aec2'
    

kubectl get kustomizations -n nginxhello

        NAME         AGE   READY   STATUS
        nginxhello   20m   True    Applied revision: main@sha1:4915acffa3c3d0ef38b2985e35db8ec1d4294cc9
   
        
kubectl get all -n nginxhello

  NAME                              READY   STATUS    RESTARTS   AGE
  pod/nginxhello-75dfc9cd44-6sxx7   1/1     Running   0          2m44s
  pod/nginxhello-75dfc9cd44-f78d6   1/1     Running   0          2m44s
  pod/nginxhello-75dfc9cd44-hwfwf   1/1     Running   0          2m44s
  pod/nginxhello-75dfc9cd44-p74mr   1/1     Running   0          2m44s
  pod/nginxhello-75dfc9cd44-r88mb   1/1     Running   0          2m44s

  NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
  service/nginxhello   ClusterIP   10.96.173.138   <none>        80/TCP    2m44s

  NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
  deployment.apps/nginxhello   5/5     5            5           2m44s

  NAME                                    DESIRED   CURRENT   READY   AGE
  replicaset.apps/nginxhello-75dfc9cd44   5         5         5       2m44s
```



-----

### Mise à jour automatique de l'image


#### Définition de l'Image Repository

```sh
cd ${WORKING_DIRECTORY}/kubernetes-development/products/nginxhello
    
flux create image repository nginxhello \
  --image=nbrown/nginxhello \
  --interval=5m \
  --namespace=nginxhello \
  --export > image-repository.yaml
    

cat image-repository.yaml

  ---
  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImageRepository
  metadata:
    name: nginxhello
    namespace: nginxhello
  spec:
    image: nbrown/nginxhello
    interval: 5m0s

          
git add .
git commit -m "feat: defined the podinfo image repository."
git push
    

kubectl -n nginxhello get imagerepository nginxhello
    
  NAME         LAST SCAN              TAGS
  nginxhello   2024-02-07T19:41:44Z   45


kubectl -n nginxhello get imagerepository nginxhello -o yaml

  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImageRepository
  metadata:
    creationTimestamp: "2024-02-06T23:06:10Z"
    finalizers:
    - finalizers.fluxcd.io
    generation: 2
    labels:
      kustomize.toolkit.fluxcd.io/name: flux-system
      kustomize.toolkit.fluxcd.io/namespace: flux-system
    name: nginxhello
    namespace: nginxhello
    resourceVersion: "193248"
    uid: ffb33fdf-4425-4e09-bda1-9b941fa6ce48
  spec:
    exclusionList:
    - ^.*\.sig$
    image: nbrown/nginxhello
    interval: 5m0s
    provider: generic
  status:
    canonicalImageName: index.docker.io/nbrown/nginxhello
    conditions:
    - lastTransitionTime: "2024-02-07T19:41:44Z"
      message: 'successful scan: found 45 tags'
      observedGeneration: 2
      reason: Succeeded
      status: "True"
      type: Ready
    lastScanResult:
      latestTags:
      - stable
      - mainline
      - latest
      - e6c463e6
      - aad042cb
      - 1.25.2
      - "1.25"
      - 1.24.0
      - "1.24"
      - 1.23.3
      scanTime: "2024-02-07T19:41:44Z"
      tagCount: 45
    observedExclusionList:
    - ^.*\.sig$
    observedGeneration: 2
```

#### Définition de l'Image Policy

```sh
flux create image policy nginxhello \
  --image-ref=nginxhello \
  --select-semver='>=1.19.0 <1.24.0' \
  --namespace=nginxhello \
  --export > image-policy.yaml
    

cat image-policy.yaml
      
  ---
  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImagePolicy
  metadata:
    name: nginxhello
    namespace: nginxhello
  spec:
    imageRepositoryRef:
      name: nginxhello
    policy:
      semver:
        range: '>=1.19.0 <1.24.0'
    

git add .
git commit -m "feat: defined the nginxhello image policy."
git push
    

kubectl -n nginxhello get imagepolicy nginxhello
    
  NAME         LATESTIMAGE
  nginxhello   nbrown/nginxhello:1.23.3
```

### Ajout d'un marqueur dans le manifest de déploiement

!!! info 
    https://fluxcd.io/flux/guides/image-update/#configure-image-update-for-custom-resources


Nous pouvons enfin ajouter un marqueur à notre deployment pour permettre la mise à jour de l'application podinfo via image automation.

```sh
cd ${WORKING_DIRECTORY}/products/nginxhello-development
vi deployment.yaml
```

Nous allons ajouter un marquer sur le paramètre .spec.template.spec.containers[].image comme suit :

```sh
nbrown/nginxhello:1.19.0 -> nbrown/nginxhello:1.19.0 # {"$imagepolicy": "nginxhello:nginxhello"}
```

!!! info
    __*"nginxhello:nginxhello"*__ correspond à __*"<namespace\>:<imagepolicy\>*__"

!!! note
    https://fluxcd.io/flux/guides/image-update/#configure-image-update-for-custom-resources


### Définition d'une Image Update Automation

Il nous reste à définir une ImageUpdateAutomation

!!! info
    https://fluxcd.io/flux/cmd/flux_create_image_update/#examples

```sh
cd ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo

flux create image update nginxhello \
  --namespace=nginxhello \
  --git-repo-ref=nginxhello-development \
  --git-repo-path="./" \
  --checkout-branch=main \
  --author-name=FluxCD \
  --author-email=flux@example.com \
  --commit-template="{{range .Updated.Images}}{{println .}}{{end}}" \
  --export > image-update-automation.yaml
    

cat image-update-automation.yaml
    
  ---
  apiVersion: image.toolkit.fluxcd.io/v1beta1
    kind: ImageUpdateAutomation
    metadata:
    name: nginxhello
    namespace: nginxhello
  spec:
    git:
      checkout:
        ref:
          branch: main
      commit:
        author:
          email: flux@example.com
          name: FluxCD
        messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}'
    interval: 1m0s
    sourceRef:
      kind: GitRepository
      name: nginxhello-development
    update:
      path: ./
      strategy: Setters

git add image-update-automation.yaml
git commit -m 'defined the nginxhello image update automation.' 
git push

    
cd ${WORKING_DIRECTORY}/products/nginxhello-development
git fetch     # si le manifest a été modifié, nous aurons 1 commit de retard sur notre copie locale.
git pull
grep "image:" deployment.yaml
  - image: nbrown/nginxhello:1.23.3 # {"$imagepolicy": "nginxhello:nginxhello"}
# -> la version a bien changé, image update automation a réécrit le manifest.


kubectl -n nginxhello events
# -> retrace l'ensemble des opérations déclenchées depuis l'ImageUpdateAutomation (la liste est longue).
```

### Test complémentaire ^^

Nous allons modifier l'ImagePolicy pour utiliser l'image Docker la plus récente de nginxhello.


#### Identification de l'image la plus récente

```sh
kubectl -n nginxhello get imagerepository nginxhello -o yaml | yq '.status.lastScanResult.latestTags'

  - stable
  - mainline
  - latest
  - e6c463e6
  - aad042cb
  - 1.25.2
  - "1.25"
  - 1.24.0
  - "1.24"
  - 1.23.3
```

-> la version la plus récente semble être la 1.25.2


#### Modification de l'Image Policy 

```sh
cd ${WORKING_DIRECTORY}/kubernetes-development/products/nginxhello
gsed -i "s/range: .*$/range: \'>=1.23.0\'/" image-policy.yaml

cat image-policy.yaml

  ---
  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImagePolicy
  metadata:
    name: nginxhello
    namespace: nginxhello
  spec:
    imageRepositoryRef:
      name: nginxhello
    policy:
      semver:
        range: '>=1.23.0'


git add .
git commit -m 'modified the nginxhello image policy to get its latest image version.'
git push 
```


## Cleaning

Nous allons nous concentrer sur la gestion des Helm Charts.
Avant cela, pour économiser des ressources, nous allons désactiver la gestion des ressources précédentes.
Je ne sais pas s'il existe une méthode plus académique, ausi nous allons simplement renommer les manifests de kustomization.

```sh
cd ${WORKING_DIRECTORY}products
mv nginxhello/sync.yaml nginxhello/sync.yaml.BKP
mv podinfo/sync.yaml podinfo/sync.yaml.BKP

git add .
git commit -m 'disabling flux management for nginxhello and podinfo products.'
git push
```

-> les pods, deployments, services sont supprimés dnas les namespaces nginxhello et podinfo !


## Gestion des applications packagées avec Helm


### Arborescence d'accueil pour la nouvelle application

Nous allons déployer la même application _'podinfo'_ mais cette fois-ci, via un Helm Chart.
Pour éviter toute confusion avec notre premier déploiement, nous hébergerons cette nouvelle application dans une répertoire et un namespace nommés podinfo2

```sh
mkdir ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2
mkdir ${WORKING_DIRECTORY}/products/podinfo2
```

### Namespace dédié

```sh
kubectl create namespace podinfo2 --dry-run=client -o yaml | grep -vE 'creationTimestamp|spec|status' > ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2/namespace.yaml
kubectl apply -f ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2/namespace.yaml
```

### Notifications Discord

#### Création du channel Discord dédié à l'application podinfo
Créer un channel nommé **_'podinfo2-development'_** dans son 'serveur' Discord et recopier le webhook créé par défaut.


#### Enregistrement du webhook du channel Discord dans un Secret Kubernetes

```sh
DISCORD_WEBHOOK=https://discord.com/api/webhooks/1205276611159789689/6UTavz1aoiaEtxTpDmN-hBYP9vRVpXaD-XJK4K0cI0hscdVd3XFrNR32o9vJ_VStB1Hl
kubectl -n podinfo2 create secret generic discord-podinfo2-development-webhook --from-literal=address=${DISCORD_WEBHOOK}
```

#### Création du 'notification provider'

!!! info
    https://fluxcd.io/flux/components/notification/providers/#discord

```sh
cd ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2/
flux create alert-provider discord \
  --type=discord \
  --secret-ref=discord-podinfo2-development-webhook \
  --channel=podinfo2-development \
  --username=FluxCD \
  --namespace=podinfo2 \
  --export > notification-provider.yaml
```


#### Configuration des alertes Discord

```sh
flux create alert discord \
  --event-severity=info \
  --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*' \
  --provider-ref=discord \
  --namespace=podinfo2 \
  --export > notification-alert.yaml
```

#### Enregistrement des modifications

```sh
cd ${WORKING_DIRECTORY}/kubernetes-development
git add .
git commit -m 'configuring discord alerting.'
git push
    
kubectl get providers,alerts -n podinfo2
```


#### The _'podinfo'_ Helm Chart

We will use the _'podinfo'_ Helm chart as an example.

```sh
helm show chart oci://ghcr.io/stefanprodan/charts/podinfo
    
  Pulled: ghcr.io/stefanprodan/charts/podinfo:6.5.4
  Digest: sha256:a961643aa644f24d66ad05af2cdc8dcf2e349947921c3791fc3b7883f6b1777f
  apiVersion: v1
  appVersion: 6.5.4
  description: Podinfo Helm chart for Kubernetes
  home: https://github.com/stefanprodan/podinfo
  kubeVersion: '>=1.23.0-0'
  maintainers:
    - email: stefanprodan@users.noreply.github.com
  name: stefanprodan
  name: podinfo
  sources:
    - https://github.com/stefanprodan/podinfo
  version: 6.5.4
```

#### Creating the _'podinfo2'_ helmRepository

##### Authenticating to the Helm repository

Let's create a new _'Docker registry'_ type secret allowinf us to retrieve the Helm chart.
(ghcr.io belongs to GitHub; they both use the same identity management)

!!! note
    This repository is a public one; in our case there will be no need to specify credentials in the helmRepository.

```sh
export GITHUB_USER=papafrancky
export GITHUB_TOKEN=${GITHUB_PAT}

kubectl create secret docker-registry ghcr-charts-auth \
  --docker-server=ghcr.io \
  --docker-username=${GITHUB_USER} \
  --docker-password=-{GITHUB_TOKEN}
```

##### Creating the helmRepository manifest

```sh
flux create source helm podinfo2 \
  --url=https://stefanprodan.github.io/podinfo \
  --namespace=podinfo2 \
  --interval=1m \
  --export > ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2/helm-repository.yaml
```

#### La Helm Release podinfo2

Si l'on veut personnaliser la configuration de la Helm Release, on peut se référer aux paramètres ici :

!!! info
    https://artifacthub.io/packages/helm/podinfo/podinfo

Dans notre cas, nous souhaitons simplement afficher le message 'Hello' dans la UI :

```sh
echo 'ui.message: Hello' > ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2/helm-release.values.yaml

flux create helmrelease podinfo2 \
  --source=HelmRepository/podinfo2 \
  --chart=podinfo \
  #--version=">6.0.0" \
  --values=${WORKING_DIRECTORY}/helmrelease_values/podinfo2/values.yaml \
  --namespace=podinfo2 \
  --export > ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2/helm-release.yaml

flux create hr podinfo \
  --interval=10m \
  --source=HelmRepository/podinfo \
  --chart=podinfo \
  --version=">6.0.0" \
  -export > ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2/helm-release.yaml


cat ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo2/helm-release.yaml

  ---
  apiVersion: helm.toolkit.fluxcd.io/v2beta2
  kind: HelmRelease
  metadata:
    name: podinfo2
    namespace: podinfo2
  spec:
    chart:
      spec:
        chart: podinfo
        reconcileStrategy: ChartVersion
        sourceRef:
          kind: HelmRepository
          name: podinfo2
    interval: 1m0s
    values:
      ui.message: Hello


cd ${WORKING_DIRECTORY}/kubernetes-development
git add .
git commit -m "feat: Defining a 'podinfo' Helm release."
git push


kubectl -n podinfo2 get helmrelease

  NAME       AGE   READY   STATUS
  podinfo2   40h   True    Helm install succeeded for release podinfo2/podinfo2.v1 with chart podinfo@6.5.4


kubectl -n podinfo2 get all

  NAME                            READY   STATUS    RESTARTS   AGE
  pod/podinfo2-7479bb6f76-lfxsz   1/1     Running   0          13s

  NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
  service/podinfo2   ClusterIP   10.96.217.241   <none>        9898/TCP,9999/TCP   13s

  NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
  deployment.apps/podinfo2   1/1     1            1           13s

  NAME                                  DESIRED   CURRENT   READY   AGE
  replicaset.apps/podinfo2-7479bb6f76   1         1         1       13s
```
