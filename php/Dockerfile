FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libzip-dev \
        libicu-dev \
        libonig-dev \
        libcurl4-openssl-dev \
        libssl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        gd \
        mbstring \
        opcache \
        zip \
        intl \
        curl \
        ftp \
    && a2enmod headers \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# curl baut gegen libcurl (libcurl4-openssl-dev) und bringt HTTPS mit.
# Ein "docker-php-ext-configure curl --with-openssl" gibt es nicht – die
# Option gehört zur openssl-Extension und bricht den Build ab.

# Externe Musikquellen (my/remote.php)
#   ftp    → Stream-Wrapper ftp:// ftps:// webdav:// webdavs://
#   curl   → WebDAV via PROPFIND und HTTPS/S3-Downloads
# SMB/CIFS und NFS koennen PHP nicht selbst mounten – dafuer wird der Pfad
# per Bind-Mount durchgereicht (siehe docker-compose.yml).

RUN a2enmod rewrite

# Debian-Apache liefert ein eigenes Alias /icons/ -> /usr/share/apache2/icons.
# Es verdeckt das App-Verzeichnis icons/ (favicon.svg & Co. liefern sonst 404).
RUN a2dismod alias

RUN sed -i 's|AllowOverride None|AllowOverride All|g' /etc/apache2/apache2.conf

WORKDIR /var/www/html
