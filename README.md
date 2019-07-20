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
