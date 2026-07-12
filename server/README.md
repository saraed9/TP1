# MiniDiscord

Elixir est un langage performant dans le domaine de la concurrence et de la robustesse. Il possède également des facilités de communication réseau par son modèle acteur.

Dans ce projet, le but sera de créer un mini Discord; principalement du côté Serveur.


L'outil mix génère une arborescence de fichiers pour un projet.
``mix new mini_discord  `` a créé cette arborescence (dans le répertoire mini_discord, vous pouvez créer le projet avec un autre nom).

Prendre les fichiers fournis avec ce sujet et les installer dans votre projet pour avoir cette arborescence :
```
mon_projet/
├── lib/
│ └── chat_server.ex
│ └── client_handler.ex
│ └── mini_discord.ex
│ └── salon.ex
├── test/
├── mix.exs
├── README.md
```
où
- mix.exs : fichier central (config, dépendances, version, classe principale (mini_discord ici)...)
- lib/ : codes sources
  - mini_discord.ex : classe principale,   lance les processus 
    - MiniDiscord.Registry de type Registry : qui mappe nom -> pid (un Registry est sous forme de processus dynamique et concurrent)
    - MiniDiscord.SalonSupervisor de type DynamicSupervisor, qui gère des sous processus et peut les relancer en cas de panne
    - MiniDiscord.ChatServer
    - MiniDiscord.TaskSupervisor de type TaskSupervisor pour gérer les sockets clients (dans ChatServer)
  -  chat_server.ex : un serveur qui écoute des demandes de connections via tcp. A la reception d'une demande de connection, un processus de gestion de message est créé pour le nouveau client.
  - client_handler.ex :  Lance la relation pseudo, salon
    - si le salon n'existe pas, il est crée en tant que fils du superviseur MiniDiscord.SalonSupervisor (qui a une politique de relance automatique de ses fils)
      - un processus lié au salon sera ainsi automatiquement relancé si le précédent a planté
    - demande à la classe Salon de relié le salon au client
    - demande à la classe Salon de broadcaster à tous les membres du salon le nom du nouveau client (pseudo)
    - affiche au client qu'il peut saisir un texte
    - lance la boucle de reception de message sur le salon
  - salon.ex : cree un processus du nom du salon avec une liste de clients vide
- test/ : tests (avec ExUnit par défaut, non utilisés ici)
