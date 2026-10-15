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
    && docker-php-ext-configure curl --with-openssl \
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

# Externe Musikquellen (my/remote.php)
#   ftp    → Stream-Wrapper ftp:// ftps:// webdav:// webdavs://
#   curl   → WebDAV via PROPFIND und HTTPS/S3-Downloads
# SMB/CIFS und NFS koennen PHP nicht selbst mounten – dafuer wird der Pfad
# per Bind-Mount durchgereicht (siehe docker-compose.yml).

RUN a2enmod rewrite

RUN sed -i 's|AllowOverride None|AllowOverride All|g' /etc/apache2/apache2.conf

WORKDIR /var/www/html
