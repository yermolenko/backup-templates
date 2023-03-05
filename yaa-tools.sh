#!/bin/bash
#
#  yaa-tools.sh - basic shell scripting tools
#
#  Copyright (C) 2010, 2013, 2014, 2017, 2019, 2020, 2021, 2022, 2023
#  Alexander Yermolenko <yaa.mbox@gmail.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

die()
{
    local msg=${1:-"Unknown error"}
    shift
    echo "ERROR: $msg $@" 1>&2
    call_function_if_declared finalize
    exit 1
}

goodbye()
{
    die "Cancelled by user"
}

info()
{
    local msg=${1:-"Unspecified message"}
    shift
    flag_is_set quiet_mode || \
        echo "INFO: $msg $@" 1>&2
}

timestamp()
{
    echo $(date "+%Y%m%d-%H%M%S")
}

require()
{
    local cmd=${1:?"Command name is required"}
    shift
    hash "$cmd" >/dev/null 2>&1 || die "$cmd not found! $@"
}

find_tool()
{
    local tool_var_name=${1:?"Tool location container variable name is required"}
    var_is_declared "$tool_var_name" && die "Variable '$tool_var_name' is already declared"
    local tool=${2:?"Tool executable name is required"}
    local cmd=./"$tool"
    [ -f "$cmd" ] || cmd="$scriptdir/$tool"
    [ -f "$cmd" ] || { cmd=$(which "$tool"); require "$tool"; }
    declare -g $tool_var_name="$cmd"
}

include()
{
    local bash_source=${1:?"bash source filename is required"}
    [ -f "$scriptdir/$bash_source" ] && \
        source "$scriptdir/$bash_source" || \
            source "$bash_source" || die "bash source $bash_source not found"
}

require_root()
{
    [ "$EUID" -eq 0 ] || die "This program is supposed to be run with superuser privileges"
}

function_is_declared()
{
    declare -f -F ${1:?"Function name is required"} >/dev/null 2>&1
}

call_function_if_declared()
{
    local function_name=${1:?"Function name is required"}
    shift
    function_is_declared "$function_name" && "$function_name" "$@"
}

var_is_declared()
{
    declare -p ${1:?"Variable name is required"} >/dev/null 2>&1
}

var_is_declared_and_nonzero()
{
    local var_name=${1:?"Variable name is required"}
    var_is_declared "$var_name" && [ "${!var_name}" -ne 0 ]
}

flag_is_set()
{
    var_is_declared_and_nonzero "$1"
}

flag_is_unset()
{
    ! var_is_declared_and_nonzero "$1"
}

require_var()
{
    var_is_declared "$1" || die "Variable '$1' is not declared"
}

check_var()
{
    var_is_declared "$1" && info "$1: declared" || info "$1: not declared"
}

# scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# date=`date "+%Y%m%d-%H%M%S"`
# date=`timestamp`
# info "`timestamp`: message text"

# echo "yaa-tools.sh is a library"
