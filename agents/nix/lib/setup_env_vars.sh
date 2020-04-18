# shellcheck shell=sh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.

# Requires: Prior loading of common functions library

####################################################################################################
#MK_BASEDIR="/opt/checkmk/agent"
MK_BASEDIR="/home/rawiri/git/checkMK/agents/nix"

# Define the version of Check_MK
# Unless otherwise specified, plugins and local checks are indexed to this version
# If a VERSION file exists, then read it
if [ -r "${MK_BASEDIR}/VERSION" ]; then
    read -r MK_VERSION < "${MK_BASEDIR}/VERSION"
# Otherwise, see if we can get it from our git branch, or set it to 'Unknown'
# This logic should, ideally, very rarely be used.  If ever.
elif get_command git; then
    _git_branch="$(git branch 2>/dev/null| sed -n '/\* /s///p')"
    case "${_git_branch}" in
        ('') MK_VERSION="Unknown" ;;
        (*)  MK_VERSION="${_git_branch}" ;;
    esac
    unset -v _git_branch
    printf -- '%s\n' "${MK_VERSION}" > "${MK_BASEDIR}/VERSION"
else
    MK_VERSION="Unknown"
    printf -- '%s\n' "${MK_VERSION}" > "${MK_BASEDIR}/VERSION"
fi

MK_LIBDIR="${MK_BASEDIR}/lib"
MK_CONFDIR="${MK_BASEDIR}/etc"
MK_VARDIR="${MK_BASEDIR}/var"
MK_TMPDIR="${MK_BASEDIR}/tmp"

MK_COREDIR="${MK_BASEDIR}/core-checks"

# All executables in MK_PLUGINSDIR will simply be executed and their
# ouput appended to the output of the agent. Plugins define their own
# sections and must output headers with '<<<' and '>>>'
MK_PLUGINSDIR="${MK_BASEDIR}/plugins"

# All executables in MK_LOCALDIR will be executed and their
# output inserted into the section <<<local:sep(0)>>>. Please
# refer to online documentation for details about local checks.
MK_LOCALDIR="${MK_BASEDIR}/local"

# Define the path to the local check config file
MK_LOCALCONF="${MK_CONFDIR}/checkmk-local.conf"

# All files in MK_SPOOLDIR will simply appended to the agent
# output if they are not outdated (see below)
MK_SPOOLDIR="${MK_VARDIR:?}/spool"

# Ensure that the MK_OSSTR environment variable is set.
# This imitates the 'OSTYPE' variable from bash
# We use this variable later on for OS specific behaviour
case $(uname -s) in
    ("AIX")                              MK_OSSTR=aix ;;
    ("Darwin")                           MK_OSSTR=mac ;;
    ("FreeBSD")                          MK_OSSTR=freebsd ;;
    ("HPUX")                             MK_OSSTR=hpux ;;
    ("Linux"|"linux-gnu"|"GNU"*)         MK_OSSTR=linux ;;
    ("NetBSD")                           MK_OSSTR=netbsd ;;
    ("OpenBSD")                          MK_OSSTR=openbsd ;;
    ("SunOS"|"solaris")                  MK_OSSTR=solaris ;;
    (*"BSD"|*"bsd"|"DragonFly"|"Bitrig") MK_OSSTR=bsd ;;
    (*)                                  MK_OSSTR=$(uname -s) ;;
esac

# Protect all our MK variables
readonly MK_BASEDIR MK_OSSTR MK_LIBDIR MK_CONFDIR MK_VARDIR MK_VERSION 
readonly MK_PLUGINSDIR MK_LOCALDIR MK_LOCALCONF MK_SPOOLDIR MK_TMPDIR MK_COREDIR

# Export all our MK variables
export MK_BASEDIR MK_OSSTR MK_LIBDIR MK_CONFDIR MK_VARDIR MK_VERSION 
export MK_PLUGINSDIR MK_LOCALDIR MK_LOCALCONF MK_SPOOLDIR MK_TMPDIR MK_COREDIR

# If EUID isn't set, then set it
# Note that 'id -u' is now mostly portable here due to the alignment of xpg4 above
# '[ -w / ]' may be an alternative test for proving root privileges...
if [ -z "${EUID}" ]; then
    EUID=$(id -u); readonly EUID; export EUID
fi

# If HOSTNAME isn't set, then set it
if [ -z "${HOSTNAME}" ]; then 
    HOSTNAME=$(hostname); readonly HOSTNAME; export HOSTNAME
fi

# If HOME isn't set, then set it
# TO-DO: Figure out non-getent based solution(s)
if [ -z "${HOME}" ]; then
    HOME=$(getent passwd | awk -F':' -v EUID="${EUID}" '$3 == EUID{print $6}')
    readonly HOME; export HOME
fi

# If USER isn't set, then set it
# TO-DO: Figure out non-getent based solution(s)
if [ -z "${USER}" ]; then
    USER=$(getent passwd | awk -F':' -v EUID="${EUID}" '$3 == EUID{print $1}')
    readonly USER; export USER
fi

# Newer shells like zsh and bash5.x have EPOCHSECONDS.  If it's not available, we set it
# Note that if this is set here, it will not update each time it's used
# Use get_epoch() if you need that kind of accuracy
if [ -z "${EPOCHSECONDS}" ]; then
    EPOCHSECONDS=$(get_epoch); readonly EPOCHSECONDS; export EPOCHSECONDS
fi

# If SHELL isn't set, then set it.
if [ -z "${SHELL}" ]; then
    if get_shell >/dev/null 2>&1; then
        SHELL=$(command -v "$(get_shell)"); readonly SHELL; export SHELL
    fi
fi

# Figure out which shell we're going to use.  We do this to enforce a POSIX baseline, and to
# minimise the amount of pure Bourne shell code that we have to write and maintain.
# I have attempted to put the list of preferred shells in appropriate order
# This list should cover most releases of Linux, Solaris, HPUX and AIX.
# See: http://www.in-ulm.de/~mascheck/various/shells/

# Set the default list of shells that we like
shList="/bin/bash /usr/bin/bash /usr/dt/bin/dtksh /usr/xpg4/bin/sh /usr/mbin/ksh"
shList="${shList} /usr/bin/ksh93 /bin/ksh /usr/bin/ksh /bin/posix/sh /usr/bin/sh /sbin/sh"

# If bash is available, test its version.  We want newer than 2.05
if bash --version >/dev/null 2>&1; then
    # Get the version and use expr to check if it's not higher than 2.05
    # If indeed it isn't, discount bash from shList
    # Disabling SC2006 as this script is intentionally bourne sh
    # in order to bootstrap the environment into minimum POSIX capability
    # shellcheck disable=SC2006
    if expr "`bash -version | awk -F'[ (]' '/version/{print $4;exit}'`" '>' 2.05 >/dev/null; then
        # No-op, as we may be invoked by an ancient version of 'sh that doesn't support '!' negation
        :
    else
        shList="/usr/xpg4/bin/sh /usr/mbin/ksh /usr/bin/ksh93 /bin/ksh /usr/bin/ksh /bin/posix/sh /usr/bin/sh /sbin/sh"
    fi
fi

# Go through each shell in the list and see if it exists.  Break the loop on the first one found.
for shell in ${shList}; do
    if [ -x "${shell}" ]; then
        readonly MK_SHELL="${shell}"
        export MK_SHELL
        break
    fi
done

# Throw in a cursory check to ensure that a shell from the list has been found
if [ -z "${MK_SHELL}" ]; then
    printf -- '%s\n' "POSIX compatible shell required, one wasn't found."
    exit 1
fi

# The package name gets patched for baked agents to either
# "check-mk-agent" or the name set by the "name of agent packages" rule
XINETD_SERVICE_NAME=checkmk
readonly XINETD_SERVICE_NAME; export XINETD_SERVICE_NAME

# Detect whether or not the agent is being executed in a container
# environment.
if [ -f /.dockerenv ]; then
    MK_IS_DOCKERIZED=1
    readonly MK_IS_DOCKERIZED; export MK_IS_DOCKERIZED
elif grepq container=lxc /proc/1/environ; then
    # Works in lxc environment e.g. on Ubuntu bionic, but does not
    # seem to work in proxmox (see CMK-1561)
    MK_IS_LXC_CONTAINER=1
    readonly MK_IS_LXC_CONTAINER; export MK_IS_LXC_CONTAINER
elif grepq 'lxcfs /proc/cpuinfo fuse.lxcfs' /proc/mounts; then
    # Seems to work in proxmox
    MK_IS_LXC_CONTAINER=1
    readonly MK_IS_LXC_CONTAINER; export MK_IS_LXC_CONTAINER
else
    unset -v MK_IS_DOCKERIZED
    unset -v MK_IS_LXC_CONTAINER
fi

# Provide information about the remote host. That helps when data
# is being sent only once to each remote host.
if [ "${REMOTE_HOST}" ]; then
    MK_RTC_HOST="${REMOTE_HOST}"
    export MK_RTC_HOST
elif [ "${SSH_CLIENT}" ]; then
    MK_RTC_HOST="${SSH_CLIENT%% *}"
    export MK_RTC_HOST
fi

# If we are called via xinetd, try to find only_from configuration
if [ -n "${REMOTE_HOST}" ]; then
    MK_ONLYFROM=$(sed -n '/^service[[:space:]]*'${XINETD_SERVICE_NAME}'/,/}/s/^[[:space:]]*only_from[[:space:]]*=[[:space:]]*\(.*\)/\1/p' /etc/xinetd.d/* | head -n1)
    # shellcheck disable=SC2039
    printf -- 'OnlyFrom: %s\n' "${MK_ONLYFROM}"
    readonly MK_ONLYFROM
    export MK_ONLYFROM
fi
