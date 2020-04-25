# shellcheck shell=sh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.

# 'mkecho()' abstracts the portability of 'printf' and solves the major 
# portability headaches caused by various implementations of 'echo'
# This is called 'mkecho()' rather than an 'echo()' override because 
# some shells protect their builtins, denying us the override cleanliness
# Fun exercise: look at Oracle's man page for 'echo', specifically the USAGE section.
# This also adds the '-j' option to output in json string keypair format
mkecho() {
    case "${1}" in
        (-e)
            case "${2}" in
                (-n)      shift 2; printf -- '%b' "${*}" ;;
                (*)       shift; printf -- '%b\n' "${*}" ;;
            esac
        ;;
        (-E)
            case "${2}" in
                (-n)      shift 2; printf -- '%s' "${*}" ;;
                (*)       shift; printf -- '%s\n' "${*}" ;;
            esac
        ;;
        (-j)              shift; printf -- '{"%s": "%s"}\n' "${1}" "${2}" ;;
        (-n)
            case "${2}" in
                (-e)      shift 2; printf -- '%b' "${*}" ;;
                (-E)      shift 2; printf -- '%s' "${*}" ;;
                (*)       shift; printf -- '%s' "${*}" ;;
            esac
        ;;
        (-en|-ne)         shift; printf -- '%b' "${*}" ;;
        (-En|-nE)         shift; printf -- '%s' "${*}" ;;
        (*)               printf -- '%s\n' "${*}" ;;
    esac
}

# date +%s is not portable, so we provide this function
# To do this in pure shell is... fun... however 'perl' is assumed
# elsewhere in this agent, so we may as well depend on that for our failover option
if date +%s 2>/dev/null | grepq '%s'; then
    get_epoch() { perl -e 'print time."\n";'; }
else
    get_epoch() { date +%s; }
fi

get_rc() {
  "${@}" >/dev/null 2>&1 && return "${?}"
}

# Functionalise and standardise 'quiet grep' based tests.
# This gives us 'grep -q' cleanliness where '>/dev/null 2>&1'
# would otherwise be required e.g. Solaris, older versions of grep etc
if mkecho "word" | grep -q "word" >/dev/null 2>&1; then
    grepq() { grep -q "$@" 2>/dev/null; }
else
    grepq() { grep "$@" >/dev/null 2>&1; }
fi

# Function to replace "if type [somecmd]" idiom
# 'command -v' tends to be more robust vs 'which' and 'type' based tests
is_command() {
  command -v "${1:?No command to test}" >/dev/null 2>&1
}

alias get_command='is_command'
alias inpath='is_command'

# Check that a file isn't open in order to prevent race conditions
is_file_avail() {
    [ ! -f "${1:?No file specified}" ] && return 1
    ! lsof -- "${1:?No file specified}" >/dev/null 2>&1
}

is_directory() {
    [ -d "${1:?No Directory Defined}" ]
}

is_executable() {
    [ -x "${1:?No file specified}" ]
}

is_fsobj() {
    [ -e "${1:?No file specified}" ]
}

is_readable() {
    [ -r "${1:?No file specified}" ]
}

is_set() {
    if [ -z "${1+x}" ]; then
        return 0
    else
        return 1
    fi
}

is_true() {
    case "${1}" in
        ([tT][rR][uU][eE])     return 0 ;;
        ([fF][aA][lL][sS][eE]) return 1 ;;
        ([yY]|[yY][eE][sS])    return 0 ;;
        ([nN]|[nN][oO])        return 1 ;;
        ([oO][nN])             return 0 ;;
        ([oO][fF][fF])         return 1 ;;
        (0)                    return 0 ;;
        (''|*)                 return 1 ;;
    esac
}

is_false() {
    case "${1}" in
        ([tT][rR][uU][eE])     return 1 ;;
        ([fF][aA][lL][sS][eE]) return 0 ;;
        ([yY]|[yY][eE][sS])    return 1 ;;
        ([nN]|[nN][oO])        return 0 ;;
        ([oO][nN])             return 1 ;;
        ([oO][fF][fF])         return 0 ;;
        (0)                    return 1 ;;
        (''|*)                 return 0 ;;
    esac
}

is_symlink() {
    [ -L "${1:?No file specified}" ]
}

# This function ensures that a file is executable and
# does not have certain patterns within its name
# TO-DO: Setup housekeeping function to auto-delete problematic files
# TO-DO: Convert this into a run() function?
is_valid_plugin() {
    case "${1:?No plugin defined}" in
        (*dpkg-new|*dpkg-old|*dpkg-temp)
            return 1
        ;;
        (*)
            if [ -x "${1}" ]; then
                return 0
            else
                return 1
            fi
        ;;
    esac
}

# GNU 'coreutils' 5.3.0 broke how 'stat' handled its output.  This was reverted in 5.9.4 STABLE.
# See: https://lists.gnu.org/archive/html/bug-coreutils/2005-12/msg00157.html
# If 'MK_STAT_BUG' is set to 'true', then enable our override function.
# This corrects the behaviour of 'stat' globally
case "${MK_STAT_BUG}" in
    (true)
        stat() {
            printf -- '%s\n' "$(command stat "${@}")"
        }
    ;;
    (false)
        # No-op
        :
    ;;
    (''|*)
        if stat --version | grepq GNU; then
        # If we get to this point, then MK_STAT_BUG isn't set at all
        if stat --version 2>&1 | head -n 1 | grepq "5.[3-9].[0-9]"; then
            # The following sequence of transformations converts a semantic version to an integer
            # Where the Major number is untouched, and the Minor and Patch numbers are zero padded
            # e.g. 'stat (GNU coreutils) 8.28' --> '82800'
            # This technique allows us to do simple integer based version comparisons
            stat_version=$(stat --version | head -n 1)
            stat_version="${stat_version//[!0-9.]/}"
            # We want word splitting here so that 'set' assigns each 'word' appropriately
            # shellcheck disable=SC2086
            set -- ${stat_version//./ }
            stat_version="${1}$(printf -- '%02d' "${2}" "${3:-0}")"

            if [ "${stat_version}" -ge 50300 ] && [ "${stat_version}" -lt 50904 ]; then
                printf -- '%s\n' "MK_STAT_BUG=true" >> "${mk_conf}"
                stat() {
                    printf -- '%s\n' "$(command stat "${@}")"
                }
            else
                printf -- '%s\n' "MK_STAT_BUG=false" >> "${mk_conf}"
            fi
        fi
        else
            printf -- '%s\n' "MK_STAT_BUG=false" >> "${mk_conf}"
        fi
    ;;
esac
