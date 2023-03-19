#!/bin/bash
#
#  website-time-machine-restore.sh - shell script template for
#  restoring a website from its backup
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

backuptag=20230312-153000

remote_is_bsd=0
# remote_is_bsd=1

dbuser=root
dbpassword='unused'

sitewwwroot="/var/www/html/"

sitedbname=restored_site_database_name
sitedbuser=restored_site_database_username
sitedbpassword='ihgfedcba'

maintenance_mode_on
set_wwwroot_owner_to_an_ordinary_user

read -d '' restore_excludes <<"EOF"
/sites/default/files/tmp/*
EOF

RSYNC_RSH="${ssh_command_wo_user_at_host[@]}" \
         rsync_restore "$backuproot/wwwroot/$time_machine_dirprefix$backuptag/" "$user@$host:$sitewwwroot" "$restore_excludes"

if [ $test -eq 1 ]
then
    info "DRY RUN of patching restored directories"
else
    require_var sitewwwroot

    require_var sitedbname
    require_var sitedbuser
    require_var sitedbpassword

    run_via_ssh chmod +w "$sitewwwroot/sites/default/" "$sitewwwroot/sites/default/settings.php" || \
        die "Cannot chmod settings.php"

    sed_i_arg="-i.orig"
    [ $remote_is_bsd -eq 1 ] && \
        sed_i_arg="-i .orig"

    # TODO: make the following sed call work with run_via_ssh_sh_c()
    # note: the double quoted sed expression is incompatible with run_via_ssh_sh_c()
    # run_via_ssh_sh_c sed "$sed_i_arg" "s/\'database\'\ \=\>\ \'original\.site\.database\.name\'/\'database\'\ \=\>\ \'$sitedbname\'/g" "$sitewwwroot/sites/default/settings.php" || \
    #     die "Cannot modify settings.php"

    run_via_ssh sed "$sed_i_arg" "s/\'database\'\ \=\>\ \'site_database_name_in_the_backup\'/\'database\'\ \=\>\ \'$sitedbname\'/g" "$sitewwwroot/sites/default/settings.php" || \
        die "Cannot modify settings.php"

    run_via_ssh sed "$sed_i_arg" "s/\'username\'\ \=\>\ \'site_database_username_in_the_backup\'/\'username\'\ \=\>\ \'$sitedbuser\'/g" "$sitewwwroot/sites/default/settings.php" || \
        die "Cannot modify settings.php"

    run_via_ssh sed "$sed_i_arg" "s/\'password\'\ \=\>\ \'abcdefghi\'/\'password\'\ \=\>\ \'$sitedbpassword\'/g" "$sitewwwroot/sites/default/settings.php" || \
        die "Cannot modify settings.php"

    if [ $remote_is_bsd -eq 0 ] # the following commands may not work on FreeBSD
    then
        # echo "s/\\\$conf\\['memcache_servers'\\] = /\#\\\$conf\\['memcache_servers'\\] = /g" |
        #     run_via_ssh sed "$sed_i_arg" -f - "$sitewwwroot/sites/default/settings.php" || \
        #     die "Cannot modify settings.php"

        echo "s/Options +FollowSymLinks/\Options +SymLinksIfOwnerMatch/g" |
            run_via_ssh sed "$sed_i_arg" -f - \
                        "$sitewwwroot/sites/default/files/translations/.htaccess" \
                        "$sitewwwroot/sites/default/files/tmp/.htaccess" \
                        "$sitewwwroot/sites/default/files/.htaccess" \
                        "$sitewwwroot/.htaccess" || \
            info "WARNING: Cannot modify some of .htaccess files"
    fi

    run_via_ssh rm "$sitewwwroot/sites/default/settings.php.orig"

    run_via_ssh chmod -w "$sitewwwroot/sites/default/" "$sitewwwroot/sites/default/settings.php" || \
        die "Cannot chmod settings.php"

    run_via_ssh patch -d "$sitewwwroot/sites/all/modules/imageapi" < "$backuproot/imageapi.patch" || \
        info "Cannot patch imageapi"
fi

sql_restore_via_ssh "$sitedbname" "$backuproot/sql/site_database_name_in_the_backup-$backuptag.sql"

# sql_creates_database=1
# sql_restore_via_ssh "$sitedbname" "$backuproot/sql_from_webpanel/site_database_backup.sql"

sync

sleep 10

set_wwwroot_owner_to_www_user
maintenance_mode_off
