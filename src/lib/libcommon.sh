## Begin libcommon.sh

include color

function gnu_options() {
    local i

    for i in $* ;do
	if [ "$i"  = '--help' ]; then
	    print_help
	    exit 0
	fi
	if [ "$i"  = '--version' ]; then
	    print_version
	    exit 0
	fi
    done
}


function print_version() {
    echo "$exname ver. $version";
}


function print_help() {
    print_version
    echo "$help"
}


function print_exit() {
    echo $@
    exit 1
}


function print_syntax_error() {
    [ "$*" ] ||	print_syntax_error "$FUNCNAME: no arguments"
    print_exit "${ERROR}script error:${NORMAL} $@" >&2
}


function print_syntax_warning() {
    [ "$*" ] || print_syntax_error "$FUNCNAME: no arguments."
    [ "$exname" ] || print_syntax_error "$FUNCNAME: 'exname' var is null or not defined."
    echo "$exname: ${WARNING}script warning:${NORMAL} $@" >&2
}


function print_error() {
    [ "$*" ] || print_syntax_warning "$FUNCNAME: no arguments."
    [ "$exname" ] || print_exit "$FUNCNAME: 'exname' var is null or not defined." >&2
    print_exit "$exname: ${ERROR}error:${NORMAL} $@" >&2
}


function die() {
    [ "$*" ] || print_syntax_warning "$FUNCNAME: no arguments."
    [ "$exname" ] || print_exit "$FUNCNAME: 'exname' var is null or not defined." >&2
    print_exit "$exname: ${ERROR}error:${NORMAL} $@" >&2
}


function print_warning() {
    [ "$*" ] || print_syntax_warning "$FUNCNAME: no arguments."
    [ "$exname" ] || print_syntax_error "$FUNCNAME: 'exname' var is null or not defined."
    echo "$exname: ${WARNING}warning:${NORMAL} $@" >&2
}


function print_usage() {
    [ "$usage" ] || print_error "$FUNCNAME: 'usage' variable is not set or empty."
    echo "usage: $usage"
}


function invert_list() {
    local newlist

    newlist=" "
    for i in $* ; do
      newlist=" $i${newlist}"
    done
    echo $newlist
}


function get_path() {
    local type

    type="$(type -t "$1")"
    case $type in
	("file")
	    type -p "$1"
	    return 0
	    ;;
	("function" | "builtin" )
	    echo "$1"
	    return 0
	    ;;
    esac
    return 1
}


function depends() {

    ## Very important not to collide with variables that are created
    ## with depends.
    local __i __tr __path

    __tr=$(get_path "tr")
    test "$__tr" ||
	print_error "dependency check : couldn't find 'tr' command."

    for __i in $@ ; do

      if ! __path=$(get_path $__i); then
	  __new_name=$(echo $__i | "$__tr" '_' '-')
	  if [ "$__new_name" != "$__i" ]; then
	     depends "$__new_name"
	  else
	     print_error "dependency check : couldn't find '$__i' command."
	  fi
      else
	  if ! test -z "$__path" ; then
	      export "$(echo $__i | "$__tr" '-' '_')"=$__path
	  fi
      fi

    done
}


function require() {

    local i path

    for i in $@; do

      if ! path=$(get_path $i); then
	   return 1;
      else
	  if ! test -z "$path"; then
	      export $i=$path
	  fi
      fi

    done
}


function check() {
    for i in $@; do
      [ "$(type -t "check_$i")" == "function" ] &&
          "check_$i" && continue

      print_error "dependency check : couldn't find 'check_$i' function."
    done
}


function check_ls_timestyle() {

    depends ls

    ##  Checking a special option of "ls"
    ##     -ls does accept the --time-style ?

    if ! "$ls" --time-style=+date:%Y%m%d%H%M.%S / >/dev/null 2>&1; then
	print_error "'$ls' doesn't support the --time-style argument, please upgrade your coreutils tools."
    fi
}


function print_bytes () {

    depends bc
    [ "$*" ] || print_syntax_error "$FUNCNAME: no arguments.";
    [ "$2" ] && print_syntax_error "$FUNCNAME: too much arguments.";


    (
    export LC_ALL=C

    bytes="$1"
    [ "$bytes" == 0 -o "$bytes" == 1 ] && { printf "%s byte" $bytes; return 0;}

    [ "$(echo "$bytes < 1024" | "$bc" )" == "1" ] &&
        { printf "%s bytes" $bytes; return 0;}

    kbytes="$(echo "$bytes / 1024" | bc )"
    [ "$(echo "$kbytes < 1024" | bc)" == "1" ] &&
        { printf "%.2f KiB" "$(echo "$bytes / 1024" | "$bc" -l)" ; return 0; }

    mbytes="$(echo "$kbytes / 1024" | bc )"
    [ "$(echo "$mbytes < 1024" | bc)" == "1" ] &&
        { printf "%.2f MiB" "$(echo "$kbytes / 1024" | "$bc" -l)" ; return 0; }

    gbytes="$(echo "$mbytes / 1024" | bc )"
    [ "$(echo "$gbytes < 1024" | bc )" == "1" ] &&
        { printf "%.2f GiB" "$(echo "$mbytes / 1024" | "$bc" -l)" ; return 0; }

    tbytes="$(echo "$gbytes / 1024" | bc )"
    [ "$(echo "$tbytes < 1024" | bc )" == "1" ] &&
        { printf "%.2f TiB" "$(echo "$gbytes / 1024" | "$bc" -l)" ; return 0; }


    pbytes="$(echo "$tbytes / 1024" | bc )"
    printf "%.2f PiB" "$(echo "$tbytes / 1024" | "$bc" -l)"
    )
}


## compatibility:
function print_octets () {
    print_bytes "$@"
}


function is_set() {
    local i val

    for i in $*; do
	val=$(eval echo -n \$$i)
	if test -z "$val"; then
	    print_error "Variable \$$i is not set."
	fi
    done
    return 0
}


function checkfile () {

    [ "$*" ] || print_syntax_error "$FUNCNAME: no arguments."
    [ "$3" ] && print_syntax_error "$FUNCNAME: too much arguments."

    separate=$(echo "$1" | sed_compat 's/(.)/ \1/g')

    for i in $(echo $1 | sed_compat 's/(.)/ \1/g'); do
	case "$i" in
		"")
			:
		;;
                "e")
                        if ! [ -e "$2" ]; then
	                        echo "'$2' is not found."
        	                return 1
			fi;;
		"f")
			if ! [ -f "$2" ]; then
				echo "'$2' is not a regular file."
				return 1
			fi;;
		"d")
			if ! [ -d "$2" ]; then
				echo "'$2' is not a directory."
				return 1
			fi;;
		"r")
	                if ! [ -r "$2" ]; then
	                        echo "'$2' is not readable."
	                        return 1
			fi;;
                "w")
			if ! [ -w "$2" ]; then
	                        echo "'$2' is not writable."
	                        return 1
			fi;;
                "x")
                        if ! [ -x "$2" ]; then
	                        echo "'$2' is not executable/openable."
	                        return 1
			fi;;
		"l")
			if ! [ -L "$2" ]; then
				echo "'$2' is not a symbolic link."
				return 1
			fi;;
	esac
    done

    return 0
}


function matches() {

    [ "$*" ] || print_syntax_error "$FUNCNAME: no arguments."
    [ "$3" ] && print_syntax_error "$FUNCNAME: too much arguments."

     echo "$1" | "$grep" "^$2\$" >/dev/null 2>&1
}


function find_conf_file() {

    [ "$*" ] || print_syntax_error "$FUNCNAME: no arguments."
    [ "$2" ] && print_syntax_error "$FUNCNAME: too much arguments."

    poss="~/.$1 "

    [ -d "$KAL_CONF_DIR" ] && poss="$KAL_CONF_DIR/$1 $poss"
    [ -d "$KAL_PREFIX" ] && poss="$KAL_PREFIX/etc/$1 $poss"

    poss="/etc/$1 /usr/etc/$1 /usr/local/etc/$1 "

    for i in $poss ; do
	n=$(eval echo "$i")
	if [ -f "$n" -a -r "$n" ]; then
	    echo "$n"
	    return 0
	fi
    done

    ## return first choice
    for i in $poss ;do
	n=$(eval echo "$i")
	echo "$n"
	return 1
    done
}


function str_is_uint() {
    matches "$1" "[0-9]\+"
}


function str_is_sint() {
    matches "$1" '\(-\|+\)\?[0-9]\+'
}


function str_is_sreal() {
    matches "$1" '\(-\|+\)\?[0-9]\+\(\.[0-9]\+\)\?'
}


function str_is_ipv4() {
    ## XXXvlab: not perfect as it will match 929.267829872.2.129782
    matches "$1" '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+'
}


## BSD / GNU sed compatibility layer
function sed_compat() {

    depends sed cat

    if test "$BSD_SED"; then
        ## BSD sed
	"$cat" - | "$sed" -E "$1"
	return 0
    fi

    ## GNU sed
    "$cat" - | "$sed" -r "$1"
    return 0

}


## BSD / GNU md5 compatibility layer
function md5_compat() {

    depends cat

    if test "$BSD_MD5"; then
        ## BSD md5
	depends md5
	"$cat" - | "$md5"
	return 0
    fi

    ## GNU md5
    depends md5sum
    "$cat" - | "$md5sum" | "$cut" -c -32
    return 0
}


## BSD / GNU compatibile
function get_perm() {
    if test "$BSD_STAT"; then
	"$stat" -f %OLp "$1"
	return 0
    fi

    "$stat" "$1" -c %a
}


function check_perm() {
    [ "$(get_perm "$1")" == "$2" ]
}


function same_contents() {
    "$diff" "$1" "$2" >/dev/null 2>&1
}


function is_set() {
    "$print_env" "$1" >/dev/null 2>&1
}


function pause() {
    read -sn1 key
}


depends basename

[ -n "$exname" ] || exname=$("$basename" $0)
[ -n "$fullexname" ] || fullexname=$0

depends grep sed stat cut diff df

if ! is_set BSD_SED; then
    "$sed" --version > /dev/null 2>&1 || BSD_SED=1
fi

if ! is_set BSD_MD5; then
    type md5sum > /dev/null 2>&1 || BSD_MD5=1
fi

if ! is_set BSD_STAT; then
    "$stat" --version > /dev/null 2>&1 || BSD_STAT=1
fi

if ! is_set BSD_DF; then
    "$df" --version > /dev/null 2>&1 || BSD_DF=1
fi

## End libcommon.sh
