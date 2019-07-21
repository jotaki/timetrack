###
# main.sh: usage and invocation

usage() {
    cat <<-EOF
usage: $0 [options] <activity description>
  -h          print usage and exit

  -s          read <activity description> from stdin

  -r          show report

  -p name     set project name to name ($TIMETRACK_PROJECT)
              environment variable: TIMETRACK_PROJECT

  -u name     set username to name ($TIMETRACK_USER)
              environment variable: TIMETRACK_USER

  -d path     set database file path to path ($TIMETRACK_DB_PATH)
              environment variable: TIMETRACK_DB_PATH

  command line options override environment settings.

  <activity description> should be a breif description of what you
  are working on for a given project.

    TIMETRACK_PROJECT (-p) cannot be blank.
    TIMETRACK_USER defaults to \$USER ($USER), id -g ($(id -g)), or 'tt-user'
EOF
}

app="$(basename "$0")";
use_stdin=0
while getopts d:hp:ru:s opt; do
    case "$opt" in
        d) TIMETRACK_DB_PATH="$OPTARG" ;;
        h) usage "$app"; exit 0 ;;
        p) TIMETRACK_PROJECT="$OPTARG" ;;
        r) sqlchkversion && showreport; exit 0 ;;
        u) TIMETRACK_USER="$OPTARG" ;;
        s) use_stdin=1 ;;
        ?) usage "$app"; exit 1 ;;
    esac
done

TIMETRACK_PROJECT="$(sqlsanitize "$TIMETRACK_PROJECT")"
TIMETRACK_USER="$(sqlsanitize "$TIMETRACK_USER")"

if [ $use_stdin -eq 1 -a ! -z "$TIMETRACK_PROJECT" ]; then
    echo "enter brief description. send EOF (press Ctrl-D) when done."
    while read -p '> ' line; do activity="${activity} ${line}"; done
    unset line
fi

shift $(($OPTIND - 1))
if [ -z "$*" -a $use_stdin -ne 1 ]; then
    usage "$app"
    exit 1
fi

activity="$(sqlsanitize "${activity:-$*}")"

if [ -z "$activity" -o -z "$TIMETRACK_USER" -o -z "$TIMETRACK_PROJECT" ]; then
    usage "$app"
    exit 1
fi

if [ ! -f "$TIMETRACK_DB_PATH" ]; then
    echo -n "$TIMETRACK_DB_PATH does not exist, attempting to create it ... "
    initdb
    chkfail || exit 1
fi

sqlchkversion || exit 1

cmsg -n status: "updating table ..."
trackit "$TIMETRACK_USER" "$TIMETRACK_PROJECT" "$activity"
chkfail || exit 1
