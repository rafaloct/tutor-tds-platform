# Finalize an already built candidate from a private (umask 077) checkout.
# Record/verify BASE_IMAGE's immutable ID before invoking this one-time layer.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
RUN chmod -R a+rX,go-w /var/www/html \
 && chmod 0755 /var/www/html \
 && chmod 0444 /var/www/html/web/sites/default/settings.php
USER www-data
RUN test -r /var/www/html/web/index.php \
 && test -r /var/www/html/vendor/autoload.php \
 && test -r /var/www/html/web/modules/custom/tds_health/tds_health.info.yml \
 && test -r /var/www/html/web/sites/default/settings.php
USER root
