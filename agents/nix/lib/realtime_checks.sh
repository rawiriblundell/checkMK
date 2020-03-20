# shellcheck shell=ksh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.


# Define a helper function to send real time check data
# If we're using ksh93 or bash, then we should have /dev/tcp and /dev/udp capability built in
# This isn't always the case, however, as these shells can be compiled without it
# So we test directly for this capability and if it's not working, we use 'netcat'
case $(waitmax 1 bash -c ": </dev/tcp/127.0.0.1/9 2>&1") in
    (""|*"Connection refused"*)
        send_rtc() {
            # RTC_PORT is defined in "${MK_CONFDIR}/real_time_checks.cfg
            waitmax 4 "/dev/udp/${1:?No Host Defined}/${2:?No Port Defined}" < /dev/stdin
        }
    ;;
    (*)
        # Otherwise, we try netcat under either its 'nc' or its 'netcat' monikers
        # TO-DO: Add alternatives like socat?
        if inpath nc netcat; then
            send_rtc() {
                _bin_nc=$(command -v nc netcat 2>/dev/null | head -n 1)
                "${_bin_nc}" "${1:?No Host Defined}" "${2:?No Port Defined}"
                unset -v _bin_nc
            }
        else
            mkecho "send_rtc(): Unable to determine communication method" >&2
        fi
    ;;
esac

# Implements Real-Time Check feature of the Check_MK agent which can send
# some section data in 1 second resolution. Useful for fast notifications and
# detailed graphing (if you configure your RRDs to this resolution).
run_real_time_checks() {
    _rt_pid=${MK_VARDIR:?}/real_time_checks.pid
    mkecho "$$" >"${_rt_pid}"

    while true; do
        # terminate when pidfile is gone or other Real-Time Check process started or configured timeout
        if [ ! -e "${_rt_pid}" ] || [ "$(cat "${_rt_pid}")" -ne $$ ] || [ "${RTC_TIMEOUT}" -eq 0 ]; then
            exit 1
        fi

        for _rt_section in ${RTC_SECTIONS}; do
            # Be aware of maximum packet size. Maybe we need to check the size of the section
            # output and do some kind of nicer error handling.
            # 2 bytes: protocol version, 10 bytes: timestamp, rest: encrypted data
            # dd is used to concatenate the output of all commands to a single write/block => udp packet
            # TO-DO: See if this use of dd can be made portable.  'iflag' is a gnuism.
            {
                if [ "${ENCRYPTED_RT}" != "no" ]; then
                    # protect_output() takes care of printing our protocol and epoch info
                    section_"${_rt_section}" | protect_output -rt
                else
                    mkecho -n "99$(get_epoch)"
                    section_"${_rt_section}"
                fi
            } | dd bs=9999 iflag=fullblock 2>/dev/null | send_rtc "${MK_RTC_HOST}" "${RTC_PORT}"
        done

        # Plugins
        if cd "${MK_PLUGINSDIR}"; then
            for _rt_plugin in ${RTC_PLUGINS}; do
                # If the plugin doesn't exist, skip to the next one in the list
                [ ! -f "${_rt_plugin}" ] && continue
                # Same comment as per section handling above applies here
                {
                    if [ "${ENCRYPTED_RT}" != "no" ]; then
                        ./"${_rt_plugin}" | protect_output -rt
                    else
                        mkecho -n "99$(get_epoch)"
                        ./"${_rt_plugin}"
                    fi
                } | dd bs=9999 iflag=fullblock 2>/dev/null | send_rtc "${MK_RTC_HOST}" "${RTC_PORT}"
            done
        fi

        sleep 1
        RTC_TIMEOUT=$((RTC_TIMEOUT - 1))
    done

    unset -v _rt_pid _rt_section _rt_plugin
}