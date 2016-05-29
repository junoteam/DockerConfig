#! /bin/bash

set -e
git --work-tree=/var/upods_api/flask_project --git-dir=/var/upods_api/flask_project/.git pull origin master
exec /usr/bin/supervisord --nodaemon -c /etc/supervisor/supervisord.conf