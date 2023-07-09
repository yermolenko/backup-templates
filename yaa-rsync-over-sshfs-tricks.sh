#!/bin/bash
#
#  yaa-rsync-over-sshfs-tricks.sh - sshfs-specific rsync-based tricks
#
#  Copyright (C) 2019, 2022, 2023 Alexander Yermolenko
#  <yaa.mbox@gmail.com>
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

require sshfs
require time_machine_backup

time_machine_backup_remotedir_over_sshfs()
{
    local what2backup=${1:?what2backup dir is required}
    local backup_excludes=${2:-"*~"}
    local backup_item_name=${3:-"maindir"}

    require_var user
    require_var host
    require_var ssh_port

    require sshfs

    info "=== Backing up $what2backup over sshfs ==="

    [ -e ./fs ] && \
        fusermount -u ./fs && sleep 2 && rmdir ./fs
    [ -d ./fs ] && rmdir ./fs
    [ -e ./fs ] || mkdir ./fs
    [ -d ./fs ] || die "Cannot create mountpoint"

    if [ ${#extra_ssh_options[@]} -eq 0 ]; then
        ssh_command_option_for_sshfs=()
    else
        ssh_command_option_for_sshfs=(-o ssh_command="ssh ${extra_ssh_options[*]}")
    fi

    info "extra_sshfs_options: ${extra_sshfs_options[@]}"
    info "ssh_command_option_for_sshfs: ${ssh_command_option_for_sshfs[@]}"

    local sshfs_remote_root="$what2backup"

    if var_is_declared ssh_password_file;
    then
        [ -f "$ssh_password_file" ] || die "ssh_password_file does not exist"
        sshfs "$user@$host":"$sshfs_remote_root" ./fs/ \
              -p $ssh_port "${extra_sshfs_options[@]}" \
              "${ssh_command_option_for_sshfs[@]}" \
              -o password_stdin \
              < "$ssh_password_file"
    else
        sshfs "$user@$host":"$sshfs_remote_root" ./fs/ \
              -p $ssh_port "${extra_sshfs_options[@]}" \
              "${ssh_command_option_for_sshfs[@]}" || \
            die "Cannot mount sshfs"
    fi

    sleep 2

    time_machine_backup "./fs/" "$backup_excludes" "$backup_item_name"

    sleep 10

    fusermount -u ./fs && sleep 2 && rmdir ./fs || \
            die "Cannot umount sshfs"
}

# echo "yaa-rsync-over-sshfs-tricks.sh is a library"
