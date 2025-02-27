#!/bin/bash

# Global log file
LOG_FILE="/var/log/archl4tm.log"

# ANSI color codes for readability
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
GREEN="\e[32m"
RESET="\e[0m"

# Function to log messages with details
log_message() {
    local level="$1"
    local message="$2"
    local exit_code="${3:-0}"  # Default to 0 if not provided
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Get function name and line number
    local caller_info="${FUNCNAME[1]:-main}:${BASH_LINENO[0]:-0}"

    # Capture last command output if error
    local last_cmd_output=""
    if [[ "$level" == "ERROR" && "$exit_code" -ne 0 ]]; then
        last_cmd_output=$(journalctl -n 5 --no-pager 2>/dev/null)
    fi

    # Determine log level color
    local color=""
    case "$level" in
        INFO) color="$GREEN" ;;
        WARN) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        DEBUG) color="$BLUE" ;;
        *) color="$RESET" ;;
    esac

    # Format log message
    local log_entry="[$timestamp] [$level] [$caller_info] Exit Code: $exit_code - $message"

    # Append command output for errors
    if [[ "$level" == "ERROR" && "$last_cmd_output" != "" ]]; then
        log_entry+=" | Last Output: $last_cmd_output"
    fi

    # Print to terminal (with color)
    echo -e "${color}${log_entry}${RESET}"

    # Append to log file
    echo "$log_entry" >> "$LOG_FILE"
}

# Shortcut functions
log_debug() { log_message "DEBUG" "$1"; }
log_info() { log_message "INFO" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_error() { log_message "ERROR" "$1" "$?"; }

# Function to run commands and capture errors automatically
run() {
    "$@" 2>/tmp/last_command_output
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Command '$*' failed"
    fi
}
