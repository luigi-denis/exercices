# 🐳 WordPress avec Docker (nginx + MariaDB + PHP)

Projet réalisé dans le cadre de l'exercice 03 : déploiement d'un site WordPress via Docker Compose, en utilisant les images nginx, mariadb et php (php-fpm).

## 📋 Prérequis

- Docker installé
- Docker Compose installé

Vérification :
```bash
docker --version
docker compose version
```

## 📂 Structure du projet

```
wordpress-docker/
├── docker-compose.yaml   # Orchestration des 3 services
├── default.conf          # Configuration nginx
├── php/
│   └── Dockerfile        # Image PHP custom
└── README.md             # Ce fichier
```

## ⚙️ Les services

| Service | Image | Rôle |
|---------|-------|------|
| mariadb | mariadb:latest | Base de données |
| php | php:8.2-fpm-custom (build local) | PHP-FPM |
| nginx | nginx:latest | Serveur web (port 8080) |

> **Volume commun** : `wp_data` est partagé entre nginx et php pour les fichiers WordPress.

## 🌐 Accès au site

Ouvrir un navigateur sur : **http://localhost:8080**

L'assistant d'installation de WordPress s'affiche. Suivre les étapes : choix de la langue, titre du site, création du compte administrateur.

## 🔧 Configuration

### Base de données (MariaDB)

| Paramètre | Valeur |
|-----------|--------|
| Base de données | wordpress |
| Utilisateur | wpuser |
| Mot de passe | wppass |
| Mot de passe root | rootpass |

### Serveur web (nginx)

- Écoute sur le **port 80** dans le conteneur, mappé sur le **port 8080** de l'hôte.
- Transmet les requêtes PHP au service **php via php-fpm sur le port 9000**.

## 📁 Détail des fichiers de configuration

### docker-compose.yaml

Définit et orchestre les 3 services :

- **mariadb** : utilise l'image `mariadb:latest`. Les variables d'environnement définissent le nom de la base, l'utilisateur et les mots de passe. Les données sont stockées dans le volume `wp_data:/var/lib/mysql`.
- **php** : construit une image locale depuis `./php/Dockerfile`, taguée `php:8.2-fpm-custom`. Ce service dépend de `mariadb` et partage le volume `wp_data:/var/www/html` avec nginx pour exposer les fichiers WordPress.
- **nginx** : utilise l'image `nginx:latest`. Dépend de `php`. Expose le port 8080 de l'hôte vers le port 80 du conteneur. Monte le fichier `./default.conf` comme configuration et partage le volume `wp_data:/var/www/html`.

Un volume nommé `wp_data` est déclaré et partagé entre les services `php` et `nginx`.

### default.conf

Fichier de configuration nginx :

- Le serveur écoute sur le port **80**, avec `localhost` comme `server_name`.
- Les requêtes vers des fichiers inexistants sont redirigées vers `index.php` via `try_files` (nécessaire au routage WordPress).
- Les fichiers `.php` sont transmis au service **php** sur le port **9000**.

### Dockerfile (`./php/Dockerfile`)

Construit l'image PHP custom :

1. Basé sur l'image officielle `php:8.2-fpm`.
2. Installe les extensions PHP `mysqli`, `pdo` et `pdo_mysql`, nécessaires à la communication entre WordPress et MariaDB.
3. Télécharge la dernière version de WordPress depuis `wordpress.org`, la décompresse dans `/var/www/html`, supprime les fichiers temporaires, puis attribue les droits au user `www-data`.

## 📸 Captures d'écran

> Ajouter ici les captures d'écran de :
> - `docker compose ps` (liste des conteneurs actifs)
> - La page d'installation de WordPress
> - Le site WordPress fonctionnel

## 📝 Notes

- Les mots de passe sont en clair dans le `docker-compose.yaml` pour les besoins de l'exercice. En production, utiliser un fichier `.env` ou un gestionnaire de secrets.
- WordPress est téléchargé depuis `wordpress.org` lors du build de l'image `php`, pas depuis une image Docker officielle WordPress.
