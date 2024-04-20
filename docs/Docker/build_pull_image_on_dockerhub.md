# Créer et publier une image sur DockerHub

Ce howto montre comment créer et publier une image Docker sur DockerHub à partir d'un exemple simple.


## L'image Docker

Le conteneur va afficher une page web contenant le nom d'hôte du conteneur. Le fond de la page est blanc par défaut mais il est possible de le changer en surchargeant la variable HTML_COLOR.


### Dockerfile

```sh title="Dockerfile"
FROM nginx:latest
COPY nginx-custom-index.sh /docker-entrypoint.d/
RUN chmod a+x /docker-entrypoint.d/nginx-custom-index.sh
```


### Script

Le script ci-dessous créé la page web. Il doit être placé dans le même répertoire que le fichier Dockerfile.


```sh title="nginx-custom-index.sh"
#!/bin/sh

# This script creates a custom html indexpage 
# which displays the host name of the container/pod 
# with a background color given by the HTML_COLOR variable.

DEFAULT_HTML_COLOR="white"
HTML_ROOT_DIR="/usr/share/nginx/html"

[[ -z ${HTML_COLOR} ]] && HTML_COLOR=${DEFAULT_HTML_COLOR}

printf "<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>${HTML_COLOR}</title>
    <style>
      body {
        background-color: ${HTML_COLOR};
      }
    </style>
  </head>
    <body>
        <div style="text-align:center">
          ${HOSTNAME}
        </div>
    </body>
</html>\n" > ${HTML_ROOT_DIR}/index.html
```


## *Build* de l'image

```sh
# build
docker image build -t color-app:v1 .

# check
docker image ls color-app
```


    

## Exécution de l'image


### Comportement par défaut

```sh
## docker run
docker container run -d -p 80:80 --name color-app color-app:v1


# check the output
curl http://localhost:80/

  <!DOCTYPE html>
  <html>
    <head>
      <meta charset=utf-8 />
      <title>white</title>
      <style>
        body {
          background-color: white;
        }
      </style>
    </head>
      <body>
          <div style=text-align:center>
            082f7627d71b
          </div>
      </body>
  </html>
```


### Surcharge de la couleur de fond

```sh
# docker run
docker container run -d -p 80:80 --name color-app -e HTML_COLOR=blue color-app:v1
    
# check the output
curl http://localhost:80/
    
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset=utf-8 />
      <title>blue</title>
      <style>
        body {
          background-color: blue;
        }
      </style>
    </head>
      <body>
          <div style=text-align:center>
            9bc86e325288
          </div>
      </body>
  </html>
```


## *Push* de l'image sur DockerHub

```sh
docker tag color-app:v1 <registry>/color-app:v1
docker login
docker push <registry>/color-app:v1
```

!!! tip
    Mon *Docker ID* : zigouigoui

Mon image sera accessible à l'adresse suivante :
```sh
https://hub.docker.com/repository/docker/zigouigoui/color-app
```
