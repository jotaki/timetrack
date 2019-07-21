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
