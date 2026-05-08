#!/bin/sh

set -e

cd /var/www/localhost

mkdir -p data/cache data/logs data/migrations upload/files upload/thumbnails /var/spool/cron/crontabs
chown -R www-data:www-data data upload public

if [ ! -f data/config.php ]; then
  su -s /bin/sh www-data -c "php .docker/php/scripts/init-config.php --bootstrap"
fi

su -s /bin/sh www-data -c "php .docker/php/scripts/init-config.php"

if [ ! -d public/client ]; then
  su -s /bin/sh www-data -c "php -r 'require \"vendor/autoload.php\"; \Atro\Composer\PostUpdate::postUpdate();'"
fi

cat > /tmp/www-data-cron <<'EOF'
* * * * * cd /var/www/localhost && /usr/local/bin/php console.php cron >> data/logs/docker-cron.log 2>&1
EOF
crontab -u www-data /tmp/www-data-cron
rm /tmp/www-data-cron

cron
apache2-foreground
