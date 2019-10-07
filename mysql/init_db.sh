#! /bin/bash

/entrypoint.sh mysqld --datadir=/data/mysql &
time /extra_stuff/wait-for.sh localhost:3306 -t 900
# This is necessary because mysql will restart after loading the database,
# and we want the docker image to capture this post-restart state. So, we will
# need to sleep and then wait for the reboot to complete successfully.
sleep 20
/extra_stuff/wait-for.sh localhost:3306 -t 900
# clean up any remaining database files.
rm /docker-entrypoint-initdb.d/*current*
# Normally, the datadir is /var/lib/mysql but the problem is it is delcared
# as a VOLUME, so persistence is problematic. Specifying datadir=/data/mysql
# means that the database will be physically located in a directory that is not
# a docker VOLUME, and will be immediately available when a user pulls and runs
# the image.
echo -e "[mysqld]\ndatadir=/data/mysql" >> /etc/mysql/my.cnf
