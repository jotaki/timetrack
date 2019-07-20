# cleanup.sh: unset variables and functions
# used for debugging purposes.

unset -v TIMETRACK_DB_PATH TIMETRACK_USER TIMETRACK_PROJECT
unset -v SQL_ENGINE SQL_PARAMS
unset -f sqlblock initdb trackit sqlsanitize
