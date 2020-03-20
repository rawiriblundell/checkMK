# shellcheck shell=ksh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.
####################################################################################################

# Requires local_check_functions.sh

target_service="${1:?No service specified}"

if [[ -x /bin/systemctl ]]; then
    Start_Service() {
        /bin/systemctl start "${target_service}"
    }
    Stop_Service() {
        /bin/systemctl stop "${target_service}"
    }
    Restart_Service() {
        /bin/systemctl restart "${target_service}"
    }
elif [[ -x /sbin/service ]]; then
    Start_Service() {
        /sbin/service "${target_service}" start >/dev/null 2>&1
    }
    Stop_Service() {
        /sbin/service "${target_service}" stop >/dev/null 2>&1
    }
    Restart_Service() {
        /sbin/service "${target_service}" restart >/dev/null 2>&1
    }
elif [[ -f /etc/init.d/"${target_service}" ]]; then
    Start_Service() {
        /etc/init.d/"${target_service}" start >/dev/null 2>&1
    }
    Stop_Service() {
        /etc/init.d/"${target_service}" stop >/dev/null 2>&1
    }
    Restart_Service() {
        /etc/init.d/"${target_service}" restart >/dev/null 2>&1
    }
else
    Start_Service() {
        printDebug "Service control method not found"
    }
    Stop_Service() {
        printDebug "Service control method not found"
    }
    Restart_Service() {
        printDebug "Service control method not found"
    }
fi