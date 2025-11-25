# Linux System Hardening Tool v1.0

[![License](https://img.shields.io/badge/license-Proprietary-red.svg)]()
[![Python](https://img.shields.io/badge/python-3.6+-blue.svg)]()
[![Platform](https://img.shields.io/badge/platform-Linux-green.svg)]()

**Organization:** National Technical Research Organisation  
**Category:** Software | Theme: Cyber Security

---

## 🎯 Overview

Professional-grade Linux system hardening tool implementing **Annexure B** security requirements. Automates security configuration audits, applies safe remediations, and provides detailed compliance reporting with full rollback capabilities.

### ✨ Key Features

- 🔍 **Comprehensive Auditing** - 50+ security configuration checks
- 🔧 **Safe Remediation** - Automated fixes with backup/rollback
- 📋 **Detailed Reports** - Compliance metrics and actionable insights
- ⚠️ **Manual Guidance** - Step-by-step instructions for complex tasks
- 🔄 **Rollback Support** - Complete restoration from backups
- 🧪 **Dry-Run Mode** - Preview changes before applying
- 📊 **Test Suite** - Comprehensive validation framework

---

## 🚀 Quick Start

### Installation

```bash
# 1. Download all files to a directory
cd /path/to/hardening-tool

# 2. Run installer
chmod +x install.sh
sudo ./install.sh
```

### Basic Usage

```bash
# Run security audit
sudo hardening-tool --audit

# Preview fixes (dry-run)
sudo hardening-tool --remediate --dry-run

# Apply fixes
sudo hardening-tool --remediate

# Rollback changes
sudo hardening-tool --rollback /var/lib/hardening/backups/20250101_120000
```

---

## 📦 Project Structure

```
hardening-tool/
├── install.sh                  # Installation script
├── engine.py                   # Main hardening engine
├── hardening_rules.yaml        # Security rules configuration
├── test_hardening.sh          # Test suite
├── README.md                   # This file
└── USER_GUIDE.md              # Comprehensive documentation
```

---

## 📋 Requirements

- **OS:** Linux (Ubuntu, Debian, CentOS, RHEL)
- **Python:** 3.6 or higher
- **Privileges:** Root/sudo access
- **Disk Space:** 100MB minimum
- **Dependencies:** PyYAML (auto-installed)

---

## 🔧 What Gets Hardened?

### Filesystem Module (Currently Implemented)

#### Kernel Modules Security
- ✅ Disable unused filesystem modules (cramfs, freevxfs, hfs, hfsplus, jffs2, overlayfs, squashfs, udf)
- ✅ Disable USB storage module
- ✅ Proper blacklisting with `/bin/false` install directive

#### Filesystem Partitions
- ✅ Verify separate partitions for critical directories
- ✅ Enforce mount options (nodev, nosuid, noexec)
- ✅ Covers: `/tmp`, `/dev/shm`, `/home`, `/var`, `/var/tmp`, `/var/log`, `/var/log/audit`

### Future Modules (Annexure B)
- 🔜 Package Management & Bootloader
- 🔜 Services Configuration
- 🔜 Network Hardening
- 🔜 Firewall Configuration
- 🔜 SSH & Access Control
- 🔜 PAM & User Account Security
- 🔜 Logging & Auditing
- 🔜 System Maintenance

---

## 📊 Example Output

```
================================================================================
FILESYSTEM HARDENING CHECKS
================================================================================

[*] Checking Kernel Modules...

  [1.a.i] Ensure cramfs kernel module is not available
  [✓ PASS] Module cramfs properly disabled

  [1.a.vi] Ensure overlayfs kernel module is not available
  [✗ FAIL] Module overlayfs not properly blacklisted

[*] Checking Filesystem Partitions...

  [1.b.i] Ensure /tmp is a separate partition
  [! MANUAL] Partition /tmp does not exist
  Manual intervention required:
    1. Use 'lsblk' to identify available disk space
    2. Create partition: fdisk /dev/sdX
    3. Format: mkfs.ext4 /dev/sdXn
    ...

  [1.b.ii] Ensure nodev option set on /tmp partition
  [⏭️ SKIP] Partition /tmp does not exist

================================================================================
HARDENING SUMMARY
================================================================================
  Total Checks:        35
  Passed:              25 (71.4%)
  Failed:              5 (14.3%)
  Manual Required:     3 (8.6%)
  Skipped:             2 (5.7%)

  Compliance Rate:     71.4%

  Report saved to: /var/lib/hardening/logs/report_20250101_120000.txt
  Backups saved to: /var/lib/hardening/backups/20250101_120000
================================================================================
```

---

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Run all tests
sudo ./test_hardening.sh

# Expected output:
# ========================================
# Test Summary
# ========================================
# Total Tests:      12
# Passed:           12
# Failed:           0
# Success Rate:     100.00%
```

---

## 🎓 Usage Examples

### Scenario 1: Initial Security Assessment

```bash
# Step 1: Run audit
sudo hardening-tool --audit

# Step 2: Review report
cat /var/lib/hardening/logs/report_*.txt

# Step 3: Identify issues
grep -E "(FAIL|MANUAL)" /var/lib/hardening/logs/report_*.txt
```

### Scenario 2: Safe Hardening Process

```bash
# Step 1: Dry run
sudo hardening-tool --remediate --dry-run > /tmp/proposed_changes.txt

# Step 2: Review changes
less /tmp/proposed_changes.txt

# Step 3: Apply changes
sudo hardening-tool --remediate

# Step 4: Verify
sudo hardening-tool --audit
```

### Scenario 3: Rollback After Issues

```bash
# List available backups
ls -lt /var/lib/hardening/backups/

# Rollback to specific point
sudo hardening-tool --rollback /var/lib/hardening/backups/20250101_120000

# Verify restoration
sudo hardening-tool --audit
```

---

## 🔍 How It Works

### 1. **Intelligent Checking**
   - Detects kernel module status properly (checks blacklist + /bin/false + loaded state)
   - Validates partition mount options
   - Identifies prerequisites before dependent checks

### 2. **Safe Remediation**
   - Backs up all files before modification
   - Creates proper blacklist configurations
   - Updates fstab and remounts partitions
   - Updates initramfs when needed

### 3. **Smart Handling**
   - **Automated:** Fixes that are safe and reversible
   - **Manual:** Complex changes requiring human decision
   - **Skipped:** Checks where prerequisites aren't met

### 4. **Comprehensive Reporting**
   - Pass/Fail status for each check
   - Detailed compliance metrics
   - Manual intervention instructions
   - Timestamped reports and backups

---

## 📚 Documentation

- **[USER_GUIDE.md](USER_GUIDE.md)** - Comprehensive user guide
- **Man Page** - `man hardening-tool` (after installation)
- **Inline Help** - `hardening-tool --help`

---

## 🛡️ Security Considerations

### What This Tool Does
- ✅ Hardens kernel module configuration
- ✅ Enforces secure mount options
- ✅ Backs up all changes
- ✅ Provides rollback capability
- ✅ Guides manual interventions

### What This Tool Doesn't Do
- ❌ Create disk partitions (requires manual intervention)
- ❌ Modify running services without warning
- ❌ Make changes without backup
- ❌ Override explicit user decisions

### Best Practices
1. **Test in non-production first**
2. **Use `--dry-run` before applying**
3. **Keep backups for 30+ days**
4. **Review manual intervention warnings**
5. **Document all changes**

---

## 🔧 Advanced Configuration

### Custom Rules File

```bash
# Copy and modify default rules
sudo cp /opt/hardening-tool/hardening_rules.yaml /etc/custom_hardening.yaml

# Use custom rules
sudo hardening-tool --audit --rules /etc/custom_hardening.yaml
```

### Scheduled Audits

```bash
# Enable weekly automated audits
sudo systemctl enable --now hardening-audit.timer

# Check status
sudo systemctl status hardening-audit.timer

# View audit logs
sudo journalctl -u hardening-audit.service
```

---

## 🐛 Troubleshooting

### Common Issues

**Issue:** Permission denied  
**Solution:** Run with `sudo`

**Issue:** Module 'yaml' not found  
**Solution:** `sudo pip3 install pyyaml`

**Issue:** Partition remount failed  
**Solution:** Check if partition is in use with `lsof | grep /partition`

**Issue:** Backup directory full  
**Solution:** Clean old backups: `cd /var/lib/hardening/backups && ls -t | tail -n +6 | xargs rm -rf`

---

## 📈 Roadmap

- [x] Filesystem module (kernel modules + partitions)
- [ ] Package management & bootloader configuration
- [ ] Services and daemon hardening
- [ ] Network kernel parameters
- [ ] Host-based firewall (UFW)
- [ ] SSH server hardening
- [ ] PAM configuration
- [ ] Audit daemon configuration
- [ ] System file permissions
- [ ] Web interface (optional)
- [ ] Ansible integration (optional)

---

## 📄 License

Proprietary - National Technical Research Organisation

**Authorized Use Only**

This tool is developed for internal use within the organization. Unauthorized distribution, modification, or use is strictly prohibited.

---

## 👥 Authors & Maintainers

**Development Team:** NTRO Security Operations  
**Contact:** security-team@ntro.gov.in  
**Support:** Submit via internal ticketing system

---

## 🙏 Acknowledgments

- CIS Benchmarks for Linux
- NIST Cybersecurity Framework
- DISA STIG Guidelines
- Open-source security community

---

## 📞 Support

For issues, questions, or feature requests:

1. **Check Documentation:** [USER_GUIDE.md](USER_GUIDE.md)
2. **View Logs:** `/var/lib/hardening/logs/`
3. **Contact Team:** security-team@ntro.gov.in

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-01  
**Status:** Production Ready (Filesystem Module)

---

## Quick Reference Card

```bash
# Installation
sudo ./install.sh

# Basic Operations
sudo hardening-tool --audit                    # Audit only
sudo hardening-tool --remediate --dry-run      # Preview changes
sudo hardening-tool --remediate                # Apply fixes
sudo hardening-tool --rollback <backup_dir>    # Rollback

# Testing
sudo ./test_hardening.sh                       # Run tests

# Maintenance
sudo systemctl enable hardening-audit.timer    # Enable auto-audit
man hardening-tool                             # View manual

# Uninstall
sudo /opt/hardening-tool/install.sh --uninstall
```

---

**Happy Hardening! 🔒**