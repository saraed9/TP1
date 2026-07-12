# MiniDiscord

Implémentation d'un mini-Discord en **Elixir/OTP**, avec un serveur TCP multi-salons (GenServer, Supervision, ETS) et un client en ligne de commande. Projet réalisé dans le cadre des TP de programmation fonctionnelle (Elixir).

## Structure du projet

```
.
├── server/          # Serveur MiniDiscord (GenServer, Supervision, ETS, TCP)
├── client/          # Client CLI (gen_tcp, reconnexion, chiffrement)
├── cle.bin          # Clé AES-256 partagée (générée par gen_cle.exs)
├── gen_cle.exs       # Script de génération de la clé de chiffrement
└── README.md
```

## Fonctionnalités

### Côté serveur
- **Salons de discussion** : chaque salon est un `GenServer` géré dynamiquement via `DynamicSupervisor` et identifié dans un `Registry`
- **Diffusion de messages** (broadcast) aux membres d'un salon (`handle_cast`)
- **Détection de déconnexion** des clients via `Process.monitor/1` et `handle_info({:DOWN, ...})`
- **Supervision & tolérance aux pannes** : redémarrage automatique des salons plantés (stratégie `:one_for_one`)
- **Historique des messages** : conservation des 10 derniers messages par salon
- **Pseudos uniques** : gestion via une table **ETS** (`:pseudos`)
- **Commandes slash** : `/list`, `/join <salon>`, `/quit`
- **Mot de passe par salon** (bonus) : hashage SHA-256 des mots de passe
- **Chiffrement des messages** : AES-256-CTR (`:crypto`) avec IV aléatoire par message
- **Accès distant** : tunnel TCP via [bore](https://github.com/ekzhang/bore) pour exposer le serveur (utile en CodeSpace)

### Côté client
- Connexion TCP (`:gen_tcp`) au serveur
- Boucles asynchrones de réception/envoi (`Task.async`)
- **Reconnexion automatique** en cas de perte de connexion
- **Validation des messages** (vide, trop long, caractères interdits)
- **Déchiffrement** des messages reçus (clé partagée avec le serveur)

## Prérequis

- Elixir / Erlang OTP installés (`mix --version`)
- `netcat-openbsd` (test rapide en TCP brut)
- [bore](https://github.com/ekzhang/bore) pour exposer le serveur à l'extérieur d'un CodeSpace

## Lancement

### 1. Génération de la clé de chiffrement partagée

```bash
elixir gen_cle.exs
```

Cela produit `cle.bin`, à partager entre le serveur et le(s) client(s).

### 2. Démarrer le serveur

```bash
cd server
mix compile
iex -S mix
```

### 3. (Optionnel) Exposer le serveur à l'extérieur du CodeSpace

```bash
curl -L https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz | tar xz
./bore local 4040 --to bore.pub
```

### 4. Démarrer un client

```bash
cd client
mix compile
iex -S mix
```

```elixir
MiniDiscord.Client.start("localhost", 4040)
# ou, via le tunnel bore :
MiniDiscord.Client.start("bore.pub", <port_du_tunnel>)
```

## Tests rapides côté serveur (iex)

```elixir
# Créer un salon
DynamicSupervisor.start_child(MiniDiscord.SalonSupervisor, {MiniDiscord.Salon, "test"})

# Rejoindre et diffuser un message
MiniDiscord.Salon.rejoindre("test", self())
MiniDiscord.Salon.broadcast("test", "hello!")
flush()

# Tuer un salon pour tester la supervision
pid = GenServer.whereis({:via, Registry, {MiniDiscord.Registry, "general"}})
Process.exit(pid, :kill)
```

## Sécurité

- Pseudos uniques garantis via ETS
- Mots de passe de salon hashés en SHA-256
- Messages chiffrés en AES-256-CTR (clé + IV) entre client et serveur
- Validation des messages entrants côté client (longueur, caractères)

## Technologies

- Elixir / OTP (GenServer, DynamicSupervisor, Registry, Task)
- `:gen_tcp` (communication réseau bas niveau)
- ETS (Erlang Term Storage)
- `:crypto` (AES-256-CTR, SHA-256)
- [bore](https://github.com/ekzhang/bore) (tunneling TCP)

