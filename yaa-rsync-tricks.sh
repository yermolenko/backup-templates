#!/bin/bash
#
#  yaa-rsync-tricks.sh - various rsync-based tricks
#
#  Copyright (C) 2014, 2015, 2017, 2022, 2023 Alexander Yermolenko
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

require rsync

ntfs_friendly_rsync=0

rsync_bwlimit="10000"

rsync_backup_filter1='dir-merge /.essential-backup.rsync-filter'
rsync_backup_filter2='dir-merge /.partial-backup.rsync-filter'
rsync_backup_filter3='dir-merge /.full-backup.rsync-filter'

time_machine_backup()
{
    # To backup just contents what2backup should end with /

    local what2backup=${1:?what2backup dir is required}
    local backup_excludes=${2:-"*~"}
    local backup_item_name=${3:-"maindir"}

    require_var backuproot
    require_var date
    require_var rsync_backup_filter1
    require_var rsync_backup_filter2
    require_var rsync_backup_filter3
    require_var rsync_bwlimit

    require rsync

    info "=== Time Machine Backup ==="
    info "backuproot: $backuproot"
    info "what2backup: $what2backup"
    info "backup_excludes:"$'\n'"$backup_excludes"
    info "backup_item_name: $backup_item_name"
    info "RSYNC_RSH env var: $RSYNC_RSH"

    [ -d "$backuproot/$backup_item_name" ] || mkdir -p "$backuproot/$backup_item_name" || \
        die "Can't create destination dir. Exiting."

    info "I am going to perform 'Time Machine' backup ..."
    sleep 5
    info "'Time Machine' backup started ..."

    local rsync_command=(rsync)
    if [ $ntfs_friendly_rsync -eq 1 ]
    then
        info "using ntfs-friendly rsync options"
        rsync_command+=(-rltDixv)
    else
        rsync_command+=(-aHAXixv)
    fi

    if [ $test -eq 1 ]
    then
        info "DRY RUN of time-machine backup"
        rsync_command+=(-n)
    fi
    rsync_command+=(--compress)
    rsync_command+=(--stats)
    rsync_command+=(--exclude-from=-)
    rsync_command+=(--filter="$rsync_backup_filter1")
    rsync_command+=(--filter="$rsync_backup_filter2")
    rsync_command+=(--filter="$rsync_backup_filter3")
    rsync_command+=(--link-dest="$backuproot/$backup_item_name/current")
    rsync_command+=(--bwlimit="$rsync_bwlimit")
    rsync_command+=(--)
    rsync_command+=("$what2backup")
    rsync_command+=("$backuproot/$backup_item_name/.$date")

    if [ $test -eq 1 ]
    then
        echo "$backup_excludes" | \
            "${rsync_command[@]}"
    else
        echo "$backup_excludes" | \
            "${rsync_command[@]}" \
                > "$backuproot/$backup_item_name/.$date.stdout" 2>"$backuproot/$backup_item_name/.$date.stderr" && \
            rm -f "$backuproot/$backup_item_name/current" && \
            ln -s ".$date" "$backuproot/$backup_item_name/current" && \
            info "Backup completed successfully." && \
            touch "$backuproot/$backup_item_name/.$date.completed" && \
            info "Backup completed successfully. Everything is OK" || \
                die "Backup failed. Something went wrong"
    fi
}

time_machine_backup_remotedir()
{
    local what2backup=${1:?what2backup dir is required}
    local backup_excludes=${2:-"*~"}
    local backup_item_name=${3:-"maindir"}

    require_var user
    require_var host
    require build_ssh_command
    build_ssh_command
    require_var ssh_command_wo_user_at_host

    RSYNC_RSH="${ssh_command_wo_user_at_host[@]}" \
             time_machine_backup "$user@$host:$what2backup" "$backup_excludes" "$backup_item_name"
}

plain_backup()
{
    # To backup just contents what2backup should end with /

    local what2backup=${1:?what2backup dir is required}
    local backup_excludes=${2:-"*~"}
    local backup_item_name=${3:-"maindir"}

    require_var backuproot
    require_var date
    require_var rsync_backup_filter1
    require_var rsync_backup_filter2
    require_var rsync_backup_filter3
    require_var rsync_bwlimit

    require rsync

    info "=== Plain Backup ==="
    info "backuproot: $backuproot"
    info "what2backup: $what2backup"
    info "backup_excludes:"$'\n'"$backup_excludes"
    info "backup_item_name: $backup_item_name"
    info "RSYNC_RSH env var: $RSYNC_RSH"

    [ -d "$backuproot/$backup_item_name" ] || mkdir -p "$backuproot/$backup_item_name" || \
        die "Can't create destination dir. Exiting."

    info "I am going to perform 'Plain' backup ..."
    sleep 5
    info "'Plain' backup started ..."

    local rsync_command=(rsync)
    if [ $ntfs_friendly_rsync -eq 1 ]
    then
        info "using ntfs-friendly rsync options"
        rsync_command+=(-rltDixv)
    else
        rsync_command+=(-aHAXixv)
    fi

    if [ $test -eq 1 ]
    then
        info "DRY RUN of plain backup"
        rsync_command+=(-n)
    fi
    rsync_command+=(--compress)
    rsync_command+=(--stats)
    rsync_command+=(--exclude-from=-)
    rsync_command+=(--filter="$rsync_backup_filter1")
    rsync_command+=(--filter="$rsync_backup_filter2")
    rsync_command+=(--filter="$rsync_backup_filter3")
    rsync_command+=(--bwlimit="$rsync_bwlimit")
    rsync_command+=(--)
    rsync_command+=("$what2backup")
    rsync_command+=("$backuproot/$backup_item_name/data")

    if [ $test -eq 1 ]
    then
        echo "$backup_excludes" | \
            "${rsync_command[@]}"
    else
        echo "$backup_excludes" | \
            "${rsync_command[@]}" \
                > "$backuproot/$backup_item_name/.$date.stdout" 2>"$backuproot/$backup_item_name/.$date.stderr" && \
            info "Backup completed successfully." && \
            touch "$backuproot/$backup_item_name/.$date.completed" && \
            info "Backup completed successfully. Everything is OK" || \
                die "Backup failed. Something went wrong"
    fi
}

plain_backup_remotedir()
{
    local what2backup=${1:?what2backup dir is required}
    local backup_excludes=${2:-"*~"}
    local backup_item_name=${3:-"maindir"}

    require_var user
    require_var host
    require build_ssh_command
    build_ssh_command
    require_var ssh_command_wo_user_at_host

    RSYNC_RSH="${ssh_command_wo_user_at_host[@]}" \
             plain_backup "$user@$host:$what2backup" "$backup_excludes" "$backup_item_name"
}

# echo "yaa-rsync-tricks.sh is a library"
