# About

Timetrack is a tool for tracking time, currently backed by sqlite.

## Usage

```bash
$ timetrack -h
usage: ./timetrack [options] <activity description>
  -h          print usage and exit

  -s          read <activity description> from stdin

  -r          show report

  -p name     set project name to name ()
              environment variable: TIMETRACK_PROJECT

  -u name     set username to name (user)
              environment variable: TIMETRACK_USER

  -d path     set database file path to path (/home/user/.timetrackdb)
              environment variable: TIMETRACK_DB_PATH

  command line options override environment settings.

  <activity description> should be a breif description of what you
  are working on for a given project.

    TIMETRACK_PROJECT (-p) cannot be blank.
    TIMETRACK_USER defaults to $USER (user), id -g (1000), or 'tt-user'
```

## Work in progress
Could've swore I had the migration system working, apparently not. I am working on fixing that now.
This project is a bit complicated, and haven't worked on it in some months, it may be a minute before I finish "fixing" the -M.

Note: This project uses triggers on views to emulate procedures, since sqlite doesn't support
procedures directly.
