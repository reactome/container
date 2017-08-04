chown -vR 999:999 /var/log/mysql
chmod 600 /var/log/mysql
owner=$(ls -ld /var/log/mysql | awk 'NR==1 {print $3}')
echo "Owner=" $owner
if ! [[ $owner == 999 || $owner == 'mysql' ]]; then
  # this means that we were not able to set  permissions and ownership properly
  # Logs cannot be created on host if mysql has not got permissions, a copy of previous logs (which were run on previous container start) will reside on host.
  chown -vR 999:999 /backup
  touch /var/log/mysql/error.log
  cp --verbose -r /backup /var/log/mysql
  echo "[mysqld]
log-error   = /backup/error.log
general_log  = /backup/log_output.log" > /etc/mysql/mysql.conf.d/my.cnf
fi