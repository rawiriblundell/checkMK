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

# 'coreutils' 5.3.0 broke how 'stat' handled its output.  This was reverted
# in STABLE in 5.9.4.  Just in case we happen across this version
# we catch it and build a workaround to correct its behaviour
# See: https://lists.gnu.org/archive/html/bug-coreutils/2005-12/msg00157.html
if stat --version 2>&1 | head -n 1 | grepq "5.3.0"; then
    stat() {
        printf -- '%s\n' "$(command stat "${@}")"
    }
fi
