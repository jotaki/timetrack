###
# sqlmig.sh: sql migration

MIGFROM=0
MIGTO=1
sqlmigrate() {
    sqlblock <<- EOF 2>/dev/null
<SQL.MIGRATE>
EOF
}

chkversion(){ test $(getversion) -eq $MIGTO;}

sqlbackup() {
    local v="sv$(getversion)" dbpath="$TIMETRACK_DB_PATH"
    local bkup_path="${dbpath}.${v}.$(date +%s)" bkup=

    cmsg backup: "please enter backup path"
    read -p "[${ATTR_BOLD}${ATTR_CCYAN}$bkup_path${ATTR_NORMAL}] " bkup
    test -z "$bkup" || bkup_path="$bkup"
    cmsg backup:; cp -v "$dbpath" "$bkup_path" || return $?

    cmsg backup: "performing integrity check"

    ansi_yellow
    sha512sum "$dbpath" "$bkup_path" | tee "$bkup_path.sha" | \
        sed -E 's/^(.{24}).{80}(.{24}) *(.*)$/\1...\2    \3/g' | \
        sed -e s/.*/${ATTR_NHILITE}backup:\ ${ATTR_NORMAL}${ATTR_CYELLOW}\&/
    ansi_normal

    sha512sum -c "$bkup_path.sha" 2>/dev/null | \
        sed -e s/.*/${ATTR_NHILITE}backup:\ ${ATTR_NORMAL}\&/ \
            -e s/OK/${ATTR_CGREEN}\&${ATTR_NORMAL}/ \
            -e s/FAILED/${ATTR_CRED}\&${ATTR_NORMAL}/

    v=$(sed -E 's/^(.{128}).*$/\1/' "$bkup_path.sha" | uniq | wc -l)

    cmsg -n backup: "verifying..."
    test "$v" -eq 1
    chkfail
}

sqlchkversion() {
    chkversion && return $?

    cwarn warning: "schema version mismatch, please use -M to migrate"
    cwarn warning: "expected schema version $MIGTO, got version $(getversion)\n"
    cwarn warning: "timetrack will attempt to do the intended task, but"
    cwarn warning: "the results may be undefined. For this reason it is"
    cwarn warning: "recommended that you make a backup before performing"
    cwarn warning: "the intended task.\n"

    cmsg -n question: "Would you like to create a backup? "
    if ! chkyninput y; then
        cwarn warning: "timetrack was informed not to make a backup"
        cwarn warning: "${ATTR_EHILITE}YOU HAVE BEEN WARNED !!!${ATTR_NORMAL}"
    elif ! sqlbackup; then
        cerr error: "unable to create backup, aborting."
        return 1
    fi

    return 0
}
