#! /bin/bash
# build.sh: script concatter

# don't have spaces. order matters.
sources=(
    bash/header.sh
    bash/env.sh
    bash/misc.sh
    bash/colors.sh
    bash/sql.sh
    bash/sqlmig.sh
    bash/runmodes.sh
    bash/main.sh
)

output=timetrack.sh

## script

chkstatus(){
    if [ $? -eq 0 ]; then
        echo "ok";
    else
        echo "fail";
        rm -f "$output" "$tmpfile"
        exit 1
    fi
}
:(){ echo -n "$1 ... ";shift;eval "$@" 2>/dev/null;chkstatus;};

: 'Removing old script' \rm  -f "$output"
: 'Creating new script' \cat ${sources[@]} "> '$output'"

echo -n 'Injecting init sql ... '
\sed -i -e '/<SQL.INIT>/{
    s/<SQL.INIT>//g
    r sql/new.sql
}' "$output"
chkstatus
echo -n 'Injecting migration sql ... '
\sed -i -e '/<SQL.MIGRATE>/{
    s/<SQL.MIGRATE//g
    r sql/migration.sql
}' "$output"
chkstatus

: 'Ensuring executable' \chmod +x "$output"
echo '"Build" completed.'
