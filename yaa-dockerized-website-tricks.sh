#!/bin/bash
#
#  yaa-dockerized-website-tricks.sh - various dockerized website
#  maintenance tricks
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

run_via_ssh_docker_exec_sh_c()
{
    local container=${1:?Container name is required}
    shift

    local sh_c_command=("$@")

    # TODO: passing double-quoted expressions with quoted singe quotes may not work

    require_var ssh_command

    info "=== Executing command via ssh:"

    info "Command is an array of ${#sh_c_command[@]} elements"

    info "Command for remote 'sh -c' will be:"
    info "${sh_c_command[@]}"

    info "Running the command ..."
    "${ssh_command[@]}" \
        docker exec "$container" sh -c \
        "'"${sh_c_command[@]}"'"
}

run_via_ssh_docker_exec()
{
    local container=${1:?Container name is required}
    shift

    local command=("$@")

    require_var ssh_command

    info "=== Executing command via ssh:"

    info "Command is an array of ${#command[@]} elements"

    info "Command for ssh will be:"
    info "${command[@]}"

    info "Running the command ..."
    "${ssh_command[@]}" \
        docker exec "$container" \
        "${command[@]}"
}

test_ssh_docker_exec_command()
{
    local container=${1:?Container name is required}

    require_var ssh_command
    info "ssh_command array: ${ssh_command[@]}"

    info "container: $container"

    echo -n "Testing ssh docker exec ... "
    "${ssh_command[@]}" docker exec "$container" hostname || die "Cannot test ssh"
}

run_mysql_command_via_ssh_docker_exec()
{
    local container=${1:?Container name is required}
    shift

    local mysql_command=${1:?mysql_command is required}

    local sh_c_command=(mysql -uroot '-p"$MYSQL_ROOT_PASSWORD"')

    info "=== Executing mysql command via ssh:"

    info "Command for remote 'sh -c' will be:"
    info "${sh_c_command[@]}"

    info "Command for remote mysql will be:"
    info "${mysql_command[@]}"

    info "Running the command ..."
    echo "$mysql_command" |
        "${ssh_command[@]}" \
            docker exec -i "$container" sh -c \
            "'"${sh_c_command[@]}"'"
}

time_machine_dockerized_mysql_via_ssh()
{
    local backup_item_name=db

    local dbname=${1:?dbname dir is required}
    local container=${2:?Container name is required}

    require_var backuproot
    require_var date
    require_var ssh_command

    info "=== Dockerized DB Backup via SSH ==="
    info "backuproot: $backuproot"
    info "dbname: $dbname"
    info "container: $container"

    [ -d "$backuproot/$backup_item_name" ] || mkdir -p "$backuproot/$backup_item_name" || \
        die "Can't create destination dir. Exiting."

    local sh_c_command=()

    if [ $test -eq 1 ]
    then
        info "DRY RUN of sql backup"

        info "=== Testing mysql ==="

        sh_c_command=(
            'mysqldump --version && '
            "echo \"variable dbname is substituted by '$dbname' in the local shell (Example 1)\" && "
            'echo "variable dbname is substituted by '\'"$dbname"\'' in the local shell (Example 2)" && '
            'echo "variable MYSQL_ROOT_PASSWORD is substituted by $MYSQL_ROOT_PASSWORD ("$MYSQL_ROOT_PASSWORD") only inside db container" && '
            'echo "\`hostname\`: `hostname`" && '
            'echo "\$(hostname): $(hostname)" && '
            'echo OKKKK'
        )

        # This may not work in plain sh, use with caution
        # 'echo "\`hostname\`: `hostname`" && '
        # 'echo "\$\(hostname\): $(hostname)" && '

        run_via_ssh_docker_exec_sh_c "$container" "${sh_c_command[@]}" || die "Cannot test mysql"

        read -d '' mysql_command <<EOF
SELECT \"Hello World!\"
EOF
        run_mysql_command_via_ssh_docker_exec "$container" "$mysql_command" || die "Cannot test mysql"
    else
        info "=== Performing mysqldump ==="
        info "database $dbname -> $backuproot/$backup_item_name/$dbname-$date.sql"

        local default_character_set=utf8mb4

        sh_c_command=(
            'exec mysqldump -uroot --single-transaction --default-character-set='"$default_character_set"' '"$dbname"' -uroot -p"$MYSQL_ROOT_PASSWORD"'
        )

        quiet_mode=1 \
                  run_via_ssh_docker_exec_sh_c "$container" "${sh_c_command[@]}" \
                  > "$backuproot/$backup_item_name/$dbname-$date.sql" \
                  2>"$backuproot/$backup_item_name/$dbname-$date.stderr" && \
            info "Backup completed successfully." && \
            touch "$backuproot/$backup_item_name/$dbname-$date.completed" && \
            info "Backup completed successfully. Everything is OK" || \
                die "Cannot make database dump"
    fi
}

maintenance_mode_on()
{
    info "=== Putting site in maintenance mode ==="

    if [ $test -eq 1 ]
    then
        info "DRY RUN of Putting site in maintenance mode"
    else
        run_via_ssh "cd $remote_compose_project_dir && docker compose stop $app_service_name" || \
            die "Cannot put site in maintenance mode"
    fi
}

maintenance_mode_off()
{
    info "=== Putting site back to normal mode ==="

    if [ $test -eq 1 ]
    then
        info "DRY RUN of Putting site back to normal mode"
    else
        run_via_ssh "cd $remote_compose_project_dir && docker compose start $app_service_name" || die "Cannot put site back to normal mode"
    fi
}

# echo "yaa-dockerized-website-tricks.sh is a library"
