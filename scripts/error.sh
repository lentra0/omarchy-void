#!/bin/bash

# Ultra-powerful error handler for Void Linux setup scripts
# Features: stack traces, timing, retry logic, debug shell, package diagnostics

set -Euo pipefail

# ============================================
# COLOR AND FORMATTING DEFINITIONS
# ============================================
readonly RED='\033[0;31m'
readonly RED_BG='\033[41m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly UNDERLINE='\033[4m'
readonly BLINK='\033[5m'
readonly REVERSE='\033[7m'

# ============================================
# GLOBAL STATE VARIABLES
# ============================================
declare -g ERROR_OCCURRED=0
declare -g ERROR_LINE=""
declare -g ERROR_FILE=""
declare -g ERROR_CMD=""
declare -g ERROR_CODE=""
declare -g CURRENT_MODULE=""
declare -g SCRIPT_START_TIME
declare -g LAST_COMMAND_START_TIME
declare -g LAST_COMMAND_DURATION=0
declare -g MODULE_START_TIME
declare -g MODULE_DURATION=0
declare -a CALL_STACK=()
declare -g DEBUG_MODE=${DEBUG_MODE:-0}
declare -g VERBOSE=${VERBOSE:-0}

# ============================================
# TIMING FUNCTIONS
# ============================================

# Get current timestamp in seconds with nanosecond precision
current_timestamp() {
  date +%s.%N
}

# Calculate elapsed time
calculate_duration() {
  local start="$1"
  local end="$2"
  echo "$end - $start" | bc
}

# Format duration for display
format_duration() {
  local seconds="$1"

  if (($(echo "$seconds < 0.001" | bc -l))); then
    printf "%.0fμs" "$(echo "$seconds * 1000000" | bc)"
  elif (($(echo "$seconds < 1" | bc -l))); then
    printf "%.0fms" "$(echo "$seconds * 1000" | bc)"
  elif (($(echo "$seconds < 60" | bc -l))); then
    printf "%.2fs" "$seconds"
  elif (($(echo "$seconds < 3600" | bc -l))); then
    local minutes=$(echo "$seconds / 60" | bc)
    local remaining=$(echo "$seconds - ($minutes * 60)" | bc)
    printf "%dm %.2fs" "$minutes" "$remaining"
  else
    local hours=$(echo "$seconds / 3600" | bc)
    local minutes=$(echo "($seconds - ($hours * 3600)) / 60" | bc)
    local remaining=$(echo "$seconds - ($hours * 3600) - ($minutes * 60)" | bc)
    printf "%dh %dm %.2fs" "$hours" "$minutes" "$remaining"
  fi
}

# ============================================
# LOGGING FUNCTIONS
# ============================================

# Log levels
log_debug() {
  [ "$DEBUG_MODE" -eq 1 ] && echo -e "${GRAY}[DEBUG]${NC} $*" >&2
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

# ============================================
# INITIALIZATION
# ============================================
SCRIPT_START_TIME=$(current_timestamp)

# ============================================
# SIGNAL HANDLERS
# ============================================

# Handle interrupts
handle_interrupt() {
  local signal=$1
  log_warning "Received $signal signal"

  # Show current module if running
  if [ -n "$CURRENT_MODULE" ]; then
    log_warning "Interrupted module: $CURRENT_MODULE"

    # Calculate module duration
    local module_end_time=$(current_timestamp)
    MODULE_DURATION=$(calculate_duration "$MODULE_START_TIME" "$module_end_time")
    log_info "Module ran for $(format_duration $MODULE_DURATION)"
  fi

  # Show total script runtime
  local script_end_time=$(current_timestamp)
  local total_duration=$(calculate_duration "$SCRIPT_START_TIME" "$script_end_time")
  log_info "Total script runtime: $(format_duration $total_duration)"

  exit 130
}

trap 'handle_interrupt SIGINT' SIGINT
trap 'handle_interrupt SIGTERM' SIGTERM

# ============================================
# ERROR HANDLER CORE
# ============================================

# Main error handler function
main_error_handler() {
  local line="$1"
  local command="$2"
  local file="${3##*/}"
  local exit_code="$4"

  # Save error details
  ERROR_OCCURRED=1
  ERROR_LINE="$line"
  ERROR_FILE="$file"
  ERROR_CMD="$command"
  ERROR_CODE="$exit_code"

  # Calculate command duration
  local command_end_time=$(current_timestamp)
  LAST_COMMAND_DURATION=$(calculate_duration "$LAST_COMMAND_START_TIME" "$command_end_time")

  # Build call stack
  CALL_STACK=()
  local frame=0
  while caller $frame >/dev/null 2>&1; do
    CALL_STACK+=("$(caller $frame)")
    ((frame++))
  done

  # Display error banner
  show_error_banner

  # Display error details
  show_error_details

  # Show call stack if available
  if [ ${#CALL_STACK[@]} -gt 0 ]; then
    show_call_stack
  fi

  # Show system information
  show_system_info

  # Show package diagnostics if relevant
  if [[ "$ERROR_CMD" =~ xbps-install ]]; then
    show_package_diagnostics "$ERROR_CMD"
  fi

  # Show environment variables if in debug mode
  if [ "$DEBUG_MODE" -eq 1 ]; then
    show_environment_info
  fi

  # Interactive action menu
  show_action_menu
}

# Set trap for ERR signal
trap 'main_error_handler ${LINENO} "$BASH_COMMAND" "${BASH_SOURCE[0]}" $?' ERR

# ============================================
# DISPLAY FUNCTIONS
# ============================================

show_error_banner() {
  echo -e "\n${RED_BG}${WHITE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED_BG}${WHITE}${BOLD}║                    CRITICAL ERROR DETECTED                   ║${NC}"
  echo -e "${RED_BG}${WHITE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

show_error_details() {
  echo -e "\n${BOLD}${WHITE}ERROR DETAILS:${NC}"
  echo -e "${DIM}────────────────────────────────────────────────${NC}"

  if [ -n "$CURRENT_MODULE" ]; then
    echo -e "  ${CYAN}▸ Module:${NC} ${BOLD}$CURRENT_MODULE${NC}"
    echo -e "  ${CYAN}▸ Module runtime:${NC} $(format_duration $MODULE_DURATION)"
  fi

  echo -e "  ${CYAN}▸ File:${NC}   ${YELLOW}$ERROR_FILE${NC}"
  echo -e "  ${CYAN}▸ Line:${NC}   ${RED}${BOLD}$ERROR_LINE${NC}"
  echo -e "  ${CYAN}▸ Exit code:${NC} ${RED}$ERROR_CODE${NC}"
  echo -e "  ${CYAN}▸ Command runtime:${NC} $(format_duration $LAST_COMMAND_DURATION)"

  if [ -n "$ERROR_CMD" ] && [ "$ERROR_CMD" != "false" ]; then
    echo -e "  ${CYAN}▸ Failed command:${NC}"
    echo -e "    ${RED}$ERROR_CMD${NC}"
  fi
}

show_call_stack() {
  echo -e "\n${BOLD}${WHITE}CALL STACK TRACE:${NC}"
  echo -e "${DIM}────────────────────────────────────────────────${NC}"

  for ((i = 0; i < ${#CALL_STACK[@]}; i++)); do
    local stack_entry="${CALL_STACK[$i]}"
    local stack_line=$(echo "$stack_entry" | awk '{print $1}')
    local stack_func=$(echo "$stack_entry" | awk '{print $2}')
    local stack_file=$(echo "$stack_entry" | awk '{print $3}' | xargs basename 2>/dev/null || echo "$stack_entry" | awk '{print $3}')

    if [ $i -eq 0 ]; then
      echo -e "  ${RED}${BOLD}→${NC} ${RED}Line $stack_line${NC} in ${YELLOW}$stack_file${NC} (${MAGENTA}$stack_func${NC})"
    else
      echo -e "  ${DIM}$(printf '%2d' $i))${NC} Line $stack_line in ${DIM}$stack_file${NC} (${DIM}$stack_func${NC})"
    fi
  done
}

show_system_info() {
  echo -e "\n${BOLD}${WHITE}SYSTEM INFORMATION:${NC}"
  echo -e "${DIM}────────────────────────────────────────────────${NC}"

  echo -e "  ${CYAN}▸ User:${NC} $(whoami)"
  echo -e "  ${CYAN}▸ UID/GID:${NC} $(id -u)/$(id -g)"
  echo -e "  ${CYAN}▸ Shell:${NC} $SHELL"

  # Get distribution info
  if [ -f /etc/os-release ]; then
    local distro_name=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    local distro_id=$(grep ^ID= /etc/os-release | cut -d= -f2)
    local distro_version=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
    echo -e "  ${CYAN}▸ Distribution:${NC} $distro_name ($distro_id $distro_version)"
  elif [ -f /etc/void-release ]; then
    echo -e "  ${CYAN}▸ Distribution:${NC} Void Linux"
  else
    echo -e "  ${CYAN}▸ Distribution:${NC} $(uname -o)"
  fi

  echo -e "  ${CYAN}▸ Kernel:${NC} $(uname -r)"
  echo -e "  ${CYAN}▸ Architecture:${NC} $(uname -m)"
  echo -e "  ${CYAN}▸ Working directory:${NC} $(pwd)"
  echo -e "  ${CYAN}▸ Home directory:${NC} $HOME"

  # Check sudo access
  if sudo -n true 2>/dev/null; then
    echo -e "  ${CYAN}▸ Sudo access:${NC} ${GREEN}Available${NC}"
  else
    echo -e "  ${CYAN}▸ Sudo access:${NC} ${RED}Not available${NC}"
  fi

  # Check available memory
  if command -v free >/dev/null 2>&1; then
    local mem_total=$(free -h | grep Mem: | awk '{print $2}')
    local mem_used=$(free -h | grep Mem: | awk '{print $3}')
    echo -e "  ${CYAN}▸ Memory:${NC} $mem_used/$mem_total used"
  fi

  # Check disk space
  if command -v df >/dev/null 2>&1; then
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}')
    echo -e "  ${CYAN}▸ Disk usage:${NC} $disk_usage"
  fi
}

show_package_diagnostics() {
  local cmd="$1"

  echo -e "\n${BOLD}${WHITE}PACKAGE MANAGER DIAGNOSTICS:${NC}"
  echo -e "${DIM}────────────────────────────────────────────────${NC}"

  # Check if xbps is available
  if command -v xbps-install >/dev/null 2>&1; then
    log_info "xbps package manager is available"

    # Extract package names from command
    local packages=$(echo "$cmd" | grep -oP 'xbps-install.*?\K(\S+)$' || echo "$cmd" | sed -n 's/.*xbps-install.* //p')

    if [ -n "$packages" ]; then
      echo -e "  ${CYAN}▸ Packages mentioned:${NC} $packages"

      # Check each package
      for pkg in $packages; do
        echo -e "  ${CYAN}▸ Package:${NC} $pkg"

        # Check if installed
        if xbps-query "$pkg" >/dev/null 2>&1; then
          echo -e "    ${GREEN}✓ Installed${NC}"
        else
          echo -e "    ${YELLOW}⚠ Not installed${NC}"

          # Check if exists in repositories
          if xbps-query -Rs "$pkg" 2>/dev/null | grep -q "$pkg"; then
            echo -e "    ${GREEN}✓ Available in repositories${NC}"

            # Show version info
            local pkg_info=$(xbps-query -Rs "$pkg" 2>/dev/null | head -1)
            echo -e "    ${DIM}$pkg_info${NC}"
          else
            echo -e "    ${RED}✗ NOT found in repositories${NC}"

            # Suggest search
            echo -e "    ${DIM}Searching alternatives...${NC}"
            xbps-query -Rs "$pkg" 2>/dev/null || true
          fi
        fi
      done
    fi

    # Check repository status
    echo -e "  ${CYAN}▸ Repository sync:${NC}"
    if sudo xbps-install -S >/dev/null 2>&1; then
      echo -e "    ${GREEN}✓ Repositories are up to date${NC}"
    else
      echo -e "    ${RED}✗ Repository sync failed${NC}"
    fi

    # Check for broken packages
    if xbps-pkgdb -a 2>&1 | grep -q "broken"; then
      echo -e "  ${RED}✗ Broken packages detected${NC}"
      xbps-pkgdb -a 2>&1 | grep "broken" || true
    fi
  else
    echo -e "  ${RED}✗ xbps-install not found${NC}"
  fi
}

show_environment_info() {
  echo -e "\n${BOLD}${WHITE}ENVIRONMENT VARIABLES:${NC}"
  echo -e "${DIM}────────────────────────────────────────────────${NC}"

  # Show relevant environment variables
  for var in PATH HOME USER LOGNAME SHELL EDITOR VISUAL PWD OLDPWD LANG LC_ALL; do
    if [ -n "${!var:-}" ]; then
      echo -e "  ${CYAN}▸ $var:${NC} ${!var}"
    fi
  done
}

show_action_menu() {
  echo -e "\n${BOLD}${WHITE}AVAILABLE ACTIONS:${NC}"
  echo -e "${DIM}────────────────────────────────────────────────${NC}"

  echo -e "  ${GREEN}[C]${NC} Continue execution"
  echo -e "  ${YELLOW}[S]${NC} Skip current module and continue"
  echo -e "  ${MAGENTA}[R]${NC} Retry failed command"
  echo -e "  ${CYAN}[D]${NC} Debug shell (exit to continue)"
  echo -e "  ${BLUE}[I]${NC} Show more info about the error"
  echo -e "  ${RED}[Q]${NC} Quit installation"

  while true; do
    echo -en "\n${BOLD}Select action ${DIM}[C/S/R/D/I/Q]:${NC} "
    read -r choice

    case "${choice,,}" in
    c)
      log_info "Continuing execution..."
      # Reset error tracking for next command
      ERROR_OCCURRED=0
      return 0
      ;;
    s)
      log_warning "Skipping current module: $CURRENT_MODULE"
      # Calculate module duration
      local module_end_time=$(current_timestamp)
      MODULE_DURATION=$(calculate_duration "$MODULE_START_TIME" "$module_end_time")
      log_info "Module ran for $(format_duration $MODULE_DURATION)"
      return 1 # Special return code for module skip
      ;;
    r)
      log_info "Retrying command: $ERROR_CMD"

      # Update timing
      LAST_COMMAND_START_TIME=$(current_timestamp)

      # Execute the command
      if eval "$ERROR_CMD"; then
        log_success "Retry successful"
        ERROR_OCCURRED=0
        return 0
      else
        local retry_status=$?
        log_error "Retry failed with code $retry_status"
        # Stay in error handler
        continue
      fi
      ;;
    d)
      log_info "Opening debug shell..."
      echo -e "${DIM}Type 'exit' to return to installer${NC}"
      echo -e "${DIM}Type 'exit 1' to abort installation${NC}"

      # Save current state
      local debug_ps1="\\n${RED}DEBUG${NC} \\u@\\h:\\w\\n\\$ "

      # Start debug shell
      PS1="$debug_ps1" bash --norc -i

      # Ask if user wants to continue
      read -p "Continue after debug? [Y/n]: " debug_choice
      if [[ "${debug_choice,,}" =~ ^(n|no)$ ]]; then
        exit 1
      fi
      log_info "Returning from debug shell"
      continue
      ;;
    i)
      show_extended_error_info
      continue
      ;;
    q)
      log_error "Quitting installation..."

      # Calculate total runtime
      local script_end_time=$(current_timestamp)
      local total_duration=$(calculate_duration "$SCRIPT_START_TIME" "$script_end_time")

      echo -e "\n${BOLD}${WHITE}INSTALLATION SUMMARY:${NC}"
      echo -e "${DIM}────────────────────────────────────────────────${NC}"
      echo -e "  ${CYAN}▸ Total runtime:${NC} $(format_duration $total_duration)"

      if [ -n "$CURRENT_MODULE" ]; then
        echo -e "  ${CYAN}▸ Failed module:${NC} $CURRENT_MODULE"
        echo -e "  ${CYAN}▸ Module runtime:${NC} $(format_duration $MODULE_DURATION)"
      fi

      echo -e "  ${CYAN}▸ Error location:${NC} $ERROR_FILE:$ERROR_LINE"
      echo -e "  ${CYAN}▸ Exit code:${NC} $ERROR_CODE"

      exit 1
      ;;
    *)
      echo -e "${RED}Invalid choice. Please select C, S, R, D, I, or Q${NC}"
      continue
      ;;
    esac
    break
  done
}

show_extended_error_info() {
  echo -e "\n${BOLD}${WHITE}EXTENDED ERROR INFORMATION:${NC}"
  echo -e "${DIM}────────────────────────────────────────────────${NC}"

  # Show command output if captured
  if [ -f "/tmp/last_command_output" ]; then
    echo -e "  ${CYAN}▸ Command output:${NC}"
    cat /tmp/last_command_output | head -20
    echo -e "  ${DIM}(showing first 20 lines)${NC}"
  fi

  # Show file permissions
  if [[ "$ERROR_CMD" =~ sudo ]]; then
    echo -e "  ${CYAN}▸ Sudo permissions check:${NC}"
    if sudo -n true 2>/dev/null; then
      echo -e "    ${GREEN}✓ Passwordless sudo available${NC}"
    else
      echo -e "    ${RED}✗ Passwordless sudo NOT available${NC}"
    fi
  fi

  # Check disk space
  echo -e "  ${CYAN}▸ Disk space in $(pwd):${NC}"
  df -h . 2>/dev/null || true

  # Check inotify limits
  if [[ "$ERROR_CMD" =~ inotify ]]; then
    echo -e "  ${CYAN}▸ Inotify limits:${NC}"
    sysctl fs.inotify.max_user_watches 2>/dev/null || true
  fi

  # Check memory
  echo -e "  ${CYAN}▸ Memory usage:${NC}"
  free -h 2>/dev/null || true
}

# ============================================
# MODULE MANAGEMENT FUNCTIONS
# ============================================

module_start() {
  CURRENT_MODULE="$1"
  MODULE_START_TIME=$(current_timestamp)

  echo -e "\n${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}${BOLD}    MODULE: $CURRENT_MODULE${NC}"
  echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"

  log_info "Starting module: $CURRENT_MODULE"
  log_info "Module started at: $(date '+%H:%M:%S')"
}

module_end() {
  local module_end_time=$(current_timestamp)
  MODULE_DURATION=$(calculate_duration "$MODULE_START_TIME" "$module_end_time")

  echo -e "\n${GREEN}${BOLD}────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}${BOLD}    MODULE COMPLETED: $CURRENT_MODULE${NC}"
  echo -e "${GREEN}${BOLD}────────────────────────────────────────────────${NC}"
  log_success "Module '$CURRENT_MODULE' completed in $(format_duration $MODULE_DURATION)"

  CURRENT_MODULE=""
}

# ============================================
# COMMAND EXECUTION FUNCTIONS
# ============================================

# Safe command execution with timing and output capture
execute() {
  local cmd="$*"
  local output_file="/tmp/last_command_output"

  # Start timing
  LAST_COMMAND_START_TIME=$(current_timestamp)

  # Log the command
  if [ "$VERBOSE" -eq 1 ] || [ "$DEBUG_MODE" -eq 1 ]; then
    echo -e "\n${BLUE}${BOLD}[→]${NC} ${DIM}Executing:${NC} $cmd"
  else
    echo -e "${BLUE}[→]${NC} $cmd"
  fi

  # Execute command, capturing output
  if eval "$cmd" 2>&1 | tee "$output_file"; then
    local exit_code=0
    local status="${GREEN}✓${NC}"
  else
    local exit_code=${PIPESTATUS[0]}
    local status="${RED}✗${NC}"
  fi

  # Calculate duration
  local command_end_time=$(current_timestamp)
  LAST_COMMAND_DURATION=$(calculate_duration "$LAST_COMMAND_START_TIME" "$command_end_time")

  # Show result with timing
  if [ "$VERBOSE" -eq 1 ] || [ "$DEBUG_MODE" -eq 1 ] || [ $exit_code -ne 0 ]; then
    echo -e "$status ${DIM}Command completed in $(format_duration $LAST_COMMAND_DURATION) (exit: $exit_code)${NC}"
  fi

  # Clean up output file
  rm -f "$output_file"

  return $exit_code
}

# Install packages with detailed error handling
install_packages() {
  local packages=("$@")

  if [ ${#packages[@]} -eq 0 ]; then
    log_warning "No packages specified for installation"
    return 0
  fi

  log_info "Installing ${#packages[@]} packages..."

  # Try bulk installation first
  if execute sudo xbps-install -y "${packages[@]}"; then
    log_success "All packages installed successfully"
    return 0
  else
    log_warning "Bulk installation failed, trying individual packages..."

    local failed_packages=()
    local success_count=0

    for pkg in "${packages[@]}"; do
      log_info "Installing: $pkg"

      if execute sudo xbps-install -y "$pkg"; then
        log_success "Installed: $pkg"
        ((success_count++))
      else
        log_error "Failed to install: $pkg"
        failed_packages+=("$pkg")

        # Try to find alternative
        try_package_alternative "$pkg"
      fi
    done

    # Report results
    if [ ${#failed_packages[@]} -eq 0 ]; then
      log_success "Successfully installed all $success_count packages"
      return 0
    else
      log_error "Failed to install ${#failed_packages[@]} packages: ${failed_packages[*]}"

      # Show suggestions
      for pkg in "${failed_packages[@]}"; do
        show_package_suggestions "$pkg"
      done

      return 1
    fi
  fi
}

# Try alternative package names
try_package_alternative() {
  local pkg="$1"

  # Known package alternatives for Void Linux
  declare -A alternatives=(
    ["neovim"]="nvim"
    ["nodejs"]="nodejs18 nodejs20 nodejs"
    ["python3-pip"]="python3-pip python-pip"
    ["vscode"]="vscode-bin code"
    ["docker"]="docker-engine docker-ce"
    ["wpa_gui"]="wpa_gui-qt5 wpa_gui-qt6"
  )

  if [ -n "${alternatives[$pkg]:-}" ]; then
    log_info "Trying alternatives for $pkg: ${alternatives[$pkg]}"

    for alt in ${alternatives[$pkg]}; do
      if execute sudo xbps-install -y "$alt"; then
        log_success "Installed alternative: $alt instead of $pkg"
        return 0
      fi
    done
  fi

  return 1
}

show_package_suggestions() {
  local pkg="$1"

  log_info "Searching for package: $pkg"
  local search_results=$(xbps-query -Rs "$pkg" 2>/dev/null | head -5)

  if [ -n "$search_results" ]; then
    echo -e "  ${CYAN}▸ Available packages matching '$pkg':${NC}"
    echo "$search_results" | while read -r line; do
      echo -e "    ${DIM}$line${NC}"
    done
  else
    echo -e "  ${RED}▸ No packages found matching '$pkg'${NC}"
  fi
}

# ============================================
# SERVICE MANAGEMENT FUNCTIONS
# ============================================

# Check if service exists
service_exists() {
  local service="$1"
  [ -d "/etc/sv/$service" ]
}

# Check if service is enabled
service_enabled() {
  local service="$1"
  [ -L "/var/service/$service" ]
}

# Enable a runit service
enable_service() {
  local service="$1"

  log_info "Enabling service: $service"

  if service_exists "$service"; then
    if service_enabled "$service"; then
      log_success "Service $service is already enabled"
      return 0
    fi

    if execute sudo ln -sf "/etc/sv/$service" "/var/service/"; then
      log_success "Enabled service: $service"
      return 0
    else
      log_error "Failed to enable service: $service"
      return 1
    fi
  else
    log_warning "Service directory not found: /etc/sv/$service"
    return 1
  fi
}

# Disable a runit service
disable_service() {
  local service="$1"

  log_info "Disabling service: $service"

  if service_enabled "$service"; then
    if execute sudo rm -f "/var/service/$service"; then
      log_success "Disabled service: $service"
      return 0
    else
      log_error "Failed to disable service: $service"
      return 1
    fi
  else
    log_warning "Service not enabled: $service"
    return 0
  fi
}

# Restart a service
restart_service() {
  local service="$1"

  log_info "Restarting service: $service"

  if service_enabled "$service"; then
    if execute sudo sv restart "$service"; then
      log_success "Restarted service: $service"
      return 0
    else
      log_error "Failed to restart service: $service"
      return 1
    fi
  else
    log_warning "Service not enabled: $service"
    return 1
  fi
}

# Start a service
start_service() {
  local service="$1"

  log_info "Starting service: $service"

  if service_enabled "$service"; then
    if execute sudo sv start "$service"; then
      log_success "Started service: $service"
      return 0
    else
      log_error "Failed to start service: $service"
      return 1
    fi
  else
    log_warning "Service not enabled: $service"
    return 1
  fi
}

# Check service status
service_status() {
  local service="$1"

  echo -e "${CYAN}[*]${NC} Status of service: $service"

  if service_exists "$service"; then
    if service_enabled "$service"; then
      execute sudo sv status "$service"
    else
      echo -e "  ${YELLOW}[!]${NC} Service exists but is not enabled"
    fi
  else
    echo -e "  ${RED}[✗]${NC} Service does not exist"
  fi
}

# Enable multiple services
enable_services() {
  local services=("$@")
  local failed_services=()

  for service in "${services[@]}"; do
    if ! enable_service "$service"; then
      failed_services+=("$service")
    fi
  done

  if [ ${#failed_services[@]} -gt 0 ]; then
    log_warning "Failed to enable services: ${failed_services[*]}"
    return 1
  fi

  return 0
}

# ============================================
# SYSTEM CHECK FUNCTIONS
# ============================================

# Check if running on Void Linux
check_void_linux() {
  if [ ! -f "/etc/void-release" ]; then
    log_error "This script is for Void Linux only"
    log_info "Detected system: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' || uname -a)"
    exit 1
  fi
  log_success "Running on Void Linux"
}

# Check if user has sudo privileges
check_sudo_privileges() {
  if ! sudo -v >/dev/null 2>&1; then
    log_error "User $(whoami) does not have sudo privileges"
    log_info "To fix this, run:"
    log_info "  sudo usermod -aG wheel $(whoami)"
    log_info "Then log out and back in"
    exit 1
  fi
  log_success "Sudo privileges confirmed"
}

# Update xbps and system
update_system() {
  log_info "Updating xbps package manager..."
  execute sudo xbps-install -Suy xbps

  log_info "Updating system packages..."
  execute sudo xbps-install -Su
}

# ============================================
# UTILITY FUNCTIONS
# ============================================

# Ask yes/no question
ask_yesno() {
  local prompt="$1"
  local default="${2:-no}"

  case "$default" in
  yes | y | Y)
    local options="[Y/n]"
    local default_val="yes"
    ;;
  *)
    local options="[y/N]"
    local default_val="no"
    ;;
  esac

  while true; do
    read -p "$prompt $options: " answer

    case "${answer,,}" in
    y | yes)
      return 0
      ;;
    n | no)
      return 1
      ;;
    "")
      [ "$default_val" = "yes" ] && return 0 || return 1
      ;;
    *)
      echo -e "${RED}Please answer yes or no${NC}"
      continue
      ;;
    esac
  done
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if package is installed (Void Linux specific)
pkg_installed() {
  xbps-query "$1" >/dev/null 2>&1
}

# Create directory with parents
mkdir_p() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    execute mkdir -p "$dir"
  fi
}

# Download file with progress
download_file() {
  local url="$1"
  local output="$2"

  log_info "Downloading: $(basename "$output")"

  if command_exists curl; then
    execute curl -L -# -o "$output" "$url"
  elif command_exists wget; then
    execute wget -O "$output" "$url"
  else
    log_error "Neither curl nor wget found"
    return 1
  fi
}

# ============================================
# INITIALIZATION MESSAGE
# ============================================

# Show initialization banner
echo -e "${BLUE}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}${BOLD}           OMARCHY VOID SETUP - ERROR HANDLER LOADED           ${NC}"
echo -e "${BLUE}${BOLD}══════════════════════════════════════════════════════════════${NC}"
log_info "Error handler initialized at $(date '+%Y-%m-%d %H:%M:%S')"

# Set debug mode from environment variable if present
if [ "$DEBUG_MODE" -eq 1 ]; then
  log_info "Debug mode enabled"
fi

if [ "$VERBOSE" -eq 1 ]; then
  log_info "Verbose mode enabled"
fi
