# Command Line Tools

Ce howto décrit l'installation des CLIs utiles pour un environnement de développement Kubernetes sur macOS.

Il sera le point d'entrée pour les autres howtos.



## Homebrew
__*Brew*__ est un *'package manager'* pour macOS.

!!! info
    [Homebrew](https://brew.sh/)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```


## kubectl

!!! info
    [Install and Set Up kubectl on macOS](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)|

```sh
brew install kubectl
kubectl version --client
```



## kubectx et kubens

!!! info
    [kubectx github page](https://github.com/ahmetb/kubectx)|

```sh
brew install kubectx
which kubectx kubens
```



## fluxctl

```sh
brew install fluxctl
```



## helm

```sh
brew install helm
helm version
```



## Discord

Discord est une messagerie instantanée permettant de configurer des _*'webhooks'*_ sur ses _*'channels'*_ sans devoir payer d'abonnement ou de souscription pour autant, comme c'est le cas avec la plateforme _*'Slack'*_ par exemple.

Pour l'installer, il faut accéder au site web **discord.com** et télécharger le client :

```sh
https://discord.com/api/download?platform=osx
```



## Docker Desktop

L'alternative possible reste Rancher.

```sh
https://www.docker.com/products/docker-desktop/
```



## Material for MkDocs

MkDocs est très pratique pour créer de la documentation à partir de fichiers écrits en MarkDown.

!!! info
    https://squidfunk.github.io/mkdocs-material/

Pour voir directement les modifications apportées sur une copie locale, il faut se placer dans le répertoire racine du dépôt de la documentation concernée et lancer le conteneur suivant :

```sh
docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material
```