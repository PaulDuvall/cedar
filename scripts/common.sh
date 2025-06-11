#!/bin/bash
# Common utilities for Cedar scripts
# Eliminates code duplication across shell scripts

set -euo pipefail

# Color definitions (eliminating duplication across scripts)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration management (externalize hardcoded values)
readonly DEFAULT_CEDAR_VERSION="4.4.1"
readonly DEFAULT_AWS_REGION="us-east-1"
readonly DEFAULT_TIMEOUT="30"

# Logging functions with consistent formatting
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_section() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Error handling utilities
check_command() {
    local command="$1"
    local error_msg="${2:-Command '$command' is required but not installed}"
    
    if ! command -v "$command" &> /dev/null; then
        log_error "$error_msg"
        return 1
    fi
}

# Safe execution with error handling
safe_execute() {
    local cmd="$1"
    local error_msg="${2:-Command failed: $cmd}"
    
    if ! eval "$cmd"; then
        log_error "$error_msg"
        return 1
    fi
}

# Configuration getters with environment variable support
get_cedar_version() {
    echo "${CEDAR_VERSION:-$DEFAULT_CEDAR_VERSION}"
}

get_aws_region() {
    echo "${AWS_REGION:-$DEFAULT_AWS_REGION}"
}

get_timeout() {
    echo "${TIMEOUT:-$DEFAULT_TIMEOUT}"
}

# Validation utilities
validate_file_exists() {
    local file="$1"
    local error_msg="${2:-File not found: $file}"
    
    if [[ ! -f "$file" ]]; then
        log_error "$error_msg"
        return 1
    fi
}

validate_directory_exists() {
    local dir="$1"
    local error_msg="${2:-Directory not found: $dir}"
    
    if [[ ! -d "$dir" ]]; then
        log_error "$error_msg"
        return 1
    fi
}

# Common path resolution
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
}

get_root_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
}

# Prerequisites checking
check_prerequisites() {
    local required_commands=("cedar" "aws")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! check_command "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_error "Please install the missing commands and try again"
        return 1
    fi
    
    log_info "All prerequisites installed ✓"
    return 0
}

# Platform detection for installation scripts
detect_platform() {
    local os
    local arch
    
    case "$(uname -s)" in
        Linux*)     os="unknown-linux-gnu";;
        Darwin*)    os="apple-darwin";;
        *)          log_error "Unsupported operating system"; return 1;;
    esac
    
    case "$(uname -m)" in
        x86_64*)    arch="x86_64";;
        arm64*)     arch="aarch64";;
        *)          log_error "Unsupported architecture"; return 1;;
    esac
    
    echo "${arch}-${os}"
}

# Export functions for use in other scripts
export -f log_info log_warning log_error log_section
export -f check_command safe_execute
export -f get_cedar_version get_aws_region get_timeout
export -f validate_file_exists validate_directory_exists
export -f get_script_dir get_root_dir
export -f check_prerequisites detect_platform