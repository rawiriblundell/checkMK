# shellcheck shell=sh
# vim: noai:ts=4:sw=4:expandtab

# Copyright (C) 2019 tribe29 GmbH - License: GNU General Public License v2
# This file is part of Checkmk (https://checkmk.com). It is subject to the terms and
# conditions defined in the file COPYING, which is part of this source code package.

####################################################################################################
# Dynamically build PATH to ensure that locally installed binaries are found

# Enter potential PATH members, one per line, in order of preference
# We put the GNU and XPG options early to make our life easier on Solaris
list_potential_paths() {
cat << EOF
/home/rawiri/git/checkMK/agents/nix/bin
/opt/checkmk/agent/bin
/opt/checkmk/agent/sbin
/usr/gnu/bin
/usr/xpg6/bin
/usr/xpg4/bin
/usr/kerberos/bin
/usr/kerberos/sbin
/bin
/sbin
/usr/bin
/usr/sbin
/usr/local/bin
/usr/local/sbin
/usr/local/opt/texinfo/bin
/usr/local/opt/libxml2/bin
/usr/X11/bin
/opt/csw/bin
/opt/csw/sbin
/opt/sfw/bin
/opt/sfw/sbin
/opt/X11/bin
/usr/sfw/bin
/usr/sfw/sbin
/usr/games
/usr/local/games
/snap/bin
${HOME}/bin
${HOME}/go/bin
/usr/local/go/bin
${HOME}/.cargo
/Library/TeX/texbin
EOF

# If Android Home exists, print more dirs
if [ -d "${HOME}"/Library/Android/sdk ]; then
    ANDROID_HOME="${HOME}"/Library/Android/sdk
    printf -- '%s\n' "${ANDROID_HOME}/tools" "${ANDROID_HOME}/tools/bin" \
        "${ANDROID_HOME}/emulator" "${ANDROID_HOME}/platform-tools"
fi

# Finally, get any PATHS from OSX, because 'path_helper' can be sloooww
cat "$(find "${HOME}"/.pathrc /etc/paths /etc/paths.d -type f 2>/dev/null)" 2>/dev/null
}

# Blank a variable for the following dynamic PATH task
newPath=

# Read through each line of output from `list_potential_paths()`
# If a line is already in $newPath, skip on
# If it's not in $newPath and is a directory, append it to $newPath
for path in $(list_potential_paths); do
    # If it's already in newPath, skip on to the next dir
    case "${newPath}" in 
        (*:${path}:*|*:${path}$) : ;;
        (*) [ -d "${path}" ] && newPath="${newPath}:${path}" ;;
    esac
done

# Now assign our freshly built newPath variable, removing any leading colon
PATH="${newPath#:}"

# Finally, export the PATH and unset newPath
readonly PATH
export PATH
unset -v newPath
