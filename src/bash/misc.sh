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
