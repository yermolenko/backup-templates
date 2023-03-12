#!/bin/bash
#
#  yaa-ssh-tricks-basic.sh - basic ssh-based tricks
#
#  Copyright (C) 2022, 2023 Alexander Yermolenko <yaa.mbox@gmail.com>
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

require ssh

build_ssh_command()
{
    ssh_command=()

    if var_is_declared ssh_password_file;
    then
        require sshpass
        ssh_command+=(sshpass -f "$ssh_password_file")
    fi

    ssh_command+=(ssh)
    ssh_command+=("${extra_ssh_options[@]}")
    ssh_command+=(-p $ssh_port)
    ssh_command_wo_user_at_host=("${ssh_command[@]}")
    ssh_command+=("$user@$host")
}

test_ssh_command()
{
    require_var ssh_command
    info "ssh_command array: ${ssh_command[@]}"

    echo -n "Testing ssh... "
    "${ssh_command[@]}" hostname || die "Cannot test ssh"
}

run_via_ssh_sh_c()
{
    local sh_c_command=("$@")

    # debug: passing double quoted sed expressions with quoted singe quotes does not work

    require_var ssh_command

    info "=== Executing command via ssh:"

    info "Command is an array of ${#sh_c_command[@]} elements"

    info "Command for remote 'sh -c' will be:"
    info "${sh_c_command[@]}"

    info "Running the command ..."
    "${ssh_command[@]}" \
        sh -c \
        "'"${sh_c_command[@]}"'"
}

run_via_ssh()
{
    local command=("$@")

    require_var ssh_command

    info "=== Executing command via ssh:"

    info "Command is an array of ${#command[@]} elements"

    info "Command for ssh will be:"
    info "${command[@]}"

    info "Running the command ..."
    "${ssh_command[@]}" \
        "${command[@]}"
}

perform_extra_ssh_command_tests()
{
    info "Testing ssh (remote hostname): "
    run_via_ssh hostname || die "Cannot test ssh"

    info "Testing ssh (passing 'uname -a' as a string to run_via_ssh_sh_c):"
    sh_c_command="uname -a"
    run_via_ssh_sh_c "${sh_c_command[@]}" || die "Cannot test ssh"

    info "Testing ssh (passing 'uname -a' as a string to run_via_ssh):"
    sh_c_command="uname -a"
    run_via_ssh "${sh_c_command[@]}" || die "Cannot test ssh"

    info "Testing ssh (passing 'uname -a' as an array to run_via_ssh_sh_c):"
    sh_c_command=(uname -a)
    run_via_ssh_sh_c "${sh_c_command[@]}" || die "Cannot test ssh"

    info "Testing ssh (passing 'uname -a' as an array to run_via_ssh):"
    sh_c_command=(uname -a)
    run_via_ssh "${sh_c_command[@]}" || die "Cannot test ssh"
}

# echo "yaa-ssh-tricks-basic.sh is a library"
