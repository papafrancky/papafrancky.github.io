## Mkdocs-material


|Docs utiles|
|---|
|[Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)|



    docker pull squidfunk/mkdocs-material
    docker run --rm -it -v ${PWD}:/docs squidfunk/mkdocs-material new .

Cela va créer un nouveau 'projet' sur le filesystem local :

    .
    ├── README.md
    ├── docs
    │   └── index.md
    └── mkdocs.yml

Ajouter les lignes suivantes dans le fichier *'docs/mkdocs.yml'* pour activer le thème 'material' :

    theme:
      name: material

VS code :
Command + Alt + P -> dans la barre de recherche, taper : Preferences: Open User Settings (JSON)
Cela ouvrira en édition le fichier ~/Library/Application Support/Code/User/sessting.json

Ajouter dans le fichier de paramètres :

    {
      "yaml.schemas": {
        "https://squidfunk.github.io/mkdocs-material/schema.json": "mkdocs.yml"
      },
      "yaml.customTags": [ 
        "!ENV scalar",
        "!ENV sequence",
        "!relative scalar",
        "tag:yaml.org,2002:python/name:material.extensions.emoji.to_svg",
        "tag:yaml.org,2002:python/name:material.extensions.emoji.twemoji",
        "tag:yaml.org,2002:python/name:pymdownx.superfences.fence_code_format"
      ]
    }

MkDocs embarque un serveur de prévisualisaiton permettant de voir les modifications pendant que l'on écit la doc.
Le serveur reconstruira le site après sauvegarde.
Pour le démarrer :

    docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material

Pour accéder au site depuis un navigateur : 

    http://localhost:8000

Lorsque le site est fini de construire, il reste à construire le site static à partir des pages MarkDown comme ceci :

    docker run --rm -it -v ${PWD}:/docs squidfunk/mkdocs-material build

