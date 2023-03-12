#!/bin/bash
#
#  yaa-website-tricks.sh - various website maintenance tricks
#
#  Copyright (C) 2019, 2020, 2021, 2022, 2023 Alexander Yermolenko
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

run_mysql_command_via_ssh()
{
    local mysql_command=${1:?mysql_command is required}

    require_var ssh_command
    require_var dbuser
    require_var dbpassword

    local sh_c_command=()

    info "=== Executing mysql command via ssh:"

    sh_c_command=(
        'MYSQL_PWD="'"$dbpassword"'" mysql -u "'"$dbuser"'" '
    )

    info "Command for remote 'sh -c' will be:"
    info "${sh_c_command[@]}"

    info "Command for remote mysql will be:"
    info "${mysql_command[@]}"

    info "Running the command ..."
    echo "$mysql_command" |
        "${ssh_command[@]}" \
            sh -c \
            "'"${sh_c_command[@]}"'"
}

time_machine_sql_via_ssh()
{
    local backup_item_name=sql

    local dbname=${1:?dbname dir is required}
    local dbuser=${2:?dbuser is required}
    local dbpassword=${3:?dbpassword is required}

    require_var backuproot
    require_var date
    require_var ssh_command

    info "=== DB Backup via SSH ==="
    info "backuproot: $backuproot"
    info "dbname: $dbname"
    info "dbuser: $dbuser"
    info "dbpassword: $dbpassword"

    [ -d "$backuproot/$backup_item_name" ] || mkdir -p "$backuproot/$backup_item_name" || \
        die "Can't create destination dir. Exiting."

    local sh_c_command=()

    if [ $test -eq 1 ]
    then
        info "DRY RUN of sql backup"

        info "=== Testing mysql ==="

        read -d '' mysql_command <<EOF
SELECT \"Hello World!\"
EOF
        run_mysql_command_via_ssh "$mysql_command" || die "Cannot test mysql"
    else
        info "=== Performing mysqldump ==="
        info "database $dbname -> $backuproot/$backup_item_name/$dbname-$date.sql"

        local default_character_set=utf8mb4

        sh_c_command=(
            'MYSQL_PWD="'"$dbpassword"'" mysqldump -u "'"$dbuser"'" --single-transaction --default-character-set='"$default_character_set"' '"$dbname"' '
        )

        quiet_mode=1 \
                  run_via_ssh_sh_c "${sh_c_command[@]}" \
                  > "$backuproot/$backup_item_name/$dbname-$date.sql" \
                  2>"$backuproot/$backup_item_name/$dbname-$date.stderr" && \
            info "Backup completed successfully." && \
            touch "$backuproot/$backup_item_name/$dbname-$date.completed" && \
            info "Backup completed successfully. Everything is OK" || \
                die "Cannot make database dump"
    fi
}

sql_creates_database=0

sql_restore_via_ssh()
{
    local dbname=${1:?dbname dir is required}
    local sql_backup_file=${2:?sql_backup_file is required}

    require_var ssh_command
    require_var dbuser
    require_var dbpassword
    require_var sitedbuser
    require_var sitedbpassword

    info "=== DB Restore via SSH ==="
    info "sql_backup_file: $sql_backup_file"
    info "dbname: $dbname"

    if [ $test -eq 1 ]
    then
        # Dry Run
        info "DRY RUN: $sql_backup_file -> remote database $dbname"

        info "=== Testing mysql ==="

        read -d '' mysql_command <<EOF
SELECT \"Hello World!\"
EOF
        run_mysql_command_via_ssh "$mysql_command" || die "Cannot test mysql"
    else
        [ -e "$sql_backup_file" ] || \
            die "Can't find sql file: $sql_backup_file. Exiting."

        info "Performing DB Restore: $sql_backup_file -> remote database $dbname"

        # dropping database

        read -d '' mysql_command <<EOF
DROP DATABASE \`$dbname\`
EOF
        run_mysql_command_via_ssh "$mysql_command"

        if flag_is_unset sql_creates_database;
        then
            # creating database

            read -d '' mysql_command <<EOF
CREATE DATABASE \`$dbname\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
EOF
            run_mysql_command_via_ssh "$mysql_command" || die "Cannot test mysql"
        fi

        # dropping user

        read -d '' mysql_command <<EOF
DROP USER \`$sitedbuser\`@\'localhost\'
EOF
        run_mysql_command_via_ssh "$mysql_command"

        # creating user

        read -d '' mysql_command <<EOF
CREATE USER \`$sitedbuser\`@\'localhost\' IDENTIFIED BY \'$sitedbpassword\'
EOF
        run_mysql_command_via_ssh "$mysql_command" || die "Cannot test mysql"

        # granting privileges

        read -d '' mysql_command <<EOF
GRANT ALL PRIVILEGES on \`$dbname\`.* to \`$sitedbuser\`@\'localhost\'
EOF
        run_mysql_command_via_ssh "$mysql_command" || die "Cannot test mysql"

        # flushing privileges

        read -d '' mysql_command <<EOF
FLUSH privileges
EOF
        run_mysql_command_via_ssh "$mysql_command" || die "Cannot test mysql"

        # filling database

        if flag_is_unset sql_creates_database;
        then
            info "=== Importing sql dump ..."

            sh_c_command=(
                'MYSQL_PWD="'"$dbpassword"'" mysql -u "'"$dbuser"'" '"$dbname"' '
            )
        else
            info "=== Importing sql dump with database creation ..."

            sh_c_command=(
                'MYSQL_PWD="'"$dbpassword"'" mysql -u "'"$dbuser"'" '
            )
        fi

        run_via_ssh_sh_c "${sh_c_command[@]}" < "$sql_backup_file" || \
            die "Cannot restore database $dbname contents"

        # info "command for remote 'sh -c' will be:"
        # info "${sh_c_command[@]}"

        # info "running the command via ssh ..."
        # "${ssh_command[@]}" \
        #     sh -c \
        #     "'"${sh_c_command[@]}"'" < "$sql_backup_file" || \
        #     die "Cannot restore database $dbname contents"
    fi
}

maintenance_mode_on()
{
    info "=== Putting site in maintenance mode ==="

    if [ $remote_is_bsd -eq 1 ]
    then
        run_via_ssh 'su root -c "id && echo id success"' || die "Cannot test \"su root -c\""
    fi

    if [ $test -eq 1 ]
    then
        info "DRY RUN of Putting site in maintenance mode"
    else
        if [ $remote_is_bsd -eq 0 ]
        then
            run_via_ssh 'service apache2 stop' || die "Cannot stop apache"
        else
            run_via_ssh 'su root -c "/usr/local/etc/rc.d/apache24 stop"' || die "Cannot stop apache"
        fi
    fi
}

maintenance_mode_off()
{
    info "=== Putting site back to normal mode ==="

    if [ $test -eq 1 ]
    then
        info "DRY RUN of Putting site back to normal mode"
    else
        if [ $remote_is_bsd -eq 0 ]
        then
            run_via_ssh 'service apache2 start' || die "Cannot start apache"
        else
            run_via_ssh 'su root -c "/usr/local/etc/rc.d/apache24 start"' || die "Cannot start apache"
        fi
    fi
}

set_wwwroot_owner_to_an_ordinary_user()
{
    info "=== Changing wwwroot owner to user ==="

    require_var sitewwwroot

    if [ $remote_is_bsd -eq 1 ]
    then
        run_via_ssh 'su root -c "id && echo id success"' || die "Cannot test \"su root -c\""
    fi

    if [ $test -eq 1 ]
    then
        info "DRY RUN of Changing wwwroot owner to user"
    else
        if [ $remote_is_bsd -eq 0 ]
        then
            info "nop"

            # run_via_ssh chown -R "$user" "$sitewwwroot" || \
            #     die "Cannot fix wwwroot directory permissions"
        else
            info "TODO: parameterize chown args"
            run_via_ssh 'su root -c "chown -R ORDINARYUSERNAME /usr/local/www/apache24/sites/WEB.SITE.NAME.PLACEHOLDER"' || die "Cannot chown wwwroot"
        fi
    fi
}

set_wwwroot_owner_to_www_user()
{
    info "=== Changing wwwroot owner to www user ==="

    require_var sitewwwroot

    if [ $test -eq 1 ]
    then
        info "DRY RUN of Changing wwwroot owner to www user"
    else
        if [ $remote_is_bsd -eq 0 ]
        then
            run_via_ssh chown -R www-data:www-data "$sitewwwroot" || \
                die "Cannot fix wwwroot directory permissions"
        else
            info "TODO: parameterize chown args"
            run_via_ssh 'su root -c "chown -R www:www /usr/local/www/apache24/sites/WEB.SITE.NAME.PLACEHOLDER"' || die "Cannot chown wwwroot"
        fi
    fi
}

# echo "yaa-website-tricks.sh is a library"
