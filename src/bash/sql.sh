###
# sql.sh: wrapper code for sql

sqlblock(){ $SQL_ENGINE $SQL_PARAMS $* "$TIMETRACK_DB_PATH" 2>/dev/null;}

initdb() {
    sqlblock <<- EOF 2>/dev/null
<SQL.INIT>
EOF
}

trackit() {
    sqlblock <<- EOF 2>/dev/null
        insert into timekeep (username, projectname, activity) values
            ('$1', '$2', '$3');
EOF
}

sqlsanitize(){ test -z "$1" || sed -e s/\'/\&\&/g <<< "$1";}

getversion() {
    local version=$(sqlblock <<< "select version from ttmetas;");
    echo "${version:-0}"
}

chkdb() {
    if ! test -f "$TIMETRACK_DB_PATH"; then
        echo -n "$TIMETRACK_DB_PATH does not exist, attempting to create it ... ";
        tput cuf 1 2>/dev/null
        initdb
        chkfail || return $?;
    fi

    return 0;
}
