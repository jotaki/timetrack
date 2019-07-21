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
