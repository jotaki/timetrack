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
