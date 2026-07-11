#!/bin/sh
set -e

WEBROOT=/var/www/html
SRC=/usr/src/osticket
PREFIX="${TABLE_PREFIX:-ost_}"

# 1) Premier boot : on seme osTicket dans le webroot persistant (volume Coolify)
if [ ! -f "$WEBROOT/main.inc.php" ]; then
  echo "[entrypoint] Premier boot, copie d'osTicket dans $WEBROOT ..."
  cp -a "$SRC/." "$WEBROOT/"
fi

# 2) Attente de la base de donnees
echo "[entrypoint] Attente de la base ($DB_HOST) ..."
tries=0
until php -r '$c=@mysqli_connect(getenv("DB_HOST"),getenv("DB_USER"),getenv("DB_PASSWORD"),getenv("DB_NAME")); exit($c?0:1);' >/dev/null 2>&1; do
  tries=$((tries + 1))
  if [ "$tries" -ge 60 ]; then
    echo "[entrypoint] Base injoignable apres 120s, on continue sans installer."
    break
  fi
  sleep 2
done

# 3) Installation headless si pas deja installe
do_harden=0
if [ -f "$WEBROOT/setup/ost-autoinstall.php" ]; then
  already=$(php -r '
    $c=@mysqli_connect(getenv("DB_HOST"),getenv("DB_USER"),getenv("DB_PASSWORD"),getenv("DB_NAME"));
    if(!$c){echo "err";exit;}
    $p=getenv("TABLE_PREFIX")?:"ost_";
    $r=mysqli_query($c,"SHOW TABLES LIKE \x27".$p."config\x27");
    echo ($r && mysqli_num_rows($r)>0)?"yes":"no";
  ' 2>/dev/null)

  if [ "$already" = "yes" ]; then
    echo "[entrypoint] osTicket deja installe, on saute l'install."
    do_harden=1
  elif [ "$already" = "no" ]; then
    echo "[entrypoint] Installation headless en cours ..."
    if ( cd "$WEBROOT/setup" && php ost-autoinstall.php ); then
      do_harden=1
    else
      echo "[entrypoint] Install ECHOUEE, on garde setup/ pour reessayer/manuel."
    fi
  else
    echo "[entrypoint] Etat d'install indetermine (base KO), on garde setup/."
  fi

  # 4) Auto-durcissement (exigence osTicket) : supprimer setup/, verrouiller config
  if [ "$do_harden" = "1" ]; then
    echo "[entrypoint] Durcissement : suppression de setup/ et chmod 644 de la config."
    rm -rf "$WEBROOT/setup"
    [ -f "$WEBROOT/include/ost-config.php" ] && chmod 0644 "$WEBROOT/include/ost-config.php"
  fi
fi

# 5) Permissions + lancement d'Apache
chown -R www-data:www-data "$WEBROOT"
exec "$@"
