# About

Timetrack is a tool for tracking time, currently backed by sqlite.

## Usage

```bash
                                        timetrack
                                    schema version 1

usage: ./timetrack.sh [options] <text>
  -h          print usage and exit

  -s          read <text> from stdin

  -e          use <text> inserted text from $EDITOR (/usr/bin/vim)

  -M          migrate scehma from version 0 to version 1
              Only use this option if you are informed to do so.

  -r          show report (equivalent to ./timetrack.sh -q _tasks)

  -q          equivalent to select * from <text>;
              useful views: _tasks, _projects, _tags,
              active_tasks, active_projects

  -t task     create <text> as task description for task
              switches current task to specified task
              environment variable: TIMETRACK_TASK ()

  -T tag(s)   a comma separated list of tags ()
              environment variable: TIMETRACK_TAGS

  -p name     set project name to name ()
              environment variable: TIMETRACK_PROJECT

  -u name     set username to name (jk)
              environment variable: TIMETRACK_USER

  -d path     set database file path to path (/home/jk/.timetrackdb)
              environment variable: TIMETRACK_DB_PATH

  -z          mark all active tasks in project (-p) to inactive.
              the project is also marked as inactive.

  command line options override environment settings.

    for most tasks TIMETRACK_PROJECT (-p) cannot be blank.
    TIMETRACK_USER defaults to $USER (jk), id -g (1000), or 'tt-user'
    TIMETRACK_TAGS defaults to an empty string

  see timetrack(1) for more details.
```

## Work in progress
Could've swore I had the migration system working, apparently not. I am working on fixing that now.
This project is a bit complicated, and haven't worked on it in some months, it may be a minute before I finish "fixing" the -M.

Note: This project uses triggers on views to emulate procedures, since sqlite doesn't support
procedures directly.
