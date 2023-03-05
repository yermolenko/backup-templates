#!/bin/bash
#
#  remote-directory-backup-over-sshfs.sh - shell script template for
#  time-machine or plain rsync-based backups of a remote directory
#  over sshfs
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
include yaa-rsync-over-sshfs-tricks.sh

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
# backuproot="$backuproot/time-machines"
[ -d "$backuproot" ] || mkdir -p "$backuproot" || \
    die "Can't create backups directory $backuproot. Exiting."
backuproot="$( cd "$backuproot" && pwd )"

prepare_ssh_environment()
{
    host=192.168.56.161
    user=user
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

read -d '' excludes <<"EOF"
*~
~$*
~WRL*.tmp
logins*.json
apps/firefox*/
apps/thunderbird*/
apps/mozilla-compat-libs*/
firefox*gz
thunderbird*gz
firefox*bz2
thunderbird*bz2
.mozilla*
.icedove*
.thunderbird*
.htaccess
.htpasswd
.stfolder
lost\+found
/.cache*
/_cache*
/.local/share/Trash
/.trash*
/_trash*
/.backup*
/backup*
/.яяbackup*
/яяbackup*
/.bak
/bak
/.thumbnails
/.config/gsmartcontrol
/.config/smplayer/file_settings
/.kde/share/apps/okular/docdata
/.local/share/meld
/.nv
/apps
/bin
/sbin
/.wine*
/.local
/.Skype
/.dropbox*
/Dropbox
/.yandex
/.config/yandex-disk
/Yandex.Disk
/.config/syncthing
/Sync
/things*
/Videos/*
/Pictures/*
/Music/*
/Public/*
/Templates/*
/Видео/*
/Изображения/*
/Картинки/*
/Музыка/*
/Общедоступные/*
/Шаблоны/*
/Личное
/личное
/Личная
/личная
/distrib
/vms
/VirtualBox\ VMs
/nspawn*
/snap
/apps/archive/
/.ssh*
/.recoll*
/.stardict
/.goldendict
/.icedove*
/.thunderbird*
/.mozilla*
EOF

info "=== Performing remote directory backup ==="
time_machine_backup_remotedir_over_sshfs "/home/user/" "$excludes" home_user
# plain_backup_remotedir_over_sshfs "/home/user/" "$excludes" home_user

sync

sleep 10
