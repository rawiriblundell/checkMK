# shellcheck shell=ksh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.

# For AIX, force load of environment.
# shellcheck source=/dev/null
[ -e "${HOME}"/.profile ] && . "${HOME}"/.profile >/dev/null 2>&1

# Avoid problems with wrong decimal separators in other language verions of aix
LC_NUMERIC="en_US"
export LC_NUMERIC