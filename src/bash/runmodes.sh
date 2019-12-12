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
