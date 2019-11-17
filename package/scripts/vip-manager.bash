#! /usr/bin/env bash

# chkconfig: 2345 99 01
# description: Vip-manager daemon

### BEGIN INIT INFO
# Provides:          vip-manager
# Required-Start:    $network $local_fs $remote_fs
# Required-Stop:     $network $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start vip-manager at boot time
### END INIT INFO

# Command-line options that will be set with /etc/default/vip-manager.
VIP_OPTS=""

USER=root
GROUP=root

if [[ -r /lib/lsb/init-functions ]]; then
    source /lib/lsb/init-functions
fi

DEFAULT=/etc/default/vip-manager

if [[ -r ${DEFAULT} ]]; then
    source ${DEFAULT}
fi

if [[ -z "${VIP_IP}" ]]; then
    VIP_OPTS="${VIP_OPTS} -ip=${VIP_IP}"
fi

if [[ -z "${VIP_IFACE}" ]]; then
    VIP_OPTS="${VIP_OPTS} -iface=${VIP_IFACE}"
fi

if [[ -z "{$VIP_KEY}" ]]; then
    VIP_OPTS="${VIP_OPTS} -key={$VIP_KEY}"
fi

if [[ -z "${VIP_ETCD_USER}" ]]; then
    VIP_OPTS="${VIP_OPTS} -etcd_user=${VIP_ETCD_USER}"
fi

if [[ -z "${VIP_ETCD_PASSWORD}" ]]; then
    VIP_OPTS="${VIP_OPTS} -etcd_password=${VIP_ETCD_PASSWORD}"
fi

if [[ -z "${VIP_HOST}" ]]; then
    VIP_OPTS="${VIP_OPTS} -host=${VIP_HOST}"
fi

if [[ -z "${VIP_TYPE}" ]]; then
    VIP_OPTS="${VIP_OPTS} -type=${VIP_TYPE}"
fi

if [[ -z "${VIP_ENDPOINT}" ]]; then
    VIP_OPTS="${VIP_OPTS} -type=${VIP_ENDPOINT}"
fi

if [[ -z "${VIP_MASK}" ]]; then
    VIP_OPTS="${VIP_OPTS} -type=${VIP_MASK}"
fi

if [[ -z "${VIP_HOSTINGTYPE}" ]]; then
    VIP_OPTS="${VIP_OPTS} -hostingtype=${VIP_HOSTINGTYPE}"
fi

if [[ -z "${STDOUT}" ]]; then
    STDOUT=/dev/null
fi
if [[ ! -f "${STDOUT}" ]]; then
    mkdir -p `dirname ${STDOUT}`
fi

if [[ -z "${STDERR}" ]]; then
    STDERR=/var/log/vip-manager/vipm-anager.log
fi
if [[ ! -f "${STDERR}" ]]; then
    mkdir -p `dirname ${STDERR}`
fi

function pid_of_proc {
    if [[ $# -ne 2 ]]; then
        echo "Expected three arguments, e.g. $0 pid-file daemon-name"
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        return 1
    fi

    local pid_file=`cat $1`

    if [[ "x${pid_file}" == "x" ]]; then
        return 1
    fi

    if ps --pid "${pid_file}" | grep -q $(basename $2); then
        return 0
    fi

    return 1
}

function kill_proc {
    if [[ $# -ne 2 ]]; then
        echo "Expected three arguments, e.g. $0 pid-file signal"
        return 1
    fi

    pid=`cat $1`

    kill -s $2 ${pid}
}

function log_failure_msg {
    echo "$@" "[ FAILED ]"
}

function log_success_msg {
    echo "$@" "[ OK ]"
}

# Process name ( For display )
name=vip-manager

# Daemon name, where is the actual executable
daemon=/usr/bin/vip-manager

# pid file for the daemon
pid_file=/var/run/vip-manager.pid
pid_dir=`dirname ${pid_file}`

if [[ ! -d "${pid_dir}" ]]; then
    mkdir -p ${pid_dir}
    chown ${USER}:${GROUP} ${pid_dir}
fi

# If the daemon is not there, then exit.
[[ -x ${daemon} ]] || exit 5

case $1 in
    start)
        # Checked the PID file exists and check the actual status of process
        if [[ -e ${pid_file} ]]; then
            pid_of_proc ${pid_file} ${daemon} > /dev/null 2>&1 && status="0" || status="$?"
            # If the status is SUCCESS then don't need to start again.
            if [[ "x${status}" = "x0" ]]; then
                log_failure_msg "${name} process is running"
                exit 0 # Exit
            fi
        fi

        log_success_msg "Starting the process" "${name}"
        if command -v startproc >/dev/null; then
            startproc -u "${USER}" -g "${GROUP}" -p "${pid_file}" -q -- "${daemon}" ${VIP_OPTS}
        elif which start-stop-daemon > /dev/null 2>&1; then
            start-stop-daemon --chuid ${USER}:${GROUP} --start --quiet --pidfile ${pid_file} --exec ${daemon} -- ${VIP_OPTS} >>${STDOUT} 2>>${STDERR} &
        else
            su -s /bin/sh -c "nohup ${daemon} ${VIP_OPTS} >>${STDOUT} 2>>${STDERR} &" ${USER}
        fi
        log_success_msg "${name} process was started"
        ;;

    stop)
        # Stop the daemon.
        if [[ -e ${pid_file} ]]; then
            pid_of_proc ${pid_file} ${daemon} > /dev/null 2>&1 && status="0" || status="$?"
            if [[ "$status" = 0 ]]; then
                if kill_proc ${pid_file} SIGTERM && /bin/rm -rf ${pid_file}; then
                    log_success_msg "${name} process was stopped"
                else
                    log_failure_msg "${name} failed to stop service"
                fi
            fi
        else
            log_failure_msg "${name} process is not running"
        fi
        ;;

    restart|force-reload)
        # Restart the daemon.
        $0 stop && sleep 2 && $0 start
        ;;

    status)
        # Check the status of the process.
        if [[ -e ${pid_file} ]]; then
            if pid_of_proc ${pid_file} ${daemon} > /dev/null; then
                log_success_msg "${name} Process is running"
                exit 0
            else
                log_failure_msg "${name} Process is not running"
                exit 1
            fi
        else
            log_failure_msg "${name} Process is not running"
            exit 3
        fi
        ;;

    version)
        ${daemon} version
        ;;

    *)
        # For invalid arguments, print the usage message.
        echo "Usage: $0 {start|stop|restart|status|version}"
        exit 2
        ;;
esac
