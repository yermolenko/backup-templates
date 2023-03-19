#!/bin/bash
#
#  dockerized-website-time-machine-backup.sh - shell script template
#  for creating time-machine backups of a dockerized website
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

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$scriptdir/yaa-tools.sh" 2>/dev/null || \
    source "yaa-tools.sh" || exit 1
date=`date "+%Y%m%d-%H%M%S"`

include yaa-ssh-tricks-basic.sh
include yaa-rsync-tricks.sh
include yaa-dockerized-website-tricks.sh

finalize()
{
    echo "Finalizing..." 1>&2
    maintenance_mode_off
}

usage()
{
    echo "usage: $0 [[[--no-test] [--live]] | [-h]]"
}

test=1
live=0

while [ "$1" != "" ]; do
    [[ "$1" == --no-test ]] && test=0 && shift && continue
    [[ "$1" == --live ]] && live=1 && shift && continue

    [[ "$1" == -h || "$1" == --help ]] && usage && exit
    [[ "$1" == -* ]] && usage 1>&2 && exit 1

    shift
done

backuproot=${scriptdir:-./}
# backuproot="$backuproot/time-machines"
[ -d "$backuproot" ] || mkdir -p "$backuproot" || \
    die "Can't create backups directory $backuproot. Exiting."
backuproot="$( cd "$backuproot" && pwd )"

prepare_ssh_environment()
{
    host=192.168.56.161
    user=root
    ssh_port=22

    extra_ssh_options+=(-o UserKnownHostsFile="$HOME/hosts/samplehost/known_hosts")
    extra_ssh_options+=(-i "$HOME/hosts/zz-ids/sample_id_rsa")
    # extra_ssh_options+=(-o FingerprintHash=md5)

    # ssh_password_file=./donotusepasswords
    # extra_ssh_options+=(-o PreferredAuthentications=password -o PubkeyAuthentication=no)

    # extra_ssh_options+=(-o ProxyJump="user@jumphost:22")

    extra_ssh_options+=(-o ConnectTimeout=15)
    extra_ssh_options+=(-o Compression=yes)

    require build_ssh_command
    build_ssh_command
    test_ssh_command
}

prepare_ssh_environment

rsync_bwlimit="3000"
time_machine_dirprefix="."

remote_compose_project_dir=/srv/dc/nc
app_service_name=app
dbcontainername=nc-db
dbname=site_database_name

maintenance_mode_on

info "=== Performing backup of app data ==="

read -d '' app_excludes <<"EOF"
/data/updater-*/backups/*
/data/user/files/things*
/data/user/files/Music
/data/user/files/Музыка
/data/user/files/Videos
/data/user/files/Видео
/data/user/files/Documents
/data/user/files/Документы
EOF
time_machine_backup_remotedir "$remote_compose_project_dir/app/" "$app_excludes" app

test_ssh_docker_exec_command "$dbcontainername"

time_machine_dockerized_mysql_via_ssh "$dbname" "$dbcontainername"

sync

maintenance_mode_off
