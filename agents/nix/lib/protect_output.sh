#!/bin/ksh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.

# Load our variables for encrypted data.  See protect_output()
if [ -r "${MK_CONFDIR}/encryption.cfg" ]; then
    # We ensure that this file is secure
    chmod 640 "${MK_CONFDIR}/encryption.cfg" 2>/dev/null

    # shellcheck source=/dev/null
    . "${MK_CONFDIR}/encryption.cfg"
fi

# Setup a function to encrypt the output using openssl
protect_output() {
    if ! inpath openssl; then
        mkecho "ERROR: protect_output(): 'openssl' not found in PATH" >&2
        return
    fi

    # If this function has an arg "-rt", then we're being used for realtime data
    if [ "${1}" = "-rt" ]; then
        # Let's see if RTC_SECRET is defined
        if [ ! -r "${MK_CONFDIR}/real_time_checks.cfg" ]; then
            mkecho "ERROR: protect_output(): Unable to read real_time_checks.cfg"
            return
        fi
        # If we have a defined RTC_SECRET, then we prioritise that.
        # This is a reversal of the previous behaviour, because we may want a setup
        # where realtime checks go to hostA secured with pwdA, and normal check 
        # output goes to hostB secured with pwdB.  This approach makes that clear.
        if grepq "^RTC_SECRET=.*" "${MK_CONFDIR}/real_time_checks.cfg"; then
            PASSPHRASE=$(awk -F '=' '/^RTC_SECRET/{print $2' "${MK_CONFDIR}/real_time_checks.cfg")
        fi
    fi

    # Convert the openssl version to an integer e.g. 1.0.2k-fips -> 10002
    _opensslVer=$(openssl version | awk '{print $2}' | awk -F . '{print (($1 * 100) + $2) * 100+ $3}')
    # shellcheck disable=SC2039
    if [ "${_opensslVer}" -ge 10000 ]; then
        _encCode="02"
        _encMode=sha256
    else
        _encCode="00"
        _encMode=md5
    fi

    # Print our protocol and/or epoch information
    if [ "${1}" = "-rt" ]; then
        mkecho -n "${_encCode}$(get_epoch)"
    else
        mkecho -n "${_encCode}"
    fi

    # Call openssl with our required digest and auth
    openssl enc -aes-256-cbc -md "${_encMode}" -k "${PASSPHRASE}" -nosalt

    unset _opensslVer _encMode _encCode
}