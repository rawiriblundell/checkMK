# shellcheck shell=ksh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.
####################################################################################################

# Figure out the default name of this script/check.
# This is used for the Service Description and can/should be overridden where possible
this_check="${0##*/}"

# The following functions are relevant to the scripts that source this library
# If no performance data is detected (var=value), then default to '-'
printOut() {
    if [[ "$2" == *"="* ]]; then
        printf -- '%s\n' "${1} ${this_check} ${2}" "${@:3}"
    else
        printf -- '%s\n' "${1} ${this_check} - ${2}" "${@:3}"
    fi
}

print_json() {
    printf -- '{ "%s": {"check_type": "%s", "status": "%s", "rc": %d, "stdout": "%s", "metrics": "%s", "script_name": "%s"}}' \
      "${1:-unknown}" "${2}" "${3}" "${4}" "${5}" "${6}" "${7}"
}

printAuto() {
    if (( $# == 1 )); then
        printOut P "${*}" 
    elif (( $# > 1 )); then
        printOut P "${@}" | printLong
    fi
}

printOK() {
    case "${1}" in
        (-r|--return) local returnMode=true; shift 1;;
        (-x|--exit) local exitMode=true; shift 1;;
    esac
    if (( $# == 1 )); then
        printOut 0 "${*}" 
    elif (( $# > 1 )); then
        printOut 0 "${@}" | printLong
    fi
    [[ "${returnMode}" = "true" ]] && return 0
    [[ "${exitMode}" = "true" ]] && exit 0
}

printWarn() {
    case "${1}" in
        (-r|--return) local returnMode=true; shift 1;;
        (-x|--exit) local exitMode=true; shift 1;;
    esac
    if (( $# == 1 )); then
        printOut 1 "${*}" 
    elif (( $# > 1 )); then
        printOut 1 "${@}" | printLong
    fi
    [[ "${returnMode}" = "true" ]] && return 0
    [[ "${exitMode}" = "true" ]] && exit 0
}

printCrit() {
    case "${1}" in
        (-r|--return) local returnMode=true; shift 1;;
        (-x|--exit) local exitMode=true; shift 1;;
    esac
    if (( $# == 1 )); then
        printOut 2 "${*}" 
    elif (( $# > 1 )); then
        printOut 2 "${@}" | printLong
    fi
    [[ "${returnMode}" = "true" ]] && return 0
    [[ "${exitMode}" = "true" ]] && exit 0
}

printDebug() {
    case "${1}" in
        (-r|--return) local returnMode=true; shift 1;;
        (-x|--exit) local exitMode=true; shift 1;;
    esac
    if (( $# == 1 )); then
        printOut 3 "${*}" 
    elif (( $# > 1 )); then
        printOut 3 "${@}" | printLong
    fi
    [[ "${returnMode}" = "true" ]] && return 0
    [[ "${exitMode}" = "true" ]] && exit 0
}

printAuto_json() {
    if (( $# == 1 )); then
        print_json P "${*}" 
    elif (( $# > 1 )); then
        print_json P "${@}" | printLong
    fi
}

# Represents a checkmk local style output in json
# Classic local check format is as follows (with example):
# [status code] [servicename] [metrics] [status details]
# 0 myservice myvalue=73;80;90 My output text which may contain spaces
# Which would appear in json like so:
# {
#   "service_name": "myservice",
#   "check_type": "local",
#   "status": "OK",
#   "rc": 0,
#   "stdout": "My output text which may contain spaces",
#   "metrics": "myvalue=73;80;90",
#   "script_name": "myservice.sh"
# }
print_json() {
    case "${1}" in
      (0) script_status=OK ;;
      (1) script_status=WARNING ;;
      (2) script_status=CRITICAL ;;
      (*) script_status=UNKNOWN ;;
    esac
    printf -- '{"service_name": "%s", "check_type": "%s", "status": "%s", "rc": %d, "stdout": "%s", "metrics": "%s", "script_name": "%s"}' \
      "${2}" "local" "${script_status}" "${1}" "$3}" "${4}" "${0}"
}

printOK_json() {
    case "${1}" in
        (-r|--return) local returnMode=true; shift 1;;
        (-x|--exit) local exitMode=true; shift 1;;
    esac
    if (( $# == 1 )); then
        print_json 0 "${*}" 
    elif (( $# > 1 )); then
        print_json 0 "${@}" | printLong
    fi
    [[ "${returnMode}" = "true" ]] && return 0
    [[ "${exitMode}" = "true" ]] && exit 0
}

printWarn_json() {
    case "${1}" in
        (-r|--return) local returnMode=true; shift 1;;
        (-x|--exit) local exitMode=true; shift 1;;
    esac
    if (( $# == 1 )); then
        print_json 1 "${*}" 
    elif (( $# > 1 )); then
        print_json 1 "${@}" | printLong
    fi
    [[ "${returnMode}" = "true" ]] && return 0
    [[ "${exitMode}" = "true" ]] && exit 0
}

printCrit_json() {
    case "${1}" in
        (-r|--return) local returnMode=true; shift 1;;
        (-x|--exit) local exitMode=true; shift 1;;
    esac
    if (( $# == 1 )); then
        print_json 2 "${*}" 
    elif (( $# > 1 )); then
        print_json 2 "${@}" | printLong
    fi
    [[ "${returnMode}" = "true" ]] && return 0
    [[ "${exitMode}" = "true" ]] && exit 0
}

printDebug_json() {
    case "${1}" in
        (-r|--return) local returnMode=true; shift 1;;
        (-x|--exit) local exitMode=true; shift 1;;
    esac
    if (( $# == 1 )); then
        print_json 3 "${*}" 
    elif (( $# > 1 )); then
        print_json 3 "${@}" | printLong
    fi
    [[ "${returnMode}" = "true" ]] && return 0
    [[ "${exitMode}" = "true" ]] && exit 0
}

# This function converts newlines to literal '\n' for multi-line output
printLong() {
    sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
}

################################################################################
# The following functions are for handling deltas
read_delta() {
  case "${1}" in
    ('')
      if [[ -r "${MK_TMPDIR}/${this_check}".delta ]]; then
        IFS='|' read -r deltaEpoch deltaData < "${MK_TMPDIR}/${this_check}.delta"
      else
        return 1
      fi
    ;;
    (*)
      if [[ -r "${MK_TMPDIR}/${1}".delta ]]; then
        IFS='|' read -r deltaEpoch deltaData < "${MK_TMPDIR}/${1}.delta"
      else
        return 1
      fi
    ;;
  esac
}

write_delta() {
  local deltaFile outEpoch outData
  outEpoch=$(get_epoch)
  case "${1}" in
    ('_'|'null')
      deltaFile="${MK_TMPDIR}/${this_check}.delta"
    ;;
    (*)
      deltaFile="${MK_TMPDIR}/${1}.delta"
    ;;
  esac
  shift
  outData="${*}"
  printf -- '%s|%s\n' "${outEpoch}" "${outData}" > "${deltaFile}"
}
