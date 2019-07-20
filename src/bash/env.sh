###
# env.sh: environment variables 
# General config options that could be changed by a human (maybe)

# database path
TIMETRACK_DB_PATH="${TIMETRACK_DB_PATH:-"$TIMETRACK_DBPATH"}"

# timetrack user
TIMETRACK_USER=${TIMETRACK_USER:-$USER}
TIMETRACK_USER=${TIMETRACK_USER:-$(id -g 2>/dev/null || echo -n "tt-user")}

# timetrack project
TIMETRACK_PROJECT="${TIMETRACK_PROJECT:-}"

# sql engine
SQL_ENGINE="${SQL_PATH:-$(which sqlite3 2>/dev/null)}"
SQL_ENGINE="${SQL_ENGINE:-/usr/bin/sqlite3}"

# any necessary parameters.
SQL_PARAMS=""
