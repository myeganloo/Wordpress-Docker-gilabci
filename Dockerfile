FROM wordpress:php8.1-fpm

ARG ENVIRONMENT

# Install additional PHP extensions, WP-CLI, and ModSecurity dependencies
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libmodsecurity3 \
    libmodsecurity-dev \
    git \
    build-essential \
    libpcre3 \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli pdo pdo_mysql zip \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Install Redis PHP extension
RUN pecl install redis && docker-php-ext-enable redis

# Clone and build ModSecurity-nginx connector
RUN git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity \
    && git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx \
    && wget -O - https://nginx.org/download/nginx-1.21.3.tar.gz | tar zxfv - -C /usr/local/src \
    && cd /usr/local/src/nginx-1.21.3 \
    && ./configure --with-compat --add-dynamic-module=/usr/local/src/ModSecurity-nginx \
    && make modules \
    && cp objs/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/

# Copy custom php.ini
COPY ${PHP_INI} /usr/local/etc/php/conf.d/custom.ini

# Set up wp-content volume
VOLUME /var/www/html/wp-content

# Set proper file permissions
RUN chown -R www-data:www-data /var/www/html && \
    find /var/www/html -type d -exec chmod 755 {} \; && \
    find /var/www/html -type f -exec chmod 644 {} \;

# Add production-specific configurations
RUN if [ "$ENVIRONMENT" = "production" ] ; then \
        echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
        echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini && \
        echo "opcache.interned_strings_buffer=8" >> /usr/local/etc/php/conf.d/opcache.ini && \
        echo "opcache.max_accelerated_files=4000" >> /usr/local/etc/php/conf.d/opcache.ini && \
        echo "opcache.revalidate_freq=60" >> /usr/local/etc/php/conf.d/opcache.ini && \
        echo "opcache.fast_shutdown=1" >> /usr/local/etc/php/conf.d/opcache.ini ; \
    fi

# Copy and set permissions for the install script
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
RUN chmod +x /usr/local/bin/install-plugins.sh

# Set the entrypoint to run our script
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]