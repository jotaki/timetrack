###
# main.sh: usage and invocation

usage() {
    center_text "${ATTR_BOLD}timetrack${ATTR_NORMAL}";
    center_text "${ATTR_CYELLOW}schema version $MIGTO${ATTR_NORMAL}";
    cat <<-EOF

usage: $0 [options] <text>
  -h          print usage and exit

  -s          read <text> from stdin

  -e          use <text> inserted text from \$EDITOR ($EDITOR)

  -M          migrate scehma from version $MIGFROM to version $MIGTO
              Only use this option if you are informed to do so.

  -r          show report (equivalent to $0 -q _tasks)

  -q          equivalent to select * from <text>;
              useful views: _tasks, _projects, _tags,
              active_tasks, active_projects

  -t task     create <text> as task description for task
              switches current task to specified task
              environment variable: TIMETRACK_TASK ($TIMETRACK_TASK)

  -T tag(s)   a comma separated list of tags ($TIMETRACK_TAGS)
              environment variable: TIMETRACK_TAGS

  -p name     set project name to name ($TIMETRACK_PROJECT)
              environment variable: TIMETRACK_PROJECT

  -u name     set username to name ($TIMETRACK_USER)
              environment variable: TIMETRACK_USER

  -d path     set database file path to path ($TIMETRACK_DB_PATH)
              environment variable: TIMETRACK_DB_PATH

  -z          mark all active tasks in project (-p) to inactive.
              the project is also marked as inactive.

  command line options override environment settings.

    for most tasks TIMETRACK_PROJECT (-p) cannot be blank.
    TIMETRACK_USER defaults to \$USER ($USER), id -g ($(id -g)), or 'tt-user'
    TIMETRACK_TAGS defaults to an empty string

  see timetrack(1) for more details.
EOF
}

app="$(basename "$0")";
use_stdin=0
runmode='updateproject'
while getopts d:hMp:rst:T:u: opt; do
    case "$opt" in
        d) TIMETRACK_DB_PATH="$OPTARG" ;;
        e) use_stdin=2 ;;
        h) usage "$app"; exit 0 ;;
        M) runmode='migration' ;;
        p) TIMETRACK_PROJECT="$OPTARG" ;;
        q) runmode='query' ;;
        r) runmode='showreport' ;;
        s) use_stdin=1 ;;
        t) TIMETRACK_TASK="$OPTARG";
           runmode='addtask' ;;
        T) TIMETRACK_TAGS="$OPTARG" ;;
        u) TIMETRACK_USER="$OPTARG" ;;
        ?) usage "$app"; exit 1 ;;
    esac
done
shift $(($OPTIND - 1))

TIMETRACK_PROJECT="$(sqlsanitize "$TIMETRACK_PROJECT")"
TIMETRACK_USER="$(sqlsanitize "$TIMETRACK_USER")"
TIMETRACK_TAGS="$(sqlsanitize "$TIMETRACK_TAGS")"
TIMETRACK_TASK="$(sqlsanitize "$TIMETRACK_TASK")"

chkdb || exit 1;
test "$runmode" = "migration" || sqlchkversion || exit 1;
eval $runmode "$*"

test -n "$TIMETRACK_PROJECT" || exit 0;

if [ $use_stdin -eq 1 -a -n "$TIMETRACK_PROJECT" ]; then
    echo "enter brief description. send EOF (press Ctrl-D) when done."
    while read -p '> ' line; do activity="${activity} ${line}"; done
    unset line
fi

if [ -z "$*" -a $use_stdin -ne 1 ]; then
    usage "$app"
    exit 1
fi

activity="$(sqlsanitize "${activity:-$*}")"

if [ -z "$activity" -o -z "$TIMETRACK_USER" -o -z "$TIMETRACK_PROJECT" ]; then
    usage "$app"
    exit 1
fi

chkdb || exit 1

sqlchkversion || exit 1

cmsg -n status: "updating table ..."
trackit "$TIMETRACK_USER" "$TIMETRACK_PROJECT" "$activity"
chkfail || exit 1
