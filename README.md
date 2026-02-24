<img src=logo.png width=900> 

# LeaveNoTrace

By [infrar3d](https://github.com/Infrar3dd)

`leavenotrace.sh` is a Bash script designed to securely erase system logs, user history, temporary files, and other traces from a Linux system. The script aims to minimize recoverable traces by overwriting files with random data, shredding, and resetting timestamps

Usage:
```bash
leavenotrace.sh [options]
Options:
  -h | --help Print this message and exit
  -u | --username Target username (default is from whoami)
  -t | --time Time in minutes

  Example:
  leavenotrace.sh -u admin -u user1 -t 60 (It will clear logs from admin, user1 and this user)
  
```

## Features

- **System Log Cleaning**
  - Stops `rsyslog` and `auditd` services temporarily to safely clear logs.
  - Overwrites `.log`, `messages`, `syslog`, `secure`, `auth.log`, `kern.log` files.
  - Shreds binary logs such as `wtmp`, `btmp`, `lastlog` while maintaining permissions.
  - Cleans systemd journals (`journalctl`) and audit logs (`/var/log/audit`).
  - Cleans web server logs for Apache, Nginx, or HTTPD.

- **User History Cleaning**
  - Clears shell history for Bash, Zsh, and other command-line tools.
  - Overwrites history files with random data before deletion.
  - Cleans common configuration files (`.bashrc`, `.profile`, `.viminfo`, etc.).
  - Clears user cache and temporary files in home directories.

- **Temporary and System Trace Cleaning**
  - Cleans `/tmp`, `/var/tmp`, `/dev/shm` files based on modification time.
  - Cleans systemd journal cache.
  - Ensures recent temporary files are securely removed.

- **Memory Traces Clearing**
  - Clears page cache, dentries, and inodes.
  - Clears swap space if configured.

- **Current Session Cleaning**
  - Clears shell history for the current session.
  - Unsets history-related environment variables.

At first you need to root the machine and then you can clear traces after that

### ⚠️ Disclaimer ⚠️

This software and proof-of-concept code is provided **for educational and research purposes only**. 

*   The author (infrar3d) is **not responsible** for any misuse or damage caused by this program.
*   **Do not use** against any systems without explicit **prior permission**.
*   Use of this tools for attacking targets without consent is **illegal**.

You are responsible for obeying all applicable laws. **Use ethically and responsibly.**

