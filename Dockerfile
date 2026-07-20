FROM php:8.2-apache

# --- Extensions PHP requises par osTicket ---
# mysqli, gd, intl, mbstring, opcache, zip.
# imap est volontairement EXCLU : la lib uw-imap (libc-client) a ete retiree
# de Debian bookworm et l'extension est depreciee en PHP 8.1+. Elle casserait
# le build. Elle ne sert qu'au fetch d'email par IMAP/POP. Pour l'activer, voir
# le bloc commente plus bas et le README.
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl unzip \
      libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
      libicu-dev libonig-dev libzip-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" mysqli gd intl mbstring opcache zip \
  && a2enmod rewrite \
  && rm -rf /var/lib/apt/lists/*

# --- (Optionnel) Activer IMAP pour le fetch d'email ---
# Decommente ce bloc SI tu en as besoin. Peut echouer selon la dispo de la lib.
# RUN apt-get update && apt-get install -y --no-install-recommends libc-client-dev libkrb5-dev \
#   && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
#   && docker-php-ext-install imap \
#   && rm -rf /var/lib/apt/lists/*

# --- Reglages PHP recommandes + journalisation des erreurs ---
# display_errors=Off (securite) mais log_errors=On : les fatals PHP partent dans
# le log d'erreur Apache, qu'on redirige vers stderr juste apres. Resultat : la
# vraie cause d'un 500 apparait dans les logs du conteneur (onglet Logs Coolify).
RUN { \
      echo 'upload_max_filesize=25M'; \
      echo 'post_max_size=30M'; \
      echo 'memory_limit=256M'; \
      echo 'max_execution_time=60'; \
      echo 'log_errors=On'; \
      echo 'display_errors=Off'; \
      echo 'error_reporting=E_ALL & ~E_DEPRECATED & ~E_NOTICE'; \
    } > /usr/local/etc/php/conf.d/osticket.ini

# Rediriger les logs Apache (acces + erreurs) vers stdout/stderr du conteneur,
# sinon ils restent dans /var/log/apache2/ et n'apparaissent nulle part.
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
  && ln -sf /dev/stderr /var/log/apache2/error.log

# --- Recuperation d'osTicket (release packagee officielle) ---
ARG OSTICKET_VERSION=1.18.4
RUN curl -fsSL -o /tmp/osticket.zip \
      "https://github.com/osTicket/osTicket/releases/download/v${OSTICKET_VERSION}/osTicket-v${OSTICKET_VERSION}.zip" \
  && unzip -q /tmp/osticket.zip -d /tmp/ost \
  && mkdir -p /usr/src/osticket \
  && cp -a /tmp/ost/upload/. /usr/src/osticket/ \
  && cp /usr/src/osticket/include/ost-sampleconfig.php /usr/src/osticket/include/ost-config.php \
  && rm -rf /tmp/osticket.zip /tmp/ost

# --- Recap de build (visible dans les logs de deploiement Coolify) ---
# Confirme que l'image est saine : version PHP, version osTicket, extensions.
RUN echo "=========== RECAP BUILD osTicket ===========" \
  && php -v | head -n1 \
  && echo "osTicket version : ${OSTICKET_VERSION}" \
  && printf 'Extensions requises : ' \
  && for e in mysqli gd intl mbstring zip opcache; do \
       if php -r "exit(extension_loaded('$e')?0:1);"; then printf '%s(ok) ' "$e"; else printf '%s(MANQUANT) ' "$e"; fi; \
     done \
  && echo \
  && echo "============================================"

# Script d'install headless, place dans le dossier setup/ d'osTicket
COPY ost-autoinstall.php /usr/src/osticket/setup/ost-autoinstall.php

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
