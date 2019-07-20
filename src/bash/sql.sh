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

showreport() {
    sqlblock -column -header <<< "select * from timereport;";
}

sqlsanitize(){ [ ! -z "$1" ] && sed s:\':\\\\\':g <<< "$1";}
