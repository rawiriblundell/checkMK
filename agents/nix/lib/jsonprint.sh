# shellcheck shell=ksh
# The MIT License (MIT)

# Copyright (c) 2020 -, Rawiri Blundell

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

################################################################################
# Author's note: This is an exercise for my own amusement/education.
# If it works well for you, fantastic!  If you have ideas, please submit them :)

# Our variant of die()
json_vorhees() {
  printf -- 'Exception: %s\n' "${@}" >&2
  exit 1
}

# Sigh.  Fine.
alias json_die='json_vorhees'
alias json_exception='json_vorhees'

# A curly brace to denote the opening of something, usually the json block
json_open() {
  printf -- '%s' "{"
}

# The partner for json_open()
# This emits a newline specifically for ndjson.
json_close() {
  printf -- '%s\n' "}"
}

# A single comma
json_comma() {
  printf -- '%s' ","
}

# Sometimes you may need to remove a trailing comma when processing a list
# i.e. the last value, object, array etc
# You should really try to structure your code to not need this
json_decomma() {
  sed 's/\(.*\),/\1 /'
}

# A function to ensure that any commands or files that we need exist
# On failure, this function generates simple warning keypairs e.g.
# { "Warning": "lsblk not found or not readable." }
json_require() {
  # shellcheck disable=SC2048
  for _fsobj in ${*}; do
    # First try to determine if it's a command
    command -v "${_fsobj}" >/dev/null 2>&1 && continue

    # Next, let's see if it's a readable file
    [[ -r "${_fsobj}" ]] && continue

    # If we get to this point, add it to our list of failures
    _failures+=( "${_fsobj}" )
  done

  # Tare a loop counter
  # This helps us to automatically determine when to stop outputting commas
  _iter_count=0

  # If we have no failures, then no news is good news - return quietly
  if (( "${#_failures[@]}" == 0 )); then
    # No news is good news
    unset _fsobj _failures _iter_count
    return 0
  # Otherwise, we process each element of our failure array
  else
    json_open
      for _fsobj in ${_failures[*]}; do
        # If we're on our first run through this loop, we need to use json_str()
        # Once we iterate _iter_count by 1, we don't need to touch it again
        if (( _iter_count == 0 )); then
          json_str Warning "${_fsobj} not found or not readable"
          (( _iter_count++ ))
        # With _iter_count > 0, we simply append each extra warning
        # The append functions are prefixed with a comma, making them stackable
        else
          json_str_append Warning "${_fsobj} not found or not readable"
        fi
      done
    json_close
  fi
  unset _fsobj _failures _iter_count
  exit 1
}

# UNIX shell variables are not typed.  But...
# We need to know what we're dealing with in order to best assign a function
# i.e. a string -> json_str(), a number -> json_num() etc...
# Unfortunately we need to fork out to grep to keep this relatively portable
# To make it more portable i.e. for ancient shells, grep will have to drop the
# '-q' and instead be directed to >/dev/null 2>&1
json_gettype() {
  # Floats
  if printf -- '%s\n' "${*}" | grep -Eq '^[-+]?[0-9]+\.[0-9]*$'; then
    printf -- '%s\n' "float"
    return 0
  fi

  # Integers
  if printf -- '%s\n' "${*}" | grep -Eq '^[-+]?[0-9]+$'; then
    printf -- '%s\n' "int"
    return 0
  fi

  # Booleans
  # In the case of a boolean, we should only ever deal with one arg
  case "${1}" in
    ([tT][rR][uU][eE])      isbool=true ;;
    ([fF][aA][lL][sS][eE])  isbool=true ;;
    ([yY][eE][sS])          isbool=true ;;
    ([nN][oO])              isbool=true ;;
    ([oO][nN])              isbool=true ;;
    ([oO][fF][fF])          isbool=true ;;
    (*)                     isbool=false ;;
  esac
  if [[ "${isbool}" = "true" ]]; then
    printf -- '%s\n' "bool"
    return 0
  fi

  # Everything else we deal with as a string
  printf -- '%s\n' "string"
  return 0
}

# Open an array block
# If an arg is provided, we return '"name": ['
# Without any arg, we simply return '['
json_arr_open() {
  case "${1}" in
    ('')  printf -- '%s' "[" ;;
    (*)   printf -- '"%s": [' "${*}" ;;
  esac
}

alias json_open_arr='json_arr_open'

# Close an array block
# With '-c' or -'--comma', we return '],'
# Without either arg, we return ']'
json_arr_close() {
  case "${1}" in
    (-c|--comma) shift 1; _comma="," ;;
    (*)          _comma="" ;;
  esac
  printf -- '%s%s' "]" "${_comma}"
  unset -v _comma
}

alias json_close_arr='json_arr_close'

# Append an array to another
# If an arg is provided, we return '],"name": ['
# Otherwise, we simply return '],['
json_arr_append() {
  case "${1}" in
    (-n|--no-bracket)
      case "${2}" in
        ('')  printf -- '%s' ",[" ;;
        (*)   shift 1; printf -- ', "%s": [' "${*}" ;;
      esac
    ;;
    ('')  printf -- '%s' "],[" ;;
    (*)   printf -- '], "%s": [' "${*}" ;;
  esac
}

alias json_append_arr='json_arr_append'

# Open an object block
# If an arg is provided, we return '"name": {'
# Without any arg, we simply return '{'
json_obj_open() {
  case "${1}" in
    ('')  printf -- '%s' "{" ;;
    (*)   printf -- '"%s": {' "${*}" ;;
  esac
}

alias json_open_obj='json_obj_open'

# Close an object block
# With '-c' or -'--comma', we return '},'
# Without either arg, we return '}'
# shellcheck disable=SC2120
json_obj_close() {
  case "${1}" in
    (-c|--comma)  printf -- '%s,' "}" ;;
    (''|*)        printf -- '%s' "}" ;;
  esac 
}

alias json_close_obj='json_obj_close'

# Append an object to another
json_obj_append() {
  case "${1}" in
    (-n|--no-bracket)
      case "${2}" in
        ('')  printf -- '%s' ",{" ;;
        (*)   shift 1; printf -- ', "%s": {' "${*}" ;;
      esac
    ;;
    ('')  printf -- '%s' "},{" ;;
    (*)   printf -- '}, "%s": {' "${*}" ;;
  esac
}

alias json_append_obj='json_obj_append'

# A function to escape characters that must be escaped in JSON
# This converts stdin into a single column of octals
# We then search for our undesirable octals and emit our replacements
# Modified from https://stackoverflow.com/a/23166624
# Some of these might not be strictly necessary... YMMV...
# TO-DO: Add ability to process its $*/$@, at the moment it must be piped into
json_str_escape() {
  od -A n -t o1 -v | tr ' \t' '\n\n' | grep . | sed '$d' |
    while read -r _char; do
      case "${_char}" in
        ('00[0-7]')  printf -- '\u00%s' "${_char}" ;;
        ('02[0-7]')  printf -- '\u00%s' "$(( _char - 10 ))" ;;
        ('010')  printf -- '%s' "\b" ;;
        ('011')  printf -- '%s' "\t" ;;
        ('012')  printf -- '%s' "\n" ;;
        ('013')  printf -- '\u00%s' "0B" ;;
        ('014')  printf -- '%s' "\f" ;;
        ('015')  printf -- '%s' "\r" ;;
        ('016')  printf -- '\u00%s' "0E" ;;
        ('017')  printf -- '\u00%s' "0F" ;;
        ('030')  printf -- '\u00%s' "18" ;;
        ('031')  printf -- '\u00%s' "19" ;;
        ('042')  printf -- '%s' "\\\"" ;;
        ('047')  printf -- '%s' "\'" ;;
        ('057')  printf -- '%s' "\/" ;;
        ('134')  printf -- '%s' "\\" ;;
        (''|*)   printf -- \\${_char} ;;
      esac
    done
}

alias json_escape_str='json_str_escape'

# Format a string keypair
# With '-c' or '--comma', we return '"key": "value",'
# Without either arg, we return '"key": "value"'
# If the value is blank or literally 'null', we return 'null' unquoted
json_str() {
  case "${1}" in
    (-c|--comma) shift 1; _comma="," ;;
    (*)          _comma="" ;;
  esac
  _key="${1:-null}"
  case "${2}" in
    (null|'') printf -- '"%s": %s%s' "${_key}" "null" "${_comma}" ;;
    (*)       shift 1; printf -- '"%s": "%s"%s' "${_key}" "${*}" "${_comma}" ;;
  esac
  unset -v _comma _key
}

# Add a string keypair to an object
# This leads with a comma, allowing us to stack keypairs
# If the value is blank or literally 'null', we return 'null' unquoted
json_str_append() {
  _key="${1:-null}"
  case "${2}" in
    (null|'') printf -- ', "%s": %s' "${_key}" "null" ;;
    (*)       shift; printf -- ', "%s": "%s"' "${_key}" "${*}" ;;
  esac
  unset -v _key
}

alias json_append_str='json_str_append'

# Format a number keypair using printf float notation.  Numbers are unquoted.
# With '-c' or '--comma', we return '"key": value,'
# Without either arg, we return '"key": value'
# If the value is not a number, an error will be thrown
# TO-DO: Possibly extend to allow scientific notataion
json_num() {
  case "${1}" in
    (-c|--comma) shift 1; _comma="," ;;
    (*)          _comma="" ;;
  esac
  case "${2}" in
    (''|null)
      printf -- '"%s": %s%s' "${1:-null}" "null" "${_comma}"
    ;;
    (*[!0-9.]*)
      json_vorhees "Value '${2}' not a number"
    ;;
    (*[0-9][.][0-9]*)
      printf -- '"%s": %.2f%s' "${1:-null}" "${2}" "${_comma}"
    ;;
    (*)
      # We strip any leading zeros as json doesn't support them (i.e. octal)
      printf -- '"%s": %.0f%s' "${1:-null}" "${2}" "${_comma}"
    ;;
  esac
  unset -v _comma
}

# Add a number keypair using printf float natation.  Numbers are unquoted.
# This leads with a comma, allowing us to stack keypairs
# If the value is blank or literally 'null', we return 'null' unquoted
json_num_append() {
  _key="${1:-null}"
  case "${2}" in
    (''|null)
      printf -- ', "%s": %s' "${_key}" "null"
    ;;
    (*[!0-9.]*)
      json_vorhees "Value '${2}' not a number"
    ;;
    (*[0-9][.][0-9]*)
      printf -- ', "%s": %.2f' "${_key}" "${2}"
    ;;
    (*)
      printf -- ', "%s": %.0f' "${_key}" "${2}"
    ;;
  esac
  unset -v _key
}

alias json_append_num='json_num_append'

# Format a boolean true/false keypair.  Booleans are unquoted.
# With '-c' or '--comma', we return '"key": value,'
# Without either arg, we return '"key": value'
# If the value is neither 'true' or 'false', an error will be thrown
# TO-DO: Extend to map extra bools
json_bool() {
  case "${1}" in
    (-c|--comma) shift 1; _comma="," ;;
    (*)          _comma="" ;;
  esac
  case "${2}" in
    ([tT][rR][uU][eE])     _bool=true ;;
    ([fF][aA][lL][sS][eE]) _bool=false ;;
    ([yY][eE][sS])         _bool=true ;;
    ([nN][oO])             _bool=false ;;
    ([oO][nN])             _bool=true ;;
    ([oO][fF][fF])         _bool=false ;;
    (*)                    json_vorhees "Value not a recognised boolean" ;;
  esac
  printf -- '"%s": %s%s' "${1:-null}" "${_bool}" "${_comma}"
  unset -v _bool _comma
}

# Add a boolean true/false keypair.  Booleans are unquoted.
# This leads with a comma, allowing us to stack keypairs
# If the value is neither 'true' or 'false', an error will be thrown
# TO-DO: Extend to map extra bools
json_bool_append() {
  _key="${1:-null}"
  case "${2}" in
    ([tT][rR][uU][eE])     _bool=true ;;
    ([fF][aA][lL][sS][eE]) _bool=false ;;
    ([yY][eE][sS])         _bool=true ;;
    ([nN][oO])             _bool=false ;;
    ([oO][nN])             _bool=true ;;
    ([oO][fF][fF])         _bool=false ;;
    (*)                    json_vorhees "Value not a recognised boolean" ;;
  esac
  printf -- ', "%s": %s' "${_key}" "${_bool}"
  unset -v _key _bool
}

alias json_append_bool='json_bool_append'

# Attempt to automatically figure out how to address a key value pair
# Untested, may change.
json_auto_append() {
  _key="${1}"
  _value="${2}"
  case $(json_gettype "${_value}") in
    (int|float) json_num_append "${_key}" "${_value}" ;;
    (bool)      json_bool_append "${_key}" "${_value}" ;;
    (string)    json_str_append "${_key}" "${_value}" ;;
  esac
  unset -v _key _value
}

alias json_append_auto='json_auto_append'

# This function takes a comma or equals delimited key-value pair input
# and emits it in a way that can be used by e.g. json_str()
# Example: a variable named 'line' that contains "Bytes: 22"
# json_num $(json_from_ckvp "${line}") -> "Bytes": 22
json_from_dkvp() {
  _line="${*}"
  case "${_line}" in
    (*:*)
      _key="${_line%%:*}"
      _value="${_line##*:}"
    ;;
    (*=*)
      _key="${_line%%=*}"
      _value="${_line##*=}"
    ;;
    (*)
      # To-do: figure out a desired behaviour for this instance
      :
    ;;
  esac
  # In the presence of a 'trim()' function, we could do the following cleaner
  # Remove any trailing whitespace from 'key'
  _key="${_key%"${_key##*[![:space:]]}"}"

  # Remove any leading whitespace from 'value'
  _value="${_value#"${_value%%[![:space:]]*}"}"

  # Remove any trailing whitespace from 'value'
  _value="${_value%"${_value##*[![:space:]]}"}"
  printf -- '"%s" "%s"' "${_key}" "${_value}"
  unset -v _line _key _value
}

# This function takes any number of parameters and blindly structures
# every pair in the sequence into json keypairs.
# Example: json_foreach a b c d
# {"a": "b", "c": "d"}
# shellcheck disable=SC2048,SC2086,SC2183
json_foreach() {
  case "${1}" in
    (-n|--name) json_obj_open "${2}"; shift 2 ;;
    (*)         json_obj_open ;;
  esac
  # Tare a loop iteration counter
  _iter_count=0
  while read -r _key _value; do
    # Tidy up our key value variables.
    # Start by removing any instances of ":" or "=" from the key
    _key="${_key%%:*}"
    _key="${_key%%=*}"

    # Remove any trailing whitespace from 'key'
    _key="${_key%"${_key##*[![:space:]]}"}"

    # Remove any leading whitespace from 'value'
    _value="${_value#"${_value%%[![:space:]]*}"}"

    # Remove any trailing whitespace from 'value'
    _value="${_value%"${_value##*[![:space:]]}"}"

    # Now we determine what variable "type" _value is and
    # based on that, we select the appropriate output function
    case "$(json_gettype "${_value}")" in
      (int|float)
        if (( _iter_count == 0 )); then
          json_num "${_key}" "${_value}"
          (( _iter_count++ ))
        else
          json_num_append "${_key}" "${_value}"
        fi
      ;;
      (bool)
        if (( _iter_count == 0 )); then
          json_bool "${_key}" "${_value}"
          (( _iter_count++ ))
        else
          json_bool_append "${_key}" "${_value}"
        fi
      ;;
      (string|''|*)
        if (( _iter_count == 0 )); then
          json_str "${_key}" "${_value}"
          (( _iter_count++ ))
        else
          json_str_append "${_key}" "${_value}"
        fi
      ;;
    esac
  done < <(printf -- '%s %s\n' ${*})
  # shellcheck disable=SC2119
  json_obj_close
  unset -v _iter_count _key _value
}

# Preliminary attempt at a function to automatically read input and build objects
# do not use
json_readloop() {
  loop_iter=0
  json_obj_open
    while read -r _key _value; do
      if (( loop_iter == 0 )); then
        case $(json_gettype "${_value}") in
          (int|float) json_num "${_key}" "${_value}" ;;
          (bool)      json_bool "${_key}" "${_value}" ;;
          (string)    json_str "${_key}" "${_value}" ;;
        esac
        (( loop_iter++ ))
      else
        case $(json_gettype "${_value}") in
          (int|float) json_num_append "${_key}" "${_value}" ;;
          (bool)      json_bool_append "${_key}" "${_value}" ;;
          (string)    json_str_append "${_key}" "${_value}" ;;
        esac
      fi
    done
  json_obj_close
}

# A function to append an object with a timestamp
# This attempts the epoch first, and fails over to YYYYMMDDHHMMSS
json_timestamp() {
  json_obj_append --no-bracket timestamp
    case "$(date '+%s' 2>&1)" in
      (*[0-9]*) json_num utc_epoch "$(date -u '+%s')" ;;
      (*)       json_num utc_YYYYMMDDHHMMSS "$(date -u '+%Y%m%d%H%M%S')" ;;
    esac
  json_obj_close
}
