<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/zenithia-logo-solar.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/zenithia-logo-golddark.svg">
  <img alt="ZénithIA" src="assets/zenithia-logo-golddark.svg" height="44">
</picture>

# osTicket sur Coolify

**Déploie osTicket 1.18.4 sur Coolify en une seule ressource, installation entièrement automatique.**

![osTicket](https://img.shields.io/badge/osTicket-1.18.4-111111)
![Coolify](https://img.shields.io/badge/Coolify-Docker%20Compose-111111)
![PHP](https://img.shields.io/badge/PHP-8.2-111111)
![MariaDB](https://img.shields.io/badge/MariaDB-11-111111)

[Français](#-français) · [English](#-english)

</div>

> ⛭ **Note.** Ce dépôt est un test de build Docker réalisé par **ZénithIA**. Objectif : rendre osTicket déployable sur Coolify en un clic, alors que le template Coolify officiel ne fonctionne plus (l'image tierce qu'il utilisait a été retirée). Le code source d'osTicket appartient à ses auteurs (GPL) et n'est pas redistribué ici : il est téléchargé au moment du build depuis la release officielle.

---

## ⛭ Français

### Le problème

Le template osTicket de Coolify ne marche plus. Il tirait une **image Docker tierce** qui a été retirée ou passée en privé. Et il n'existe plus aucune image osTicket publique maintenue à jour : les dernières images publiques sont bloquées en version 1.12 (2020), et l'image communautaire la plus sérieuse est archivée depuis 2023. Réparer le template en changeant le nom d'image ne mène donc nulle part.

### La solution

Ce dépôt **construit sa propre image** à partir de la release officielle d'osTicket, puis **installe et sécurise osTicket tout seul** au premier démarrage. Résultat : tu remplis quelques variables dans Coolify, tu cliques sur Deploy, et osTicket est prêt à l'emploi. Aucun wizard web, aucun accès au terminal.

### Comment ça marche

| Fichier | Rôle |
|---|---|
| `Dockerfile` | PHP 8.2 + Apache + extensions osTicket, télécharge la release officielle `osTicket-v1.18.4.zip`. |
| `ost-autoinstall.php` | Installe osTicket sans wizard : appelle directement la classe `Installer` native d'osTicket avec des variables d'environnement. Aucune logique SQL réécrite, donc robuste d'une version à l'autre. |
| `docker-entrypoint.sh` | Au démarrage : sème le code dans un volume persistant, attend la base, installe si nécessaire, puis **supprime `setup/` et verrouille `include/ost-config.php` en 644**. Si l'installation échoue, il conserve `setup/` pour permettre une reprise. |
| `docker-compose.yaml` | Service `osticket` (build) + service `db` (MariaDB 11), avec volumes persistants pour le code et pour la base. |

### Déploiement sur Coolify

1. Dans Coolify : **New Resource → Docker Compose**, source = ce dépôt Git.
2. Renseigne les variables d'environnement (voir le tableau plus bas). Utilise le générateur de secret de Coolify pour les mots de passe.
3. Assigne ton domaine au service `osticket` (port 80). Coolify gère le proxy et le certificat SSL.
4. Clique sur **Deploy**. Au bout d'une minute, va sur ton domaine : osTicket est déjà installé et sécurisé. Connecte-toi avec le compte admin défini dans les variables.

Pendant le premier déploiement, garde les logs ouverts : les lignes `[entrypoint]` et `[autoinstall]` retracent l'installation.

### Variables d'environnement

| Variable | Obligatoire | Défaut | Note |
|---|---|---|---|
| `OSTICKET_EMAIL` | oui | | Email système du helpdesk. Doit être différent de `ADMIN_EMAIL`. |
| `ADMIN_EMAIL` | oui | | Email du compte administrateur. |
| `ADMIN_PASSWORD` | oui | | Mot de passe admin (8 caractères minimum). |
| `DB_PASSWORD` | oui | | Mot de passe de l'utilisateur MariaDB. |
| `DB_ROOT_PASSWORD` | oui | | Mot de passe root MariaDB. |
| `OSTICKET_NAME` | non | `Support` | Nom du helpdesk. |
| `ADMIN_FIRSTNAME` | non | `Admin` | Prénom de l'administrateur. |
| `ADMIN_LASTNAME` | non | `Support` | Nom de l'administrateur. |
| `ADMIN_USERNAME` | non | `ostadmin` | Login admin. Interdits : `admin`, `osticket`, `username`. |
| `DB_NAME` | non | `osticket` | Nom de la base. |
| `DB_USER` | non | `osticket` | Utilisateur de la base. |
| `TABLE_PREFIX` | non | `ost_` | Doit se terminer par `_`. |
| `OSTICKET_TIMEZONE` | non | `Europe/Paris` | Fuseau horaire. |
| `OSTICKET_LANG` | non | `en_US` | Langue de l'installation. |

### Après l'installation

- **Langue française.** L'interface est en anglais par défaut. Pour le français : Admin Panel → Manage → Languages, télécharge le pack `fr_FR`, puis règle la langue.
- **Email entrant.** Cette image n'inclut pas l'extension PHP `imap` (la bibliothèque système a été retirée de Debian et l'extension est dépréciée). Le fetch d'email par IMAP/POP est donc désactivé par défaut. Pour l'activer, décommente le bloc IMAP dans le `Dockerfile` puis rebuild.

### Mise à jour d'osTicket

Le code vit dans un volume persistant. Changer `OSTICKET_VERSION` dans le `Dockerfile` ne met pas à jour un volume déjà peuplé. Passe par l'upgrader web intégré d'osTicket, ou repars sur un nouveau volume.

---

## ⛭ English

### The problem

Coolify's osTicket template no longer works. It pulled a **third-party Docker image** that has since been removed or made private. On top of that, there is no maintained public osTicket image left: the last public images are stuck on version 1.12 (2020), and the most serious community image has been archived since 2023. Swapping the image name in the template leads nowhere.

### The solution

This repository **builds its own image** from the official osTicket release, then **installs and hardens osTicket automatically** on first boot. You fill in a few variables in Coolify, click Deploy, and osTicket is ready. No web wizard, no terminal access.

### How it works

| File | Role |
|---|---|
| `Dockerfile` | PHP 8.2 + Apache + osTicket extensions, downloads the official `osTicket-v1.18.4.zip` release. |
| `ost-autoinstall.php` | Installs osTicket without the wizard: calls osTicket's own `Installer` class directly with environment variables. No re-implemented SQL, so it stays robust across versions. |
| `docker-entrypoint.sh` | On boot: seeds the code into a persistent volume, waits for the database, installs if needed, then **removes `setup/` and locks `include/ost-config.php` to 644**. If the install fails, it keeps `setup/` so you can retry. |
| `docker-compose.yaml` | `osticket` service (build) + `db` service (MariaDB 11), with persistent volumes for the code and the database. |

### Deploying on Coolify

1. In Coolify: **New Resource → Docker Compose**, source = this Git repository.
2. Fill in the environment variables (see the table below). Use Coolify's secret generator for the passwords.
3. Assign your domain to the `osticket` service (port 80). Coolify handles the proxy and SSL certificate.
4. Click **Deploy**. After a minute, open your domain: osTicket is already installed and hardened. Log in with the admin account defined in the variables.

During the first deployment, keep the logs open: the `[entrypoint]` and `[autoinstall]` lines trace the installation.

### Environment variables

| Variable | Required | Default | Note |
|---|---|---|---|
| `OSTICKET_EMAIL` | yes | | Helpdesk system email. Must differ from `ADMIN_EMAIL`. |
| `ADMIN_EMAIL` | yes | | Administrator account email. |
| `ADMIN_PASSWORD` | yes | | Admin password (8 characters minimum). |
| `DB_PASSWORD` | yes | | MariaDB user password. |
| `DB_ROOT_PASSWORD` | yes | | MariaDB root password. |
| `OSTICKET_NAME` | no | `Support` | Helpdesk name. |
| `ADMIN_FIRSTNAME` | no | `Admin` | Administrator first name. |
| `ADMIN_LASTNAME` | no | `Support` | Administrator last name. |
| `ADMIN_USERNAME` | no | `ostadmin` | Admin login. Forbidden: `admin`, `osticket`, `username`. |
| `DB_NAME` | no | `osticket` | Database name. |
| `DB_USER` | no | `osticket` | Database user. |
| `TABLE_PREFIX` | no | `ost_` | Must end with `_`. |
| `OSTICKET_TIMEZONE` | no | `Europe/Paris` | Timezone. |
| `OSTICKET_LANG` | no | `en_US` | Install language. |

### After installation

- **French UI.** The interface is in English by default. For French: Admin Panel → Manage → Languages, download the `fr_FR` pack, then set the language.
- **Incoming email.** This image does not include the PHP `imap` extension (the system library was dropped from Debian and the extension is deprecated). IMAP/POP email fetching is therefore off by default. To enable it, uncomment the IMAP block in the `Dockerfile` and rebuild.

### Updating osTicket

The code lives in a persistent volume. Changing `OSTICKET_VERSION` in the `Dockerfile` will not update an already populated volume. Use osTicket's built-in web upgrader, or start from a fresh volume.

---

<div align="center">

Un test de build Docker par **ZénithIA** · A Docker build test by **ZénithIA**

osTicket est une marque de Enhancesoft, distribuée sous licence GPL. Ce dépôt n'est pas affilié au projet osTicket.

</div>
