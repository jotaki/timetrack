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

-- time to setup new triggers
-- this setup is to get around sqlite not supporting procedures.
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
