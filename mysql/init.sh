chown -vR 999:999 /var/log/mysql
owner=$(ls -ld /var/log/mysql | awk 'NR==1 {print $3}')
echo "Owner=" $owner
log_location="/var/log/mysql"
if ! [[ $owner == 999 || $owner == 'mysql' ]]; then
  # this means that we were not able to set  permissions and ownership properly
  # Logs cannot be created on host if mysql has not got permissions, a copy of previous logs (which were run on previous container start) will reside on host.
  chown -vR 999:999 /backup
  touch /var/log/mysql/error.log
  cp --verbose -r /backup /var/log/mysql
  log_location="/backup"
fi
# Write own configurations
# general_log_file is large, and to prevent logs to eat up disk space, it has been turned off
# The general_log and slow_query_log can be turned on by replacing 0 by 1
echo "[mysqld]
log-error          = $log_location/error.log
general_log        = 0
general_log_file   = $log_location/log_output.log
slow_query_log     = 0
slow_query_log_file= $log_location/slow_query.log
" > /etc/mysql/mysql.conf.d/my.cnf
