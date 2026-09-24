#!/bin/sh
set -eu

: "${APP_ALB_DNS:?APP_ALB_DNS must be set}"

sed "s#__APP_ALB_DNS__#${APP_ALB_DNS}#g" \
  /etc/nginx/templates/nginx.conf.template > /tmp/nginx.conf

exec nginx -c /tmp/nginx.conf -g 'daemon off;'
