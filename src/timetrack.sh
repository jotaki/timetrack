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

center_text() {
    local cols=$(tput cols 2>/dev/null) opts="-e" txt=;
    if test "$1" = "-n"; then
        opts="-en";
        shift;
    fi

    if ! test -n "$cols"; then
        echo $opts "\t\t$*";
        return 1;
    fi

    txt="$*";
    cols=$(($cols / 2));
    cols=$(($cols - $((${#txt} / 2))));
    tput cuf $cols;
    echo $opts "$*";
}

getinput() {
    local input="$*";

    case "$use_stdin" in
        0) input="$*" ;;
        1) input="$(readinput)" ;;
        2) input="$(readinput_ed)" || return 1 ;;
    esac
    echo -n "$(sqlsanitize "$input")"
}

readinput() {
    local line= buf=
    echo "enter input to be used for <text>. send EOF (press Ctrl-D) when done."
    while read -p '> ' buf; do line="$line $buf"; done
    echo -n "$line";
}

readinput_ed() {
    local file= input=
    test -n "$EDITOR" -a -x "$EDITOR" || return 1
    test -x $(which mktemp) || return 1

    file="$(mktemp)"
    test -f "$file" || return 1

    $EDITOR "$file"
    if test $? -ne 0; then
        cerr error: "$EDITOR closed unexpectedly" >&2
        rm -f "$file"
        return 1
    fi

    input="$(<"$file")"
    rm -f "$file"
    echo -n "$input"
}

testvars() {
    if [[ -z "$TIMETRACK_DB_PATH" ]]; then
        cerr error: "database path cannot be empty"
        exit 1
    elif [[ -z "$TIMETRACK_PROJECT" ]]; then
        cerr error: "project cannot be an empty string"
        exit 1
    elif [[ -z "$TIMETRACK_USER" ]]; then
        cerr error: "user cannot be an empty string"
        exit 1
    fi
    return 0
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
###
# sqlmig.sh: sql migration

MIGFROM=0
MIGTO=1
sqlmigrate() {
    sqlblock <<- EOF 2>/dev/null
>
-- ttmetas
alter table ttmetas add column description varchar(255);
insert into ttmetas (version, description) values (1, 'Big improvements - see changelog.');

-- create a changelog table
create table if not exists ttchangelogs (
    id integer primary key autoincrement,
    version_id integer not null,
    devname varchar(255) not null,
    description blob not null,
    object_type varchar(255) not null,
    object varchar(255) not null,
    created_at datetime not null default current_timestamp,

    foreign key(version_id) references ttmetas(id)
);
insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'table', 'ttchangelogs',
        'introducing changelog table.');

-- removing timereport view
drop view if exists timereport;
insert into ttchangelogs (version_id, devname, description, object_type, object) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'removed view', 'view', 'timereport');

-- tasks
create table if not exists tasks (
    id integer primary key autoincrement,
    description blob not null unique,
    shortname varchar(255) unique,     -- should default to task#id if not specified.
    created_at datetime not null default current_timestamp
);
insert into ttchangelogs (version_id, devname, description, object_type, object) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'created table', 'table', 'tasks');

create table if not exists tasklog (
    id integer primary key,
    user_id integer not null,
    project_id integer not null,
    task_id integer not null,
    start_time datetime not null default current_timestamp,
    end_time datetime not null default 0,
    created_at datetime not null default current_timestamp,

    foreign key(user_id) references users(id),
    foreign key(project_id) references projects(id),
    foreign key(task_id) references tasks(id)
);
insert into ttchangelogs (version_id, devname, description, object_type, object) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'created table', 'table', 'tasklog');

-- tags
create table if not exists tags (
    id integer primary key autoincrement,
    name varchar(255) not null,
    description varchar(255),
    created_at not null default current_timestamp
);
insert into ttchangelogs (version_id, devname, description, object_type, object) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'created table', 'table', 'tags');

create table if not exists taglog (
    id integer primary key autoincrement,
    project_id integer,
    task_id integer,
    tag_id not null,
    created_at not null default current_timestamp,

    check ( (project_id is not null or task_id is not null) ),

    unique (tag_id, project_id),
    unique (tag_id, task_id),

    foreign key(project_id) references projects(id),
    foreign key(task_id) references tasks(id),
    foreign key(tag_id) references tags(id)
);
insert into ttchangelogs (version_id, devname, description, object_type, object) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'created table', 'table', 'taglog');

-- projectlog
create table if not exists projectlog (
    id integer primary key autoincrement,
    user_id integer not null,
    project_id integer not null,
    start_time datetime not null default current_timestamp,
    end_time datetime not null default 0,

    unique (user_id, project_id)
    
    foreign key(user_id) references users(id),
    foreign key(project_id) references projects(id)
);
insert into ttchangelogs (version_id, devname, description, object_type, object) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'created table', 'table', 'projectlog');

-- migrate project acvtity to tasks.
insert into tasks (description) select distinct activity from timekeepings;
update tasks set shortname = 'task' || cast (tasks.id as varchar);

insert into tasklog (project_id, task_id, user_id, start_time, end_time)
    select tk.project_id, t.id, tk.user_id, tk.start_time, tk.end_time from timekeepings tk
        left outer join tasks t on tk.activity = t.description;

insert into ttchangelogs (version_id, devname, description, object_type, object) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 
        'migrate data from timekeepings to tasks/tasklog', 'migration', 'tasks');

insert into projectlog(project_id, user_id) select distinct project_id, user_id from timekeepings;
update projectlog set start_time = (
    select min(start_time) from tasklog where tasklog.project_id = projectlog.project_id
);
update projectlog set end_time = (
    select case
        when end_time = 0 then 0
        else max(end_time)
    end from tasklog where projectlog.project_id = tasklog.project_id
);

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'migration', 'projectlog',
        'migrate data from timekeepings to projectlog');

-- remove timekeepings table.
drop table if exists timekeepings;
insert into ttchangelogs (version_id, devname, description, object_type, object) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'remove table',
        'table', 'timekeepings');

-- add description column to projects table.
alter table projects add column description blob;
update projects set description = name;
insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'column', 'projects',
        'add description column to projects table');

-- remove view timereport;
drop view if exists timereport;
insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'view', 'timereport',
        'remove timereport');

-- remove view timekeep
drop view if exists timekeep;
insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'view', 'timekeep',
        'removed timekeep view');

-- remove triggers
drop trigger if exists tg_insert_timekeepings;
drop trigger if exists tg_insert_timekeep;
insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'trigger', 'tg_insert_timekeepings',
        'removed insert timekeepings trigger');
insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'trigger', 'tg_insert_timekeep',
        'removed insert timekeep trigger');

-- views (for procedural triggers)
create view new_task (username, projectname, projectdescription, taskname, description, future) as
    select 0, 0, 0, 0, 0, 0;

create view tag_task (taskname, tagname) as select 0, 0;
create view tag_project (projectname, tagname) as select 0, 0;

-- time to setup new triggers
-- this setup is to get around sqlite not supporting procedures.
create trigger if not exists tg_insert_tag_project
  instead of insert on tag_project
  begin
    insert or ignore into projects (name) values (NEW.projectname);
    insert into taglog (project_id, tag_id) values (
        (select id from projects where name = NEW.projectname),
        (select id from tags where name = NEW.tagname)
    );
  end;

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'trigger', 'tg_insert_tag_project',
        'insert into tag_project to tag a project. columns are projectname and tagname.');

create trigger if not exists tg_insert_tag_task
  instead of insert on tag_task
  begin
    insert or ignore into tags (name) values (NEW.tagname);
    insert into taglog (task_id, tag_id) values (
        (select id from tasks where shortname = NEW.taskname),
        (select id from tags where name = NEW.tagname)
    );
  end;

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'trigger', 'tg_insert_tag_task',
        'insert into tag_task to tag a task. columns are taskname and tagname.');

create trigger if not exists tg_insert_new_task
  instead of insert on new_task
  begin
    insert or ignore into users (name) values (NEW.username);
    insert or ignore into projects (name, description) values (
        NEW.projectname,
        case
            when NEW.projectdescription is null then NEW.projectname
            else NEW.projectdescription
        end
    );

    insert or ignore into projectlog (user_id, project_id) values (
        (select id from users where name = NEW.username),
        (select id from projects where name = NEW.projectname)
    );

    insert or ignore into tasks (description, shortname) values (NEW.description, NEW.taskname);
    insert into tasklog (user_id, project_id, task_id) values (
        (select id from users where name = NEW.username),
        (select id from projects where name = NEW.projectname),
        (select id from tasks where description = NEW.description)
    );

    update tasklog set start_time = (
        select case
            when NEW.future is not null then 0
            else current_timestamp
        end as correct_time
    ) where (tasklog.user_id = (select id from users where name = NEW.username) and
            tasklog.project_id = (select id from projects where name = NEW.projectname) and
            tasklog.task_id = (select id from tasks where description = NEW.description)
    );
  end;
insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'trigger', 'tg_insert_new_task',
        'fields/keys: username, projectname, projectdescription?, ' ||
        'taskname, description, future?' || char(10) ||
        'username: the username' || char(10) ||
        'projectname: the project name' || char(10) ||
        'projectdescription: the project description (optional)' || char(10) ||
        'taskname: the shortname for the task.' || char(10) ||
        'description: the actual description of the task' || char(10) ||
        'future: set as a future task (optional, default is false)' || char(10));

create trigger if not exists tg_insert_tasks
  after insert on tasks
  begin
    update tasks
      set shortname = 'task' || cast (NEW.id as varchar)
      where id = NEW.id and shortname is null;
  end;
insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'trigger', 'tg_insert_tasks',
        'automatically apply the shortname task#id if shortname is empty');

create trigger if not exists tg_insert_tasklog
  after insert on tasklog
  begin
    update tasklog
      set end_time = current_timestamp
      where
        tasklog.end_time = 0 and
        tasklog.id != NEW.id and
        tasklog.user_id = NEW.user_id;

    update projectlog
      set end_time = 0
      where
        projectlog.project_id = NEW.project_id and
        projectlog.user_id = NEW.user_id;

    update projectlog
      set end_time = current_timestamp
      where
        projectlog.project_id != NEW.project_id and
        projectlog.user_id = NEW.user_id and
        projectlog.end_time = 0;
  end;

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'trigger', 'tg_insert_tasklog',
        'auto update tasklog, and projectlog timestamps when inserting into tasklog');

-- some simple views
create view if not exists active_tasks (username, projectname, taskdescription, timespent) as
    select u.name, p.name, t.description, cast (
        cast ((julianday('now') - julianday(tl.start_time)) as integer) || ':' ||
        cast ((julianday('now') - julianday(tl.start_time)) * 24 % 24 as integer) || ':' ||
        cast ((julianday('now') - julianday(tl.start_time)) * 1440 % 60 as integer) || ':' ||
        cast ((julianday('now') - julianday(tl.start_time)) * 86400 % 60 as integer) as varchar)
    from tasklog tl, tasks t, projects p, users u
    where
        tl.end_time = 0 and
        tl.user_id = u.id and
        tl.project_id = p.id and
        tl.task_id = t.id;

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'view', 'active_tasks',
        'display active tasks');

create view if not exists _tasks (username, projectname, taskdescription, timespent, 
                                  status, days, hours, minutes, seconds) as
    select distinct u.name, p.name, t.description, cast (
        (select case 
            when
                cast ((julianday(tl.end_time) - julianday(tl.start_time)) as integer) < 0
            then
                cast ((julianday('now') - julianday(tl.start_time)) as integer) || ':' ||
                cast ((julianday('now') - julianday(tl.start_time)) * 24 % 24 as integer) || ':' ||
                cast ((julianday('now') - julianday(tl.start_time)) * 1440 % 60 as integer) || ':' ||
                cast ((julianday('now') - julianday(tl.start_time)) * 86400 % 60 as integer)
            else
                cast ((julianday(tl.end_time) - julianday(tl.start_time)) as integer) || ':' ||
                cast ((julianday(tl.end_time) - julianday(tl.start_time)) * 24 % 24 as integer) || ':' ||
                cast ((julianday(tl.end_time) - julianday(tl.start_time)) * 1440 % 60 as integer) || ':' ||
                cast ((julianday(tl.end_time) - julianday(tl.start_time)) * 86400 % 60 as integer)
            end
        ) as varchar), cast (
        (select case 
            when cast ((julianday(tl.end_time) - julianday(tl.start_time)) as integer) < 0
            then 'active' else 'inactive'
            end
        ) as varchar), cast (
        (select case
            when cast ((julianday(tl.end_time) - julianday(tl.start_time)) as integer) < 0
            then cast ((julianday('now') - julianday(tl.start_time)) as integer)
            else cast ((julianday(tl.end_time) - julianday(tl.start_time)) as integer)
            end
        ) as integer), cast (
        (select case
            when cast ((julianday(tl.end_time) - julianday(tl.start_time)) as integer) < 0
            then cast ((julianday('now') - julianday(tl.start_time)) * 24 % 24 as integer)
            else cast ((julianday(tl.end_time) - julianday(tl.start_time)) * 24 % 24 as integer)
            end
        ) as integer), cast (
        (select case
            when cast ((julianday(tl.end_time) - julianday(tl.start_time)) as integer) < 0
            then cast ((julianday('now') - julianday(tl.start_time)) * 1440 % 60 as integer)
            else cast ((julianday(tl.end_time) - julianday(tl.start_time)) * 1440 % 60 as integer)
            end
        ) as integer), cast (
        (select case
            when cast ((julianday(tl.end_time) - julianday(tl.start_time)) as integer) < 0
            then cast ((julianday('now') - julianday(tl.start_time)) * 86400 % 60 as integer)
            else cast ((julianday(tl.end_time) - julianday(tl.start_time)) * 86400 % 60 as integer)
            end
        ) as integer)
    from tasklog tl, tasks t, projects p, users u
    where
        tl.user_id = u.id and
        tl.project_id = p.id and
        tl.task_id = t.id;

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'view', '_tasks',
        'a _tasks wrapper view around tasks and tasklog');

create view if not exists active_projects (username, projectname, projectdescription, timespent) as
    select u.name, p.name, p.description, cast (
        cast ((julianday('now') - julianday(pl.start_time)) as integer) || ':' ||
        cast ((julianday('now') - julianday(pl.start_time)) * 24 % 24 as integer) || ':' ||
        cast ((julianday('now') - julianday(pl.start_time)) * 1440 % 60 as integer) || ':' ||
        cast ((julianday('now') - julianday(pl.start_time)) * 86400 % 60 as integer) as varchar)
    from projectlog pl, projects p, users u
    where
        pl.end_time = 0 and
        pl.user_id = u.id and
        pl.project_id = p.id;

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'view', 'active_projects',
        'display active projects');

create view if not exists _projects (username, projectname, projectdescription, timespent,
                                     status, days, hours, minutes, seconds) as
    select distinct u.name, p.name, p.description, cast (
        (select case 
            when
                cast ((julianday(pl.end_time) - julianday(pl.start_time)) as integer) < 0
            then
                cast ((julianday('now') - julianday(pl.start_time)) as integer) || ':' ||
                cast ((julianday('now') - julianday(pl.start_time)) * 24 % 24 as integer) || ':' ||
                cast ((julianday('now') - julianday(pl.start_time)) * 1440 % 60 as integer) || ':' ||
                cast ((julianday('now') - julianday(pl.start_time)) * 86400 % 60 as integer)
            else
                cast ((julianday(pl.end_time) - julianday(pl.start_time)) as integer) || ':' ||
                cast ((julianday(pl.end_time) - julianday(pl.start_time)) * 24 % 24 as integer) || ':' ||
                cast ((julianday(pl.end_time) - julianday(pl.start_time)) * 1440 % 60 as integer) || ':' ||
                cast ((julianday(pl.end_time) - julianday(pl.start_time)) * 86400 % 60 as integer)
            end
        ) as varchar), cast (
        (select case 
            when cast ((julianday(pl.end_time) - julianday(pl.start_time)) as integer) < 0
            then 'active' else 'inactive'
            end
        ) as varchar), cast (
        (select case
            when cast ((julianday(pl.end_time) - julianday(pl.start_time)) as integer) < 0
            then cast ((julianday('now') - julianday(pl.start_time)) as integer)
            else cast ((julianday(pl.end_time) - julianday(pl.start_time)) as integer)
            end
        ) as integer), cast (
        (select case
            when cast ((julianday(pl.end_time) - julianday(pl.start_time)) as integer) < 0
            then cast ((julianday('now') - julianday(pl.start_time)) * 24 % 24 as integer)
            else cast ((julianday(pl.end_time) - julianday(pl.start_time)) * 24 % 24 as integer)
            end
        ) as integer), cast (
        (select case
            when cast ((julianday(pl.end_time) - julianday(pl.start_time)) as integer) < 0
            then cast ((julianday('now') - julianday(pl.start_time)) * 1440 % 60 as integer)
            else cast ((julianday(pl.end_time) - julianday(pl.start_time)) * 1440 % 60 as integer)
            end
        ) as integer), cast (
        (select case
            when cast ((julianday(pl.end_time) - julianday(pl.start_time)) as integer) < 0
            then cast ((julianday('now') - julianday(pl.start_time)) * 86400 % 60 as integer)
            else cast ((julianday(pl.end_time) - julianday(pl.start_time)) * 86400 % 60 as integer)
            end
        ) as integer)
    from projectlog pl, tasks t, projects p, users u
    where
        pl.user_id = u.id and
        pl.project_id = p.id;

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'view', '_projects',
        'a _projects wrapper view around projectlog and projects');

create view if not exists _tags (projectname, taskdescription, tagname) as
    select p.name, task.description, tag.name from taglog tl
        left outer join projects p on p.id = tl.project_id
        left outer join tasks task on task.id = tl.task_id
        left outer join tags tag on tag.id = tl.tag_id;

insert into ttchangelogs (version_id, devname, object_type, object, description) values
    ((select id from ttmetas where version = 1 limit 1), 'jk', 'view', '_tags',
        'a _tags wrapper view around taglog');
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
# runmodes.sh: available runmodes

updateproject() {
    local cur= input= cols=

    cols=$(tput cols)
    cols=${cols:-80}

    input="$(getinput "$*")";
    cur="$(sqlblock <<< "select description from projects where name = '$input';")";

    if test -z "$input"; then
        cmsg status: "Project description for project: $TIMETRACK_PROJECT"
        fold -w $(($cols - 8)) -s <<< "$cur" | sed s/^/${ATTR_NHILITE}status:\ ${ATTR_NORMAL}/g
    elif test "$cur" != "$TIMETRACK_PROJECT"; then
        cwarn warning: "Project $TIMETRACK_PROJECT already has description"
        fold -w $(($cols - 9)) -s <<< "$cur" | sed s/^/${ATTR_WHILITE}warning:\ ${ATTR_NORMAL}/g
        echo
        cmsg -n question: "Are you sure you want to overwrite it? "
        if chkyninput n; then
            cmsg status: "ok, I wont update the description of $TIMETRACK_PROJECT"
        fi
    else
        sqlblock <<< "insert or ignore into projects (name) values ('$TIMETRACK_PROJECT');";
        sqlblock <<< "update projects set description = '$input' where name = '$TIMETRACK_PROJECT';";
        cmsg status: "updated the description of project '$TIMETRACK_PROJECT'";
    fi

    return 0;
}

migration() {
    chkdb

    cmsg -n status: "Migrating database ... "
    sqlmigrate
    chkfail || return $?
    return 0
}

query() {
    local table=$(getinput "$*");
    if test -z "$table"; then
        cerr error: "table cannot be empty.\n"
        cwarn notice: "useful tables (views) are:"
        cwarn notice: "users        - all users (u)"
        cwarn notice: "_tasks       - all tasks (t)"
        cwarn notice: "_projects    - all projects (p)"
        cwarn notice: "_tags        - all tags (g)"
        while test -z "$table"; do
            cmsg -n question: "which view would you like to see? [utpgx] "
            read -N 1 -s table
            if test -z "$table"; then
                echo
                continue
            fi
            case "$table" in
                u) table="users" ;;
                t) table="_tasks" ;;
                p) table="_projects" ;;
                g) table="_tags" ;;
                x)  echo -n "${ATTR_CBLUE}e${ATTR_BOLD}x${ATTR_NORMAL}"
                    echo "${ATTR_CBLUE}it${ATTR_NORMAL}"
                    return 0
                ;;
                *)  echo $table
                    cerr error: "erroneous input: $table"
                    cwarn notice: "use x to quit"
                    table=""
            esac
            test -z "$table" || echo "${ATTR_CCYAN}$table${ATTR_NORMAL}"
        done
    fi

    sqlblock -readonly -header -column <<< "select * from '$table';"
}

showreport() {
    sqlblock -readonly -header -column <<< \
        "select username, projectname, taskdescription, timespent, status from _tasks;"
}

addtask() {
    local input=$(getinput "$*");
    if test -z "$input"; then
        cerr error: "Adding empty tasks is not permitted"
        return 1;
    fi

    
}
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

test -n "$TIMETRACK_PROJECT" || 

exit 0;

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

if [ ! -f "$TIMETRACK_DB_PATH" ]; then
    echo -n "$TIMETRACK_DB_PATH does not exist, attempting to create it ... "
    initdb
    chkfail || exit 1
fi

sqlchkversion || exit 1

cmsg -n status: "updating table ..."
trackit "$TIMETRACK_USER" "$TIMETRACK_PROJECT" "$activity"
chkfail || exit 1
