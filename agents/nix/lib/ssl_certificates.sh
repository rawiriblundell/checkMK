#!/bin/ksh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.

# Expected format example: "Nov 10 2034 21:19:01"
convert_time_to_epoch() {
    month day timestamp year hours min sec

    # Read our incoming date/time information into our variables
    mkecho "${*:?No date provided}" | read -r month day year timestamp
    mkecho "${timestamp}" | IFS=':' read -r hours min sec

    # Convert the month to 0..11 range
    case "${month}" in
        ([jJ]an*) month=0 ;;
        ([fF]eb*) month=1 ;;
        ([mM]ar*) month=2 ;;
        ([aA]pr*) month=3 ;;
        ([mM]ay)  month=4 ;;
        ([jJ]un*) month=5 ;;
        ([jJ]ul*) month=6 ;;
        ([aA]ug*) month=7 ;;
        ([sS]ep*) month=8 ;;
        ([oO]ct*) month=9 ;;
        ([nN]ov*) month=10 ;;
        ([dD]ec*) month=11 ;;
    esac

    # Pass our variables to the mighty 'perl'
    perl -e 'use Time::Local; print timegm(@ARGV[0,1,2,3,4], $ARGV[5]-1900)."\n";' "${sec}" "${min}" "${hours}" "${day}" "${month}" "${year}"
}

# Calculate how many days until the cert expires
# Short circuit versions of 'date' that don't support '-d' (e.g. Solaris)
# In this instance, we want to call 'convert_time_to_epoch()'
if date -d yesterday 2>&1 | grep illegal >/dev/null 2>&1; then
    calculate_cert_epoch() {
        convert_time_to_epoch "$(read_cert_expiry "${1:?No Cert Defined}")"
    }
else
    calculate_cert_epoch() {
        date -d "$(read_cert_expiry "${1:?No Cert Defined}")" +%s
    }
fi