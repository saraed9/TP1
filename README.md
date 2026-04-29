# TP1: Mini Discord
## EDIRI Sara 
### Groupe 1
---
### Phase 1:

####  Q1) Pour savoir si le client crash. Si le client meurt, le serveur est prévenu et peut le supprimer de la liste proprement.
####  Q2) Le serveur va crasher à son tour. Il reçoit un message qu'il ne comprend pas, alors il s'arrête par sécurité.
####  Q3) Call : On attend une réponse (synchrone).
#### Cast : On envoie et on oublie (asynchrone).
#### Broadcast = Cast : Parce qu'on veut juste diffuser l'info vite à tout le monde sans attendre que chaque personne dise "bien reçu".

### Pahse 2:

#### Q2-4) Oui, car il est supervisé. Le Supervisor détecte l'arrêt brutal et relance automatiquement le processus pour garantir la disponibilité du service.
#### Q2-5) La difference:
#### - one_for_one : Si un processus crash, seul celui-là est redémarré. Les autres continuent leur vie.
#### - one_for_all : Si un processus crash, le superviseur tue tous les autres et redémarre tout le groupe. Utile quand les processus dépendent strictement les uns des autres.