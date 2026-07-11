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

# --- Reglages PHP recommandes ---
RUN { \
      echo 'upload_max_filesize=25M'; \
      echo 'post_max_size=30M'; \
      echo 'memory_limit=256M'; \
      echo 'max_execution_time=60'; \
    } > /usr/local/etc/php/conf.d/osticket.ini

# --- Recuperation d'osTicket (release packagee officielle) ---
ARG OSTICKET_VERSION=1.18.4
RUN curl -fsSL -o /tmp/osticket.zip \
      "https://github.com/osTicket/osTicket/releases/download/v${OSTICKET_VERSION}/osTicket-v${OSTICKET_VERSION}.zip" \
  && unzip -q /tmp/osticket.zip -d /tmp/ost \
  && mkdir -p /usr/src/osticket \
  && cp -a /tmp/ost/upload/. /usr/src/osticket/ \
  && cp /usr/src/osticket/include/ost-sampleconfig.php /usr/src/osticket/include/ost-config.php \
  && rm -rf /tmp/osticket.zip /tmp/ost

# Script d'install headless, place dans le dossier setup/ d'osTicket
COPY ost-autoinstall.php /usr/src/osticket/setup/ost-autoinstall.php

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
