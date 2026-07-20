#!/bin/sh
set -e

WEBROOT=/var/www/html
SRC=/usr/src/osticket
PREFIX="${TABLE_PREFIX:-ost_}"

log() { echo "[entrypoint] $*"; }

# --- 1) Premier boot : on seme osTicket dans le webroot persistant ---
if [ ! -f "$WEBROOT/main.inc.php" ]; then
  log "Premier boot, copie d'osTicket dans $WEBROOT ..."
  cp -a "$SRC/." "$WEBROOT/"
fi

# --- Snapshot de demarrage (baseline de diagnostic dans les logs) ---
log "PHP $(php -r 'echo PHP_VERSION;' 2>/dev/null) | webroot=$WEBROOT | cible base: host=$DB_HOST db=$DB_NAME user=$DB_USER prefix=$PREFIX"
missing=""
for e in mysqli gd intl mbstring zip opcache; do
  php -r "exit(extension_loaded('$e')?0:1);" 2>/dev/null || missing="$missing $e"
done
if [ -n "$missing" ]; then
  log "ATTENTION : extensions PHP manquantes :$missing"
else
  log "Extensions PHP requises : toutes presentes."
fi

# --- 2) Connexion a la base (on distingue "pas encore prete" de "mot de passe faux") ---
db_ok=0
db_error=""
i=0
log "Connexion a la base ($DB_HOST) ..."
while [ "$i" -lt 60 ]; do
  if out=$(php -r '
        $c = @mysqli_connect(getenv("DB_HOST"), getenv("DB_USER"), getenv("DB_PASSWORD"), getenv("DB_NAME"));
        if ($c) { echo "OK"; exit(0); }
        echo mysqli_connect_error();
        exit(1);
      ' 2>/dev/null); then
    db_ok=1
    break
  fi
  db_error="$out"
  # Inutile d'attendre 2 min si les identifiants sont refuses : ca ne changera pas.
  case "$db_error" in
    *"Access denied"*) break ;;
  esac
  i=$((i + 1))
  sleep 2
done

if [ "$db_ok" != "1" ]; then
  echo "================================================================"
  log "ERREUR : impossible de se connecter a la base de donnees."
  log "Detail : $db_error"
  case "$db_error" in
    *"Access denied"*)
      log ""
      log "CAUSE LA PLUS PROBABLE : le volume de la base vient d'un"
      log "deploiement precedent, avec un AUTRE mot de passe."
      log "MariaDB ne cree l'utilisateur et son mot de passe qu'au tout"
      log "premier demarrage sur un volume vide. Ensuite, la variable"
      log "MARIADB_PASSWORD est IGNOREE : la base garde l'ancien mot de passe."
      log ""
      log "SOLUTION : supprime l'application ET ses volumes (osticket_db"
      log "en particulier), puis redeploie. Supprimer l'application seule"
      log "ne suffit pas, Coolify conserve les volumes."
      ;;
    *)
      log "Verifie que le service 'db' demarre bien (logs du conteneur db)."
      ;;
  esac
  echo "================================================================"
  log "Apache demarre quand meme, mais osTicket renverra une erreur 500."
  chown -R www-data:www-data "$WEBROOT"
  exec "$@"
fi

log "Base joignable."

# --- 3) osTicket est-il deja installe ? (on interroge la base, pas des fichiers) ---
tables=$(php -r '
  $c = @mysqli_connect(getenv("DB_HOST"), getenv("DB_USER"), getenv("DB_PASSWORD"), getenv("DB_NAME"));
  if (!$c) { echo "err"; exit; }
  $p = getenv("TABLE_PREFIX") ?: "ost_";
  $r = mysqli_query($c, "SHOW TABLES LIKE \x27" . $p . "config\x27");
  echo ($r && mysqli_num_rows($r) > 0) ? "yes" : "no";
' 2>/dev/null)

if [ "$tables" = "no" ]; then
  # Base vide -> (re)installation. Voie de secours : si setup/ a deja ete
  # supprime par un boot precedent, on le restaure depuis l'image.
  log "Base joignable mais vide, lancement de l'installation."
  if [ ! -d "$WEBROOT/setup" ]; then
    log "Restauration de setup/ depuis l'image (voie de secours)."
    cp -a "$SRC/setup" "$WEBROOT/setup"
  fi
  # On repart d'une config vierge et inscriptible
  cp "$SRC/include/ost-sampleconfig.php" "$WEBROOT/include/ost-config.php"
  chmod 0666 "$WEBROOT/include/ost-config.php"

  if ( cd "$WEBROOT/setup" && php ost-autoinstall.php ); then
    log "Installation reussie. Durcissement : suppression de setup/, config en 644."
    rm -rf "$WEBROOT/setup"
    chmod 0644 "$WEBROOT/include/ost-config.php"
  else
    log "Installation ECHOUEE (voir les lignes [autoinstall] ci-dessus)."
    log "setup/ est conserve pour permettre une reprise."
  fi

elif [ "$tables" = "yes" ]; then
  log "osTicket est deja installe."
  # Garde-fou : base peuplee mais config vierge = volumes desynchronises
  if ! grep -q "$DB_NAME" "$WEBROOT/include/ost-config.php" 2>/dev/null; then
    echo "================================================================"
    log "ATTENTION : la base contient deja des tables, mais le fichier de"
    log "config du webroot semble vierge. Les deux volumes sont desynchronises"
    log "(volume applicatif recree et volume base conserve, ou l'inverse)."
    log "SOLUTION : supprime l'application ET ses deux volumes, puis redeploie."
    echo "================================================================"
  fi
  # Durcissement idempotent
  if [ -d "$WEBROOT/setup" ]; then
    log "Durcissement : suppression de setup/."
    rm -rf "$WEBROOT/setup"
  fi
  [ -f "$WEBROOT/include/ost-config.php" ] && chmod 0644 "$WEBROOT/include/ost-config.php"

else
  log "Etat d'installation indetermine, on ne touche a rien."
fi

# --- 4) Permissions + lancement d'Apache ---
chown -R www-data:www-data "$WEBROOT"
exec "$@"
