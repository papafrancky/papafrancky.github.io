
|Topic|URL|
|---|---|
|Kind install|https://kind.sigs.k8s.io/docs/user/quick-start|
|Flux install|https://fluxcd.io/flux/installation/|
|Flux alerts|https://fluxcd.io/flux/monitoring/alerts/|
|Flux - notification controller - discord provider|https://fluxcd.io/flux/components/notification/providers/#discord|
|FluxCD - image policies - filter tags|https://fluxcd.io/flux/components/image/imagepolicies/#filter-tags|
|FluxCD - Guides - Automate image updates to Git|https://fluxcd.io/flux/guides/image-update/|
|Force FluxCD reconciliation|flux reconcile kustomization flux-system --with-source|
|Medium - How to make ahs share your own Helm package|https://medium.com/containerum/how-to-make-and-share-your-own-helm-package-50ae40f6c221|
|GitHub Pages|https://pages.github.com/|
|OCI repositories|https://fluxcd.io/flux/components/source/ocirepositories/|


# Pre-requisites

## My variables

|variable|value|
|---|---|
|KIND_CLUSTER_NAME|sandbox|
|GITHUB_USERNAME|papafrancky|
|GITHUB_PAT|\$( cat ~/secrets/github.${GITHUB_USERNAME}.PAT.FluxCD.txt )|
|DISCORD_WEBHOOK|\$( cat ${HOME}/secrets/discord.gitops.webhook.txt )|
|WORKING_DIR|${HOME}/code/github|


## Kind install

    brew upgrade && brew install kind
    kind version
    kind create cluster --name ${KIND_CLUSTER_NAME}
    kind get clusters


## Flux CLI install

    curl -s https://fluxcd.io/install.sh | sudo bash


## GitHub repositories :
2 GitHub repos must be created to meet our needs :
|USAGE|URL|
|---|---|
|One for FluxCD itself|https://github.com/${GITHUB_USERNAME}/gitops|
|Another one for the apps to be deployed|https://github.com/${GITHUB_USERNAME}/gitops-deployments|

## Make sure your Kubernetes cluster complies with FluxCD

    flux check --pre

## Boostrap FluxCD

To do this, you will need a GitHub classic Personal Access Token (PAT) with full repo access.

    export GITHUB_USER=${GITHUB_USERNAME}
    export GITHUB_TOKEN=${GITHUB_PAT}

    flux bootstrap github \
      --token-auth \
      --owner ${GITHUB_USER} \
      --repository gitops \
      --branch=main \
      --path=clusters/${KIND_CLUSTER_NAME} \
      --personal \
      --components-extra=image-reflector-controller,image-automation-controller

    -> Check with your browser :
    https://github.com/${GITHUB_USERNAME}/gitops/tree/main/clusters/${KIND_CLUSTER_NAME}/flux-system

    kubectl -n flux-system get all



# Alerting (Discord)

## Local stuff

    # Clone 'gitops' repo locally :
    cd ${WORKING_DIR}
    git clone git@github.com:${GITHUB_USERNAME}/gitops.git

    # Create directories related to notifications :
    cd gitops/clusters/${KIND_CLUSTER_NAME}
    mkdir -p notifications/{providers,alerts}

    # Create a Kubernetes secrets from the Discord webhook :
    k create secret generic discord-gitops --from-file=address=${HOME}/secrets/discord.gitops.webhook.txt


## Create an alert-provider on the #gitops Discord channel

    flux create alert-provider discord-gitops \
      --type=discord \
      --secret-ref=discord-gitops \
      --channel=gitops \
      --username=FluxCD \
      --namespace=default \
      --export > notifications/providers/discord-gitops-provider.yaml
    
    cat notifications/providers/discord-gitops-provider.yaml
      #  ---
      #  apiVersion: notification.toolkit.fluxcd.io/v1beta3
      #  kind: Provider
      #  metadata:
      #    name: discord-gitops
      #    namespace: default
      #  spec:
      #    channel: gitops
      #    secretRef:
      #      name: discord-gitops
      #    type: discord
      #    username: FluxCD

## Create an alert on Git repos and Kustomizations

    flux create alert discord-gitops-alert \
      --event-severity=info \
      --event-source='GitRepository/*,Kustomization/*' \
      --provider-ref=discord-gitops \
      --namespace=default \
      --export > notifications/alerts/discord-gitops-alert.yaml

    cat notifications/alerts/discord-gitops-alert.yaml
      # ---
      # apiVersion: notification.toolkit.fluxcd.io/v1beta3
      # kind: Alert
      # metadata:
      #   name: discord-gitops-alert
      #   namespace: default
      # spec:
      #   eventSeverity: info
      #   eventSources:
      #   - kind: GitRepository
      #     name: '*'
      #   - kind: Kustomization
      #     name: '*'
      #   providerRef:
      #     name: discord-gitops
    
    
    cd ${WORKING_DIR}/gitops
    git st
    git add notifications
    git commit -m 'feat: discord alerting'
    git push


    kubectl get providers,alerts -n default
      # NAME                                                        AGE
      # provider.notification.toolkit.fluxcd.io/discord-gitops      32m
      #
      # NAME                                                        AGE
      # alert.notification.toolkit.fluxcd.io/discord-gitops-alert   29s


## Allow FluxCD to authenticate to GitHub

### Secret creation (SSH keys)
    flux create secret git gitops-deployments-auth \
      --url=ssh://github.com/${GITHUB_USERNAME}/gitops-deployments \
      --namespace=default

      # ✚ deploy key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBEww+J8GaJDlxQHeB6M+qrWyn3hcv2Jj8IS5gC+O6kQOvu2hKr0iqaduoottECNXEgRbdEqABzY8gZ9Xb77e5wfskVUOqKfdiv12/CVbLFj1eH1WFlUH+Vy7Wff0I0JEAw==
      #
      # ► git secret 'gitops-deployments-auth' created in 'default' namespace

### Add the newly created public key to the 'gitops-deployments' Github repository

* The public key appears as the 'deploy key' at its creation time.
* Add the public key (deploy key) in https://github.com/${GITHUB_USERNAME}/gitops-deployments/settings/keys/new; give it the name _'gitops'_ et check the box _'Allow write access'_.


### Clone the apps Github repository locally

    git clone git@github.com:${GITHUB_USERNAME}/gitops-deployments.git



## Configure FluxCD for automated deployments

### Create a GitRepository manifest

    cd ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}
    mkdir -p {sources,kustomizations}

    flux create source git nginxhello \
      --url=ssh://github.com/${GITHUB_USERNAME}/gitops-deployments \
      --branch=main \
      --secret-ref=gitops-deployments-auth \
      --namespace=default \
      --export > sources/nginxhello-source.yaml

    cat sources/nginxhello-source.yaml

      # ---
      # apiVersion: source.toolkit.fluxcd.io/v1
      # kind: GitRepository
      # metadata:
      #   name: nginxhello
      #   namespace: default
      # spec:
      #   interval: 1m0s
      #   ref:
      #     branch: main
      #   secretRef:
      #     name: gitops-deployments-auth
      #   url: ssh://github.com/${GITHUB_USERNAME}/gitops-deployments


### Create a Kustomization manifest

      flux create kustomization nginxhello \
        --source=GitRepository/nginxhello.default \
        --path=./nginxhello \
        --prune=true \
        --target-namespace=default \
        --namespace=default \
        --export > kustomizations/nginxhello-kustomization.yaml

      cat kustomizations/nginxhello-kustomization.yaml

      # ---
      # apiVersion: kustomize.toolkit.fluxcd.io/v1
      # kind: Kustomization
      # metadata:
      #   name: nginxhello
      #   namespace: default
      # spec:
      #   interval: 1m0s
      #   path: ./nginxhello
      #   prune: true
      #   sourceRef:
      #     kind: GitRepository
      #     name: nginxhello
      #     namespace: default
      #    targetNamespace: default


### Push changes to GitHub repo

    git add sources kustomizations
    git commit -m ""
    git push

-> From now on, FluxCD will reconcile the apps Github repository.


### check FluxCD manages the new objects as expected

    kubectl get GitRepositories -n default

      # NAME         URL                                               AGE     READY   STATUS
      # nginxhello   ssh://github.com/${GITHUB_USERNAME}/gitops-deployments   2m14s   False   git repository is empty


    kubectl get kustomizations -n default

      # NAME         AGE    READY   STATUS
      # nginxhello   3m1s   False   Source artifact not found, retrying in 30s


### Add an application into the apps Github repository

Copy the _'deployment.yaml'_ and _'service.yaml'_ manifests :
* from Nigel Brown's example repository ( https://github.com/nbrownuk/gitops-nginxhello/ )
* to our Github repo dedicated to FluxCD ( https://github.com/${GITHUB_USERNAME}/gitops ) 

Then, push the changes to your 'gitops' repo : 

    cd ${WORKING_DIR}/ gitops
    git add .
    git commit -m 'feat: added the application 'nginxhello'.'
    git push

Finally, let's check wether FluxCD manages the deployment of the application as expected :

    kubectl get GitRepositories

      # NAME         URL                                               AGE   READY   STATUS
      # nginxhello   ssh://github.com/${GITHUB_USERNAME}/gitops-deployments   26m   True    stored artifact for revision 'main@sha1:b223021b6ff0fee832941e0825a6203e4775196c'


    kubectl get kustomizations

      # NAME         AGE   READY   STATUS
      # nginxhello   28h   True    Applied revision: main@sha1:3a1755be8df43fc45bb467490aa0adc52117a4e7


    kubectl get services

    kubectl port-forward service/nginxhello 8080:80
      # -> open a browser and check if you can see nginxhello's page correctly : http://localhost:8080 


### Testing a modification on the newly deployed application

We will change the number of replicas and the version of the application :

    vi ${WORKING_DIR}/gitops-deployments/nginxhello/deployment.yaml
      # -> changer :
      #      .spec.replicas : 2 -> 4
      #      .spec.template.spec.containers[0].image : nbrown/nginxhello:1.19.0 -> nbrown/nginxhello:1.24.0


Push the changes to GitHub :

    cd ${WORKING_DIR}/gitops-deployments
    git add .
    git commit -m 'evol: changed replicas number and app version.'
    git push


Let's observe FluxCD's reconciliation :

    # Watch the pods during the operation :
    kubectl get po -w

    # Check the _'nginxhello'_ GitRepository status : it should show the SHA1 of the commit (cf. _'git logs'_) :
    kubectl get GitRepositories

    # Check you #gitops Discord channel : you should have received 2 new alerts.

    # Connect to the _'nginxhello'_ app :
    kubectl port-forward service/nginxhello 8080:80 
    -> open a browser and access the following URL: http://localhost:8080 -> the app version should be 1.24.0



## Handling application updates with image automation

### Create an ImageRepository

    cd ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}
    flux create image repository nginxhello \
      --image=nbrown/nginxhello \
      --interval=5m \
      --namespace=default \
      --export > sources/nginxhello-imagerepository.yaml

    cat sources/nginxhello-imagerepository.yaml
    # ---
    # apiVersion: image.toolkit.fluxcd.io/v1beta2
    # kind: ImageRepository
    # metadata:
    #   name: nginxhello
    #   namespace: default
    # spec:
    #   image: nbrown/nginxhello
    #   interval: 5m0s

Push the changes to GitHub :

    cd ${WORKING_DIR}/gitops
    git add .
    git commit -m 'feat: added nginxhello image repository manifest.' 
    git push

    kubectl get imagerepositories


### Modify the Discord alert to manage image policies

    cd ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}
    vi notifications/alerts/discord-gitops-alert.yaml

    # ---
    # apiVersion: notification.toolkit.fluxcd.io/v1beta3
    # kind: Alert
    # metadata:
    #   name: discord-gitops-alert
    #   namespace: default
    # spec:
    #   eventSeverity: info
    #   eventSources:
    #   - kind: GitRepository
    #     name: '*'
    #   - kind: Kustomization
    #     name: '*'
    #   - kind: ImagePolicy
    #     name: '*'
    #   providerRef:
    #     name: discord-gitops

### Create an image policy

    cd ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}
    mkdir imagepolicies
    flux create image policy nginxhello \
      --image-ref=nginxhello \
      --select-semver='>=1.20.x' \
      --namespace=default \
      --export > imagepolicies/nginxhello-image-policy.yaml

    cat imagepolicies/nginxhello-image-policy.yaml

    # ---
    # apiVersion: image.toolkit.fluxcd.io/v1beta2
    # kind: ImagePolicy
    # metadata:
    #   name: nginxhello
    #   namespace: default
    # spec:
    #   imageRepositoryRef:
    #     name: nginxhello
    #   policy:
    #     semver:
    #       range: '>=1.20.x'

Push the changes to GitHub :

    cd ${WORKING_DIR}/gitops
    git add .
    git commit -m "feat: added a new image policy"
    git push

    kubectl get imagepolicies

      # NAME         LATESTIMAGE
      # nginxhello

    kubectl describe imagerepository nginxhello

      # Name:         nginxhello
      # Namespace:    default
      # Labels:       kustomize.toolkit.fluxcd.io/name=flux-system
      #               kustomize.toolkit.fluxcd.io/namespace=flux-system
      # Annotations:  <none>
      # API Version:  image.toolkit.fluxcd.io/v1beta2
      # Kind:         ImageRepository
      # Metadata:
      #   Creation Timestamp:  2023-12-29T17:27:59Z
      #   Finalizers:
      #     finalizers.fluxcd.io
      #   Generation:        2
      #   Resource Version:  47347
      #   UID:               0eaf8380-5fad-4458-aca0-826f02d74abc
      # Spec:
      #   Exclusion List:
      #     ^.*\.sig$
      #   Image:     docker.io/nbrown/nginxhello
      #   Interval:  5m0s
      #   Provider:  generic
      # Status:
      #   Canonical Image Name:  index.docker.io/nbrown/nginxhello
      #   Conditions:
      #     Last Transition Time:  2023-12-29T18:16:39Z
      #     Message:               successful scan: found 45 tags
      #     Observed Generation:   2
      #     Reason:                Succeeded
      #     Status:                True
      #     Type:                  Ready
      #   Last Scan Result:
      #     Latest Tags:
      #       stable
      #       mainline
      #       latest
      #       e6c463e6
      #       aad042cb
      #       1.25.2
      #       1.25
      #       1.24.0
      #       1.24
      #       1.23.3
      #     Scan Time:  2023-12-29T18:16:39Z
      #     Tag Count:  45
      #   Observed Exclusion List:
      #     ^.*\.sig$
      #   Observed Generation:  2
      # Events:
      # (...)

You should have received an alert on the _'#gitops'_ Discord channel : 

    imagepolicy/nginxhello.default
    Latest image tag for 'docker.io/nbrown/nginxhello' resolved to 1.25.2

Some additiona checks can be done :

    kubectl get imagepolicies

      # NAME         LATESTIMAGE
      # nginxhello   docker.io/nbrown/nginxhello:1.25.2


    kubectl get deployment nginxhello -o yaml | yq '.spec.template.spec.containers[].image'

      # nbrown/nginxhello:1.20.1    # the deployed version isn't the latest one.


### Updating our application version with the image automation

#### Adding a marker to the deployment

    cd ${WORKING_DIR}/gitops-deployments
    vi ${WORKING_DIR}/gitops-deployments/nginxhello/deployment.yaml

      # ---
      # apiVersion: apps/v1
      # kind: Deployment
      # metadata:
      #   labels:
      #     app: nginxhello
      #   name: nginxhello
      #   annotations:
      #     fluxcd.io/ignore: "true"
      #     fluxcd.io/automated: "false"
      # spec:
      #   replicas: 4
      #   selector:
      #     matchLabels:
      #       app: nginxhello
      #   template:
      #     metadata:
      #       labels:
      #         app: nginxhello
      #     spec:
      #       containers:
      #       - image: docker.io/nbrown/nginxhello:1.25.2 # {"$imagepolicy": "default:nginxhello"}
      #         name: nginxhello
      #         ports:
      #         - containerPort: 80
      #         env:
      #         - name: NODE_NAME
      #           valueFrom:
      #             fieldRef:
      #               fieldPath: spec.nodeName
      #         livenessProbe:
      #           initialDelaySeconds: 2
      #           periodSeconds: 2
      #           httpGet:
      #             port: 80
      #             path: /healthz/live
      #         readinessProbe:
      #           initialDelaySeconds: 2
      #           periodSeconds: 2
      #           httpGet:
      #             port: 80
      #             path: /healthz/ready 

    git add .
    git commit -m "feat: added a version marker to the _'nginxhello'_ deployment manifest."
    git push

Let's check the SHA1 of our commit :

    git log

      # commit ed03554ba51d9f1e29f38711d667efebd3c9e33c (HEAD -> main, origin/main)
      # Author: Franck Levesque <franck.levesque@gmail.com>
      # Date:   Sat Dec 30 13:29:46 2023 +0100
      #
      # feat: added a version marker to the _'nginxhello'_ deployment manifest.


We should see the same SHA1 commit in the gitRepository now :

    kubectl get gitrepository nginxhello
    
      # NAME         URL                                               AGE     READY   STATUS
      # nginxhello   ssh://github.com/${GITHUB_USERNAME}/gitops-deployments   2d18h   True    stored artifact for revision 'main@sha1:ed03554ba51d9f1e29f38711d667efebd3c9e33c'

It should also appear in a Discord alert :

    FluxCD BOT
     — Aujourd’hui à 13:31
    gitrepository/nginxhello.default
    stored artifact for commit 'evol: added maker to the deployment manifest'
    revision
    main@sha1:ed03554ba51d9f1e29f38711d667efebd3c9e33c


#### Image update automation

Write a template in order to format the commits created by FluxCD :

    cd ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}
    mkdir imageupdateautomations
    vi imageupdateautomations/msg_template

      # Flux automated image update
      # 
      # Automation name: {{ .AutomationObject }}
      # 
      # Files:
      # {{ range $filename, $_ := .Updated.Files -}}
      # - {{ $filename }}
      # {{ end -}}
      # 
      # Objects:
      # {{ range $resource, $_ := .Updated.Objects -}}
      # - {{ $resource.Kind }} {{ $resource.Name }}
      # {{ end -}}
      # 
      # Images:
      # {{ range .Updated.Images -}}
      # - {{.}}
      # {{ end -}}

Create the imageUpdateAutomation manufest :

      flux create image update nginxhello \
        --git-repo-ref=nginxhello \
        --git-repo-path=./nginxhello \
        --checkout-branch=main \
        --push-branch=main \
        --author-name=FluxCD \
        --author-email=gitops@users.noreply.github.com \
        --commit-template="$( cat ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/imageupdateautomations/msg_template )" \
        --namespace=default \
        --export > ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/imageupdateautomations/nginxhello.yaml

cat ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/imageupdateautomations/nginxhello.yaml

      # ---
      # apiVersion: image.toolkit.fluxcd.io/v1beta1
      # kind: ImageUpdateAutomation
      # metadata:
      #   name: nginxhello
      #   namespace: default
      # spec:
      #   git:
      #     checkout:
      #       ref:
      #         branch: main
      #     commit:
      #       author:
      #         email: gitops@users.noreply.github.com
      #         name: FluxCD
      #       messageTemplate: |-
      #         Flux automated image update
      # 
      #         Automation name: {{ .AutomationObject }}
      # 
      #         Files:
      #         {{ range $filename, $_ := .Updated.Files -}}
      #         - {{ $filename }}
      #         {{ end -}}
      # 
      #         Objects:
      #         {{ range $resource, $_ := .Updated.Objects -}}
      #         - {{ $resource.Kind }} {{ $resource.Name }}
      #         {{ end -}}
      # 
      #         Images:
      #         {{ range .Updated.Images -}}
      #         - {{.}}
      #         {{ end -}}
      #     push:
      #       branch: main
      #   interval: 1m0s
      #   sourceRef:
      #     kind: GitRepository
      #     name: gitops-deployments
      #   update:
      #     path: ./nginxhello
      #     strategy: Setters

Push the changes to GitHub :

    cd ${WORKING_DIR}/gitops
    git add .
    git commit -m "feat: created an image update automation manifest for nginxhello."
    git push

Check the changes :

    kubectl get pods -w
    kubectl get imageupdateautomations
    k get deployment nginxhello -o yaml | yq '.spec.template.spec.containers[].image'

      # nbrown/nginxhello:1.20.1
      # This is not the latest version.

    cd ${WORKING_DIR}/gitops-deployments
    git fetch      # our branch is not up-to-date (1 commit missing).
    git pull
    git log -1     # the commit message looks like our commit template.

    cat ${WORKING_DIR}/gitops-deployments/nginxhello/deployment.yaml| grep 'image:'
    
      # - image: docker.io/nbrown/nginxhello:1.25.2 # {"$imagepolicy": "default:nginxhello"}
      # -> latest version : 1.25.2 

    kubectl describe imageupdateautomations nginxhello

      # Flux automated image update
      # 
      # Automation name: default/nginxhello
      # 
      # Files:
      # - deployment.yaml
      # Objects:
      # - Deployment nginxhello
      # 
      # 
      # Images:
      # - docker.io/nbrown/nginxhello:1.25.2



## Automating packages releases with the Helm controller

### Cleaning 

    cd ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}
    mkdir _backup
    tar cvzf _backup/imagepolicies.tgz imagepolicies
    tar cvzf _backup/imageupdateautomations.tgz imageupdateautomations
    tar cvzf _backup/kustomizations.tgz kustomizations 
    tar cvzf _backup/sources_nginxhello-imagerepository.yaml.tgz sources/nginxhello-imagerepository.yaml
    rm -rf image* kustomizations sources/nginxhello-imagerepository.yaml
    
    tree
    
      # .
      # ├── _backup
      # │   ├── imagepolicies.tgz
      # │   ├── imageupdateautomations.tgz
      # │   ├── kustomizations.tgz
      # │   └── sources_nginxhello-imagerepository.yaml.tgz
      # ├── flux-system
      # │   ├── gotk-components.yaml
      # │   ├── gotk-sync.yaml
      # │   └── kustomization.yaml
      # ├── notifications
      # │   ├── alerts
      # │   │   └── discord-gitops-alert.yaml
      # │   └── providers
      # │       └── discord-gitops-provider.yaml
      # └── sources
      #     └── nginxhello-source.yaml
    
    cd ${WORKING_DIR}/gitops
    git add .
    git commit -m 'feat: cleaning before using Helm charts.'
    git push

You should receive an alert in the _'#gitops'_ Discord channel :

    FluxCD BOT
     — Aujourd’hui à 16:04
    kustomization/nginxhello.default
    Deployment/default/nginxhello deleted
    Service/default/nginxhello deleted
    revision
    main@sha1:5855cb796a4e1b7cd07d3c9da8351debb0dff3f5

Normally, you shouldn't see any pods again :

    kubectl get pods -n default
    
      # No resources found in default namespace.


### Configuring a Helm Repository

#### Discord alerting

First, let's modify the Discord alerts to manage the helmRepositories into account :

    vi notifications/alerts/discord-gitops-alert.yaml

    # ---
    # apiVersion: notification.toolkit.fluxcd.io/v1beta3
    # kind: Alert
    # metadata:
    #   name: discord-gitops-alert
    #   namespace: default
    # spec:
    #   eventSeverity: info
    #   eventSources:
    #   - kind: GitRepository
    #     name: '*'
    #   - kind: Kustomization
    #     name: '*'
    #   - kind: ImagePolicy
    #     name: '*'
    #   - kind: HelmRepository
    #     name: '*'
    #   providerRef:
    #     name: discord-gitops


#### The _'podinfo'_ Helm Chart

We will use the _'podinfo'_ Helm chart as an example.

    helm show chart oci://ghcr.io/stefanprodan/charts/podinfo
    
      # Pulled: ghcr.io/stefanprodan/charts/podinfo:6.5.4
      # Digest: sha256:a961643aa644f24d66ad05af2cdc8dcf2e349947921c3791fc3b7883f6b1777f
      # apiVersion: v1
      # appVersion: 6.5.4
      # description: Podinfo Helm chart for Kubernetes
      # home: https://github.com/stefanprodan/podinfo
      # kubeVersion: '>=1.23.0-0'
      # maintainers:
      # - email: stefanprodan@users.noreply.github.com
      #   name: stefanprodan
      # name: podinfo
      # sources:
      # - https://github.com/stefanprodan/podinfo
      # version: 6.5.4


#### Creating the _'podinfo'_ helmRepository

##### Authenticating to the Helm repository

Let's create a new _'Docker registry'_ type secret allowinf us to retrieve the Helm chart.
(ghcr.io belongs to GitHub; they both use the same identity management)

**NOTE** : this repository is a public one; in our case there will be no need to specify credentials in the helmRepository.

    export GITHUB_USER=${GITHUB_USERNAME}
    export GITHUB_TOKEN=$(GITHUB_PAT)

    kubectl create secret docker-registry ghcr-charts-auth \
      --docker-server=ghcr.io \
      --docker-username=${GITHUB_USER} \
      --docker-password=-{GITHUB_TOKEN}


##### Creating the helmRepository manifest

    flux create source helm podinfo \
      --url=https://stefanprodan.github.io/podinfo \
      --namespace=default \
      --interval=1m \
      --export > ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/sources/podinfo.yaml
    

    cat ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/sources/podinfo.yaml
    
      # ---
      # apiVersion: source.toolkit.fluxcd.io/v1beta2
      # kind: HelmRepository
      # metadata:
      #   name: podinfo
      #   namespace: default
      # spec:
      #   interval: 1m0s
      #   url: https://stefanprodan.github.io/podinfo


#### Pushing the changes to GitHub

    cd ${WORKING_DIR}/gitops
    git add .
    git commit -m "feat: Defining a 'podinfo' Helm repository."
    git push


    kubectl get helmrepo 

    # NAME      URL                                      AGE    READY   STATUS
    # podinfo   https://stefanprodan.github.io/podinfo   116s   True    stored artifact: revision 'sha256:faeeeb1a7a887b5fe4d440164d29f58ba6f186d46fdf069fd227c39e9fc6ae09'


### The _'podinfo'_ helmRelease

    cd ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/
    mkdir helmreleases

    tree

      # .
      # ├── _backup
      # │   ├── imagepolicies.tgz
      # │   ├── imageupdateautomations.tgz
      # │   ├── kustomizations.tgz
      # │   └── sources_nginxhello-imagerepository.yaml.tgz
      # ├── flux-system
      # │   ├── gotk-components.yaml
      # │   ├── gotk-sync.yaml
      # │   └── kustomization.yaml
      # ├── helmreleases
      # ├── notifications
      # │   ├── alerts
      # │   │   └── discord-gitops-alert.yaml
      # │   └── providers
      # │       └── discord-gitops-provider.yaml
      # └── sources
      #     ├── nginxhello-source.yaml
      #     └── podinfo.yaml

If you need to customize the configuration of your Helm release, you can find all the parameters for the Values file here :

    https://artifacthub.io/packages/helm/podinfo/podinfo

In our case, we will only want to add a simple "Hello" message in the UI :

    echo 'ui.message: Hello' > ${WORKING_DIR}/gitops/clusters/podinfo.values.yaml

Now, let's create the helmRelease object :

    flux create helmrelease podinfo \
      --source=HelmRepository/podinfo \
      --chart=podinfo \
      --values=${WORKING_DIR}/gitops/clusters/podinfo.values.yaml \
      --namespace=default \
      --export > ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/helmreleases/podinfo.yaml


    cat ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/helmreleases/podinfo.yaml
    
    # apiVersion: helm.toolkit.fluxcd.io/v2beta2
    # kind: HelmRelease
    # metadata:
    #   name: podinfo
    #   namespace: default
    # spec:
    #   chart:
    #     spec:
    #       chart: podinfo
    #       reconcileStrategy: ChartVersion
    #       sourceRef:
    #         kind: HelmRepository
    #         name: podinfo
    #   interval: 1m0s
    #   values:
    #     ui.message: Hello

Push the changes to GitHub :

    cd ${WORKING_DIR}/gitops
    git add .
    git commit -m "feat: Defining a 'podinfo' Helm release."
    git push

Let's check the good deployment of the _'podinfo'_ Helm release :

    kubectl get helmreleases

    # NAME      AGE   READY   STATUS
    # podinfo   78m   True    Helm install succeeded for release default/podinfo.v1 with chart podinfo@6.5.4


    # Is the pod running ?
    kubectl get po

    # NAME                      READY   STATUS    RESTARTS   AGE
    # podinfo-8c4b88bf8-2j8sd   1/1     Running   0          16m


    # Let's access the _'podinfo'_ web page : 
    kubectl port-forward service/podinfo 8080:9898

    # Forwarding from 127.0.0.1:8080 -> 9898
    # Forwarding from [::1]:8080 -> 9898
    # Handling connection for 8080
    -> open a browser : http://localhost:8080/



##### remediation 

Read the proper documentation for more details.
Remediation allows to rollback for instance afer 2 unsuccessful update tries :

In the example below, we will add to the HelmRelease manifest :

    .spec.upgrade.remedation.retries: 2

Let's edit the manifest :

    vi ${WORKING_DIR}/gitops/clusters/${KIND_CLUSTER_NAME}/helmreleases/podinfo.yaml
    
      # ---
      # apiVersion: helm.toolkit.fluxcd.io/v2beta2
      # kind: HelmRelease
      # metadata:
      #   name: podinfo
      #   namespace: default
      # spec:
      #   chart:
      #     spec:
      #       chart: podinfo
      #       reconcileStrategy: ChartVersion
      #       sourceRef:
      #         kind: HelmRepository
      #         name: podinfo
      #   interval: 1m0s
      #   values:
      #     ui.message: Hello
      #   upgrade:
      #     remediation:
      #       retries: 2




