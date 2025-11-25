#!/bin/bash
################################################################################
# Linux System Hardening Tool - Installation Script
# Organization: National Technical Research Organisation
# Category: Software | Theme: Cyber Security
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Installation directories
INSTALL_DIR="/opt/hardening-tool"
BIN_DIR="/usr/local/bin"
LIB_DIR="/var/lib/hardening"
LOG_DIR="/var/lib/hardening/logs"
BACKUP_DIR="/var/lib/hardening/backups"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        print_info "Detected OS: $PRETTY_NAME"
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
}

# Check Python version
check_python() {
    print_info "Checking Python installation..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
        
        if [[ $PYTHON_MAJOR -eq 3 ]] && [[ $PYTHON_MINOR -ge 6 ]]; then
            print_success "Python $PYTHON_VERSION found"
            return 0
        else
            print_error "Python 3.6 or higher required (found $PYTHON_VERSION)"
            return 1
        fi
    else
        print_error "Python 3 not found"
        return 1
    fi
}

# Install Python dependencies
install_dependencies() {
    print_info "Installing dependencies..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        print_info "Using apt-get package manager"
        apt-get update -qq
        apt-get install -y python3 python3-pip python3-yaml &> /dev/null
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        print_info "Using yum package manager"
        yum install -y python3 python3-pip python3-pyyaml &> /dev/null
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        print_info "Using dnf package manager"
        dnf install -y python3 python3-pip python3-pyyaml &> /dev/null
    else
        print_error "No supported package manager found"
        exit 1
    fi
    
    # Install Python packages
    print_info "Installing Python packages..."
    pip3 install --quiet --upgrade pip
    pip3 install --quiet pyyaml
    
    print_success "Dependencies installed"
}

# Create directories
create_directories() {
    print_info "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LIB_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Set proper permissions
    chmod 755 "$INSTALL_DIR"
    chmod 750 "$LIB_DIR"
    chmod 750 "$LOG_DIR"
    chmod 750 "$BACKUP_DIR"
    
    print_success "Directories created"
}

# Install files
install_files() {
    print_info "Installing files..."
    
    # Check if files exist in current directory
    if [[ ! -f "engine.py" ]]; then
        print_error "engine.py not found in current directory"
        exit 1
    fi
    
    if [[ ! -f "hardening_rules.yaml" ]]; then
        print_error "hardening_rules.yaml not found in current directory"
        exit 1
    fi
    
    # Copy files
    cp engine.py "$INSTALL_DIR/"
    cp hardening_rules.yaml "$INSTALL_DIR/"
    
    # Set permissions
    chmod 755 "$INSTALL_DIR/engine.py"
    chmod 644 "$INSTALL_DIR/hardening_rules.yaml"
    
    # Create symlink
    ln -sf "$INSTALL_DIR/engine.py" "$BIN_DIR/hardening-tool"
    chmod 755 "$BIN_DIR/hardening-tool"
    
    print_success "Files installed"
}

# Create systemd service (optional)
create_service() {
    print_info "Creating systemd service for scheduled audits..."
    
    cat > /etc/systemd/system/hardening-audit.service << 'EOF'
[Unit]
Description=Linux System Hardening Audit
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/hardening-tool --audit
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/hardening-audit.timer << 'EOF'
[Unit]
Description=Run hardening audit weekly
Requires=hardening-audit.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    
    print_success "Systemd service created"
    print_info "Enable with: systemctl enable --now hardening-audit.timer"
}

# Create configuration file
create_config() {
    print_info "Creating configuration file..."
    
    cat > "$INSTALL_DIR/config.ini" << EOF
[General]
install_dir = $INSTALL_DIR
lib_dir = $LIB_DIR
log_dir = $LOG_DIR
backup_dir = $BACKUP_DIR

[Logging]
level = INFO
max_log_size = 10485760
backup_count = 5

[Hardening]
auto_backup = true
require_confirmation = false
EOF

    chmod 644 "$INSTALL_DIR/config.ini"
    print_success "Configuration file created"
}

# Create man page
create_manpage() {
    print_info "Creating man page..."
    
    mkdir -p /usr/local/share/man/man8
    
    cat > /usr/local/share/man/man8/hardening-tool.8 << 'EOF'
.TH HARDENING-TOOL 8 "2025" "version 1.0" "System Administration"
.SH NAME
hardening-tool \- Linux system hardening and compliance tool
.SH SYNOPSIS
.B hardening-tool
[\fIOPTIONS\fR]
.SH DESCRIPTION
.B hardening-tool
is a comprehensive system hardening tool that audits and remediates security
configurations based on industry best practices and organizational standards.
.SH OPTIONS
.TP
.B \-\-audit
Run security audit checks without making any changes
.TP
.B \-\-remediate
Run audit and apply fixes to failed checks
.TP
.B \-\-dry-run
Show what changes would be made without applying them
.TP
.B \-\-rollback BACKUP_DIR
Rollback changes to a previous backup
.TP
.B \-\-rules FILE
Use custom rules file (default: hardening_rules.yaml)
.SH EXAMPLES
.TP
Run audit only:
.B sudo hardening-tool --audit
.TP
Audit and fix issues:
.B sudo hardening-tool --remediate
.TP
Test changes without applying:
.B sudo hardening-tool --remediate --dry-run
.SH FILES
.TP
.I /opt/hardening-tool/hardening_rules.yaml
Main configuration file containing hardening rules
.TP
.I /var/lib/hardening/logs/
Log and report directory
.TP
.I /var/lib/hardening/backups/
Backup directory for rollback functionality
.SH SEE ALSO
.BR systemd (1),
.BR auditd (8),
.BR modprobe (8)
.SH AUTHOR
National Technical Research Organisation
EOF

    gzip -f /usr/local/share/man/man8/hardening-tool.8
    mandb -q 2>/dev/null || true
    
    print_success "Man page created"
}

# Create README
create_readme() {
    cat > "$INSTALL_DIR/README.md" << 'EOF'
# Linux System Hardening Tool

## Overview
Professional system hardening tool implementing security best practices based on CIS benchmarks and organizational standards.

## Quick Start

### Audit System
```bash
sudo hardening-tool --audit
```

### Apply Fixes
```bash
sudo hardening-tool --remediate
```

### Dry Run
```bash
sudo hardening-tool --remediate --dry-run
```

### Rollback
```bash
sudo hardening-tool --rollback /var/lib/hardening/backups/20250101_120000
```

## Features
- ✓ Automated security checks
- ✓ Safe remediation with rollback
- ✓ Detailed compliance reports
- ✓ Manual intervention guidance
- ✓ Backup before changes
- ✓ Dry-run mode

## Directory Structure
- `/opt/hardening-tool/` - Installation directory
- `/var/lib/hardening/logs/` - Reports and logs
- `/var/lib/hardening/backups/` - Configuration backups

## Support
For issues and updates, contact your security team.
EOF

    print_success "README created"
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    local errors=0
    
    # Check files
    [[ -f "$INSTALL_DIR/engine.py" ]] || { print_error "engine.py missing"; ((errors++)); }
    [[ -f "$INSTALL_DIR/hardening_rules.yaml" ]] || { print_error "hardening_rules.yaml missing"; ((errors++)); }
    [[ -L "$BIN_DIR/hardening-tool" ]] || { print_error "hardening-tool symlink missing"; ((errors++)); }
    
    # Check directories
    [[ -d "$LIB_DIR" ]] || { print_error "Library directory missing"; ((errors++)); }
    [[ -d "$LOG_DIR" ]] || { print_error "Log directory missing"; ((errors++)); }
    [[ -d "$BACKUP_DIR" ]] || { print_error "Backup directory missing"; ((errors++)); }
    
    # Check executability
    [[ -x "$INSTALL_DIR/engine.py" ]] || { print_error "engine.py not executable"; ((errors++)); }
    
    if [[ $errors -eq 0 ]]; then
        print_success "Installation verified successfully"
        return 0
    else
        print_error "Installation verification failed with $errors errors"
        return 1
    fi
}

# Uninstall function
uninstall() {
    print_warning "Uninstalling hardening tool..."
    
    # Remove files
    rm -f "$BIN_DIR/hardening-tool"
    rm -rf "$INSTALL_DIR"
    
    # Remove systemd files
    systemctl stop hardening-audit.timer 2>/dev/null || true
    systemctl disable hardening-audit.timer 2>/dev/null || true
    rm -f /etc/systemd/system/hardening-audit.service
    rm -f /etc/systemd/system/hardening-audit.timer
    systemctl daemon-reload
    
    # Remove man page
    rm -f /usr/local/share/man/man8/hardening-tool.8.gz
    mandb -q 2>/dev/null || true
    
    print_warning "Note: Logs and backups in $LIB_DIR are preserved"
    print_success "Uninstallation complete"
}

# Main installation
main() {
    print_header "Linux System Hardening Tool - Installer v1.0"
    
    # Check for uninstall flag
    if [[ "$1" == "--uninstall" ]]; then
        check_root
        uninstall
        exit 0
    fi
    
    print_info "Starting installation..."
    echo ""
    
    check_root
    detect_os
    
    if ! check_python; then
        print_info "Installing Python..."
        install_dependencies
    fi
    
    create_directories
    install_files
    create_config
    create_service
    create_manpage
    create_readme
    
    if verify_installation; then
        print_header "Installation Complete!"
        
        echo -e "${GREEN}The hardening tool has been installed successfully!${NC}"
        echo ""
        echo "Installation Details:"
        echo "  • Installation directory: $INSTALL_DIR"
        echo "  • Executable: $BIN_DIR/hardening-tool"
        echo "  • Logs: $LOG_DIR"
        echo "  • Backups: $BACKUP_DIR"
        echo ""
        echo "Quick Start:"
        echo "  1. Run audit:      ${BOLD}sudo hardening-tool --audit${NC}"
        echo "  2. Apply fixes:    ${BOLD}sudo hardening-tool --remediate${NC}"
        echo "  3. Dry run:        ${BOLD}sudo hardening-tool --remediate --dry-run${NC}"
        echo "  4. Get help:       ${BOLD}hardening-tool --help${NC}"
        echo "  5. View manual:    ${BOLD}man hardening-tool${NC}"
        echo ""
        echo "Optional:"
        echo "  • Enable weekly audits: ${BOLD}sudo systemctl enable --now hardening-audit.timer${NC}"
        echo ""
        echo -e "${YELLOW}Note: Always backup your system before running remediation!${NC}"
        echo ""
    else
        print_error "Installation verification failed"
        exit 1
    fi
}

# Run main installation
main "$@"
