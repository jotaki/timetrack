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
