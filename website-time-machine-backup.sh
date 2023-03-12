#!/bin/bash
#
#  website-time-machine-backup.sh - shell script template for
#  creating time-machine backups of a website
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
include yaa-website-tricks.sh

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

remote_is_bsd=0
# remote_is_bsd=1

dbname=site_database_name
dbuser=root
dbpassword='unused'

sitewwwroot="/var/www/html/"

maintenance_mode_on

info "=== Performing backup of wwwroot ==="

read -d '' wwwroot_excludes <<"EOF"
/tmp/*
EOF
time_machine_backup_remotedir "$sitewwwroot" "$wwwroot_excludes" wwwroot
# time_machine_backup_remotedir_via_sshfs "$sitewwwroot" "$wwwroot_excludes" wwwroot

if [ $live -eq 0 ]
then
    time_machine_sql_via_ssh "$dbname" "$dbuser" "$dbpassword"
else
    info "Skipping sql backup in 'live' mode"
fi

sync

sleep 10

maintenance_mode_off
