#!/bin/bash
# Fast Cedar CLI installation script that matches GitHub Actions
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

# Platform detection is now handled by common.sh

# Install using cargo-binstall (fastest method)
install_with_cargo_binstall() {
  log_info "Installing Cedar CLI with cargo-binstall..."
  
  # Install cargo-binstall if not present
  if ! check_command "cargo-binstall" "cargo-binstall not found, installing..."; then
    log_info "Installing cargo-binstall first..."
    local timeout
    timeout=$(get_timeout)
    
    if ! safe_execute "curl -L --proto '=https' --tlsv1.2 --max-time ${timeout} -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash" "Failed to install cargo-binstall"; then
      log_error "Could not install cargo-binstall"
      return 1
    fi
    
    # Source cargo environment
    if [[ -f "$HOME/.cargo/env" ]]; then
      # shellcheck source=/dev/null
      source "$HOME/.cargo/env"
    fi
  fi
  
  # Install Cedar CLI with error handling
  local cedar_version
  cedar_version=$(get_cedar_version)
  
  if ! safe_execute "cargo-binstall --no-confirm cedar-policy-cli@${cedar_version}" "Failed to install Cedar CLI with cargo-binstall"; then
    log_error "cargo-binstall installation failed"
    return 1
  fi
  
  return 0
}

# Install from pre-built binary (if available)
install_from_binary() {
  log_info "Attempting to install from pre-built binary..."
  
  # Get platform using common utility with error handling
  local platform
  if ! platform=$(detect_platform); then
    log_error "Platform detection failed"
    return 1
  fi
  
  # Use configuration management
  local cedar_version
  cedar_version=$(get_cedar_version)
  local timeout
  timeout=$(get_timeout)
  
  # Create temporary directory with error handling
  local temp_dir
  if ! temp_dir=$(mktemp -d); then
    log_error "Failed to create temporary directory"
    return 1
  fi
  
  # Ensure cleanup on exit
  trap "cd / && rm -rf '$temp_dir'" EXIT
  
  if ! cd "$temp_dir"; then
    log_error "Failed to change to temporary directory"
    return 1
  fi
  
  # Try to download binary with proper error handling
  local urls=(
    "https://github.com/cedar-policy/cedar/releases/download/v${cedar_version}/cedar-${platform}"
    "https://github.com/cedar-policy/cedar/releases/download/v${cedar_version}/cedar-policy-cli-${platform}"
  )
  
  for url in "${urls[@]}"; do
    log_info "Trying: $url"
    if safe_execute "curl -L -f --max-time ${timeout} -o cedar '$url'" "Failed to download from $url"; then
      if safe_execute "chmod +x cedar" "Failed to make binary executable"; then
        # Try to install to a location in PATH with fallback
        if safe_execute "sudo mv cedar /usr/local/bin/" "Failed to install to /usr/local/bin, trying user directory"; then
          return 0
        elif [[ -d "$HOME/.local/bin" ]] && safe_execute "mv cedar ~/.local/bin/" "Failed to install to ~/.local/bin"; then
          log_info "Installed to ~/.local/bin (ensure it's in your PATH)"
          return 0
        else
          log_error "Failed to install binary to any PATH location"
          return 1
        fi
      fi
    fi
  done
  
  log_warning "All binary download attempts failed"
  return 1
}

# Install using cargo (slowest but most reliable)
install_with_cargo() {
  log_info "Installing Cedar CLI with cargo (this may take 3-5 minutes)..."
  
  # Ensure Rust is installed
  if ! command -v cargo &> /dev/null; then
    log_info "Installing Rust first..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  fi
  
  cargo install cedar-policy-cli
}

# Main installation logic
main() {
  log_info "Fast Cedar CLI installation (matching GitHub Actions)"
  
  # Check if already installed
  if command -v cedar &> /dev/null; then
    log_info "Cedar CLI is already installed: $(cedar --version 2>&1)"
    exit 0
  fi
  
  # Try installation methods in order of speed
  log_info "Attempting fastest installation method..."
  
  # Method 1: Pre-built binary (fastest, but may not exist)
  if install_from_binary; then
    log_info "Successfully installed from pre-built binary!"
  # Method 2: cargo-binstall (fast, downloads pre-built if available)
  elif install_with_cargo_binstall; then
    log_info "Successfully installed with cargo-binstall!"
  # Method 3: cargo install (slow but reliable)
  else
    log_warn "Fast methods failed, falling back to cargo install..."
    install_with_cargo
  fi
  
  # Verify installation
  if command -v cedar &> /dev/null; then
    log_info "Cedar CLI installed successfully: $(cedar --version 2>&1)"
  else
    log_error "Cedar CLI installation failed!"
    exit 1
  fi
}

# Run main
main "$@"