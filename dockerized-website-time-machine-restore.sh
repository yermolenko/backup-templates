#!/bin/bash
#
#  dockerized-website-time-machine-restore.sh - shell script template for
#  restoring a dockerized website from its backup
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
    echo "Note: I will not switch maintenance_mode off" 1>&2
    # maintenance_mode_off
}

usage()
{
    echo "usage: $0 [[[--no-test]] | [-h]]"
}

test=1

while [ "$1" != "" ]; do
    [[ "$1" == --no-test ]] && test=0 && shift && continue

    [[ "$1" == -h || "$1" == --help ]] && usage && exit
    [[ "$1" == -* ]] && usage 1>&2 && exit 1

    shift
done

backuproot=${scriptdir:-./}
cd "$backuproot" || die "Cannot cd to backuproot: $backuproot"
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
    perform_extra_ssh_command_tests
}

prepare_ssh_environment

rsync_bwlimit="3000"
time_machine_dirprefix="."

backuptag=20230319-153000
sql_filename_prefix=site_database_name

remote_compose_project_dir=/srv/dc/nc

run_via_ssh "cd $remote_compose_project_dir" || die "Cannot cd to remote project directory"
run_via_ssh "cd $remote_compose_project_dir && source ./.env && echo \"COMPOSE_PROJECT_NAME: \${COMPOSE_PROJECT_NAME}\"" || \
    die "Cannot read .env int remote project directory"

if [ $test -eq 1 ]
then
    info "DRY RUN of docker compose down"
else
    run_via_ssh "cd $remote_compose_project_dir && docker compose down" || die "docker fail"
fi

sleep 3

run_via_ssh "[ -e \"$remote_compose_project_dir/app\" ]" && \
    die "app data directory exists on the remote machine. Remove it first"

if [ $test -eq 1 ]
then
    info "DRY RUN of docker volume rm"
else
    run_via_ssh "cd $remote_compose_project_dir && source ./.env && docker volume rm \${COMPOSE_PROJECT_NAME}_db \${COMPOSE_PROJECT_NAME}_nc"
fi

run_via_ssh "cd $remote_compose_project_dir && docker volume ls" || die "docker fail"

sleep 3

read -d '' restore_excludes <<"EOF"
/nothingisexcluded/*
EOF

RSYNC_RSH="${ssh_command_wo_user_at_host[@]}" \
         rsync_restore \
         "$backuproot/app/$time_machine_dirprefix$backuptag/" \
         "$user@$host:$remote_compose_project_dir/app/" \
         "$restore_excludes"

sleep 3

if [ $test -eq 1 ]
then
    info "DRY RUN of fixing app dir permissions"
else
    run_via_ssh  "cd $remote_compose_project_dir && \
[ -d ./app ] && \
chown -R www-data:www-data ./app && \
chown root:root ./app && \
chown -R www-data:root ./app/config && \
chown www-data:www-data ./app/config/config.php && \
chown -R www-data:root ./app/custom_apps && \
chown www-data:root ./app/data && \
chown -R www-data:root ./app/themes" || \
    die "Can't fix app dir permissions. Exiting."
fi

if [ $test -eq 1 ]
then
    info "DRY RUN of preparing docker-entrypoint-initdb.d"
else
    run_via_ssh "cd $remote_compose_project_dir && \
[ -d ./docker-entrypoint-initdb.d ] || mkdir -p ./docker-entrypoint-initdb.d" || \
        die "Can't create docker-entrypoint-initdb.d dir. Exiting."

    RSYNC_RSH="${ssh_command_wo_user_at_host[@]}" \
             rsync_restore \
             "$backuproot/db/$sql_filename_prefix-$backuptag.sql" \
             "$user@$host:$remote_compose_project_dir/docker-entrypoint-initdb.d/$sql_filename_prefix-$backuptag.sql"
fi

sync

sleep 10

if [ $test -eq 1 ]
then
    info "DRY RUN of docker compose pull and docker compose up -d"
else
    # run_via_ssh "cd $remote_compose_project_dir && docker compose pull" || die "docker fail"
    run_via_ssh "cd $remote_compose_project_dir && docker compose up -d" || die "docker fail"
fi
