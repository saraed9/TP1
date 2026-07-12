# MiniDiscord :Client

Client en ligne de commande pour se connecter au serveur [MiniDiscord](../server). Écrit en Elixir, communication via `:gen_tcp`.

## Structure

```
client/
├── lib/
│   └── client.ex     # Logique du client
├── test/
├── mix.exs
└── README.md
```

## Fonctionnalités

- **Connexion TCP** au serveur (`:gen_tcp.connect/3`, options `[:binary, packet: :line, active: false]`)
- **Choix du pseudo et du salon** à la connexion (`rencontre/1`)
- **Réception asynchrone** des messages du salon (`receive_loop/1`, via `Task.async`)
- **Envoi asynchrone** des messages tapés au clavier (`send_loop/1`, via `Task.async`)
- **Reconnexion automatique** avec backoff (2s) en cas de perte de connexion (`connect_with_retry/3`)
- **Validation des messages** avant envoi/réception : rejette les messages vides, trop longs (> 500 caractères), ou contenant des caractères interdits (`\ ? < >` ...)
- **Chiffrement AES-256-CTR** des messages envoyés/reçus, avec IV aléatoire par message (clé partagée avec le serveur via `cle.bin`)

## ⚙️ Prérequis

- Elixir / Erlang OTP
- Un serveur MiniDiscord actif (voir [../server](../server)) et sa clé de chiffrement partagée (`cle.bin`, à copier depuis la racine du projet)

## Utilisation

```bash
mix compile
iex -S mix
```

```elixir
MiniDiscord.Client.start("localhost", 4040)
# ou vers un serveur distant exposé via bore :
MiniDiscord.Client.start("bore.pub", <port_du_tunnel>)
```

À la connexion :
1. Le client affiche le message de bienvenue du serveur
2. Il demande un pseudo (`IO.gets/1`)
3. Il demande le choix d'un salon parmi ceux disponibles
4. Les messages échangés dans le salon s'affichent en direct

## Robustesse

- En cas d'échec de connexion initiale : nouvelle tentative automatique toutes les 2 secondes
- En cas de perte de connexion en cours de session : la socket est fermée proprement puis une reconnexion est retentée automatiquement
- Les messages sont validés avant envoi via `valider_message/1`, qui retourne :
  - `{:error, "Message vide"}`
  - `{:error, "Message trop long (max 500 chars)"}`
  - `{:ok, msg}` si le message est valide

## Chiffrement

Chaque message envoyé est chiffré avec la clé partagée (`cle.bin`) et un IV (Initialization Vector) généré aléatoirement :

```elixir
iv = :crypto.strong_rand_bytes(16)
msg_chiffre = :crypto.crypto_one_time(:aes_256_ctr, cle, iv, msg, true)
# envoi de iv <> msg_chiffre
```

À la réception, le client sépare l'IV (16 premiers octets) du message chiffré puis déchiffre :

```elixir
<<iv::binary-size(16), msg_chiffre::binary>> = msg_recu
msg = :crypto.crypto_one_time(:aes_256_ctr, cle, iv, msg_chiffre, false)
```

