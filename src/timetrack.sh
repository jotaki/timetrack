#! /bin/bash
# timetrack.sh: time tracking

# Default database path (you should not need to change this.)
TIMETRACK_DBPATH="$HOME/.timetrackdb"

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
###
# misc.sh: miscellaneous functions

# default=$1
chkyninput() {
    local b=$ATTR_BOLD n=$ATTR_NORMAL
    local answer=$(tr [YN] [yn] <<< "$1") msg="[${b}Y${n}/n]"
    test "$answer" = "y" || msg="[y/${b}N${n}]"

    echo -n " $msg "
    builtin read -N 1 answer
    echo

    answer="$(tr [YN] [yn] <<< "$answer")"
    test "${answer:-$1}" = "$1"
}
###
# colors.sh: support for colors

ctransform(){ echo -en "$*" | tr a-z A-Z; }
cmsgwrap() {
    local ansi="$1" prefix="$2" opt="-e"
    test "$prefix" = "-n" && shift && opt="-en" && prefix="$2"
    prefix="$(ctransform "$prefix")"
    shift 2
    echo $opt "${ansi}${prefix}${ATTR_NORMAL} $*"
}

cerr(){ cmsgwrap $ATTR_EHILITE $*; }
cwarn(){ cmsgwrap $ATTR_WHILITE $*; }
cmsg(){ cmsgwrap $ATTR_NHILITE $*; }

chkfail() {
    local rc=$?
    test $rc -eq 0 && cmsg "ok" || cerr "failed"
    return $rc
}

# yes, I know the correct spelling is highlight.
ATTR_EHILITE=""
ATTR_WHILITE=""
ATTR_NHILITE=""

ATTR_CBLACK=""
ATTR_CRED=""
ATTR_CGREEN=""
ATTR_CYELLOW=""
ATTR_CBLUE=""
ATTR_CMAGENTA=""
ATTR_CCYAN=""
ATTR_CWHITE=""
ATTR_NORMAL=""
ATTR_BOLD=""

ansi_bold(){ echo -en "${ATTR_BOLD}";}
ansi_red(){ echo -en "${ATTR_CRED}";}
ansi_green(){ echo -en "${ATTR_CGREEN}";}
ansi_red(){ echo -en "${ATTR_CRED}";}
ansi_green(){ echo -en "${ATTR_CGREEN}";}
ansi_yellow(){ echo -en "${ATTR_CYELLOW}";}
ansi_blue(){ echo -en "${ATTR_CBLUE}";}
ansi_magenta(){ echo -en "${ATTR_CMAGENTA}";}
ansi_cyan(){ echo -en "${ATTR_CCYAN}";}
ansi_white(){ echo -en "${ATTR_CWHITE}";}
ansi_normal(){ echo -en "${ATTR_NORMAL}";}

# call this function to enable color support.
enable_color_support(){
    test -t 1 || return $?
    test -x "$(which tput)" || return $?
    local colors=$(tput colors)
    test "${colors:-0}" -ge 8 || return $?

    # see terminfo(5)
    ATTR_BOLD="$(tput bold)"
    ATTR_NORMAL="$(tput sgr0)"  # exit_attribute_mode
    ATTR_CBLACK="$(tput setaf 0)"
    ATTR_CRED="$(tput setaf 1)"       # blue?
    ATTR_CGREEN="$(tput setaf 2)"
    ATTR_CYELLOW="$(tput setaf 3)"    # cyan?
    ATTR_CBLUE="$(tput setaf 4)"      # red?
    ATTR_CMAGENTA="$(tput setaf 5)"
    ATTR_CCYAN="$(tput setaf 6)"      # yellow?
    ATTR_CWHITE="$(tput setaf 7)"

    ATTR_EHILITE="${ATTR_BOLD}${ATTR_CRED}"
    ATTR_WHILITE="${ATTR_BOLD}${ATTR_CYELLOW}"
    ATTR_NHILITE="${ATTR_BOLD}${ATTR_CGREEN}"

    # redefine ctransform
    unset -f ctransform
    ctransform(){ echo -en "$*";}
}

# called now.
enable_color_support
###
# sql.sh: wrapper code for sql

sqlblock(){ $SQL_ENGINE $SQL_PARAMS $* "$TIMETRACK_DB_PATH" 2>/dev/null;}

initdb() {
    sqlblock <<- EOF 2>/dev/null

/*
table structure:

|users  |  |projects |  |timekeepings                                      |
|id|name|  |id|name  |  |id|project_id|user_id|activity|start_time|end_time|
 ^^     ^^--------------^^     ^^
  \\----------------------------------//
*/

-- create tables --

-- users table, this is probably pointless as timetrack intends to be a one-user database.
create table if not exists users (
    id integer primary key autoincrement,
    name varchar(255) not null unique,
    created_at datetime not null default current_timestamp
);

-- projects table
create table if not exists projects (
    id integer primary key autoincrement,
    name varchar(255) not null unique,
    created_at datetime not null default current_timestamp
);

-- actual time keeping table
create table if not exists timekeepings (
    id integer primary key autoincrement,
    project_id integer not null,
    user_id integer not null,
    activity varchar(255) not null,
    start_time datetime not null default current_timestamp,
    end_time datetime not null default 0,

    -- foreign key references
    foreign key(project_id) references projects(id),
    foreign key(user_id) references users(id)
);

-- meta data table
-- this table is used to deal with any migration issues.
create table if not exists ttmetas (
    id integer primary key autoincrement,
    version integer not null default 1,
    reserved blob
);

-- create views. --

create view if not exists timekeep (projectname, username, activity) as
    select p.name, u.name, tk.activity from
        timekeepings tk, users u, projects p
        where
            tk.project_id = p.id and
            tk.user_id = u.id;

create view if not exists timereport (projectname, username, activity, 
                                  timedays, timehours, timeminutes, timeseconds) as
    select p.name, u.name, tk.activity,
        cast ((julianday(tk.end_time) - julianday(start_time)) as integer), -- XXX: this logic is probably wonky.
        cast ((julianday(tk.end_time) - julianday(start_time)) * 24 as integer),
        cast ((julianday(tk.end_time) - julianday(start_time)) * 1440 % 60 as integer),
        cast ((julianday(tk.end_time) - julianday(start_time)) * 86400 % 60 as integer) 
        from timekeepings tk, users u, projects p
        where
            tk.project_id = p.id and
            tk.user_id = u.id and
            tk.end_time != 0
        order by
            p.name, u.name;

-- create triggers --

/* shuffle timestamps on insert */
create trigger if not exists tg_insert_timekeepings
  after insert on timekeepings
  begin
    update timekeepings
      set end_time = NEW.start_time
      where
        timekeepings.end_time = 0 and
        timekeepings.id != NEW.id and
        timekeepings.user_id = NEW.user_id;
  end;

/* easily work with users, projects, and timekeepings table */
create trigger if not exists tg_insert_timekeep
  instead of insert on timekeep
  begin
    insert or ignore into users (name) values (NEW.username);
    insert or ignore into projects (name) VALUES (new.projectname);
    insert into timekeepings (project_id, user_id, activity) values (
        (select id from projects where name = NEW.projectname),
        (select id from users where name = NEW.username),
        NEW.activity
    );
  end
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

sqlsanitize(){ test -z "$1" || sed -e s/\'/\&\&/g <<< "$1";}

getversion() {
    local version=$(sqlblock <<< "select version from ttmetas;");
    echo "${version:-0}"
}
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