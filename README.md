# osTicket sur Coolify (une ressource, install automatique)

Déploie [osTicket](https://osticket.com) 1.18.4 sur Coolify en **une seule ressource
Docker Compose**, sans passer par le wizard web : l'app se construit, la base se
crée, l'installation se fait et le dossier `setup/` se supprime tout seul au
premier démarrage.

## Pourquoi ce repo existe

Le template osTicket de Coolify ne fonctionne plus : il tirait une image Docker
tierce qui a été retirée. Or il n'existe plus aucune image osTicket publique
maintenue à jour (les dernières publiques sont bloquées en 1.12, 2020). Ce repo
construit sa propre image à partir de la release officielle, tu ne dépends de
personne.

## Comment ça marche

- `Dockerfile` : PHP 8.2 + Apache + extensions osTicket, télécharge la release
  officielle `osTicket-v1.18.4.zip`.
- `ost-autoinstall.php` : appelle directement la classe `Installer` d'osTicket
  avec des variables d'environnement (aucun wizard, aucune logique SQL
  réécrite, donc robuste).
- `docker-entrypoint.sh` : au boot, sème le code dans un volume persistant,
  attend la base, installe si nécessaire, puis **supprime `setup/` et verrouille
  `include/ost-config.php` en 644** automatiquement. Si l'install échoue, il
  garde `setup/` pour permettre une reprise.
- `docker-compose.yaml` : service `osticket` (build) + service `db` (MariaDB 11),
  volumes persistants pour le code/uploads et pour la base.

## Déploiement Coolify

1. **New Resource → Docker Compose**, source = ce dépôt Git.
2. Renseigne les variables d'environnement (voir tableau ci-dessous).
3. Assigne ton domaine au service `osticket` (port 80). Coolify gère proxy + SSL.
4. **Deploy**. Au bout d'une minute, va sur ton domaine : osTicket est déjà
   installé, connecte-toi avec le compte admin défini dans les variables.

## Variables d'environnement

| Variable | Obligatoire | Défaut | Note |
|---|---|---|---|
| `OSTICKET_EMAIL` | oui | — | Email système du helpdesk. **Doit différer** de `ADMIN_EMAIL`. |
| `ADMIN_EMAIL` | oui | — | Email du compte admin. |
| `ADMIN_PASSWORD` | oui | — | Mot de passe admin (8+ caractères). |
| `DB_PASSWORD` | oui | — | Mot de passe de l'utilisateur MariaDB. |
| `DB_ROOT_PASSWORD` | oui | — | Mot de passe root MariaDB. |
| `OSTICKET_NAME` | non | `Support` | Nom du helpdesk. |
| `ADMIN_FIRSTNAME` | non | `Admin` | Prénom de l'admin. |
| `ADMIN_LASTNAME` | non | `Support` | Nom de l'admin. |
| `ADMIN_USERNAME` | non | `ostadmin` | Login admin. **Interdit** : `admin`, `osticket`, `username`. |
| `DB_NAME` | non | `osticket` | |
| `DB_USER` | non | `osticket` | |
| `TABLE_PREFIX` | non | `ost_` | Doit finir par `_`. |
| `OSTICKET_TIMEZONE` | non | `Europe/Paris` | |
| `OSTICKET_LANG` | non | `en_US` | La langue FR s'ajoute après coup depuis l'admin. |

Astuce : pour `DB_PASSWORD`, `DB_ROOT_PASSWORD` et `ADMIN_PASSWORD`, utilise le
générateur de secret de Coolify.

## Après l'installation

- L'UI est en anglais par défaut. Pour le français : Admin Panel → Manage →
  Languages, télécharge le pack `fr_FR`, puis règle la langue.
- **Email** : cette image n'inclut pas l'extension PHP `imap` (la lib système a
  été retirée de Debian et l'extension est dépréciée). Le fetch d'email par
  IMAP/POP est donc désactivé. Si tu en as besoin, décommente le bloc IMAP dans
  le `Dockerfile` (peut échouer selon la dispo de la lib) et rebuild.

## Mise à jour d'osTicket

Le code vit dans un volume persistant. Bumper `OSTICKET_VERSION` dans le
`Dockerfile` ne suffit pas à mettre à jour un volume déjà peuplé : passe par
l'upgrader web d'osTicket, ou pars sur un nouveau volume.
