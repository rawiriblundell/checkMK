# shellcheck shell=ksh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.

if inpath zonename; then
    zonename=$(zonename)
    pszone="-z ${zonename}"
else
    zonename="global"
    pszone="-A"
fi