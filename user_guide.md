# Linux System Hardening Tool - User Guide

**Version:** 1.0  
**Organization:** National Technical Research Organisation  
**Category:** Software | Theme: Cyber Security

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Usage Guide](#usage-guide)
5. [Understanding Results](#understanding-results)
6. [Rollback Procedures](#rollback-procedures)
7. [Manual Interventions](#manual-interventions)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

---

## Overview

The Linux System Hardening Tool is a comprehensive security automation framework that:

- ✅ **Audits** system configurations against security benchmarks
- ✅ **Remediates** security issues automatically where safe
- ✅ **Guides** administrators for manual interventions
- ✅ **Backs up** all changes for easy rollback
- ✅ **Reports** detailed compliance status

### Key Features

| Feature | Description |
|---------|-------------|
| **Automated Checks** | Validates 50+ security configurations |
| **Safe Remediation** | Only applies fixes that can be safely automated |
| **Rollback Support** | Complete backup and restore functionality |
| **Detailed Reports** | JSON and text reports with compliance metrics |
| **Dry-Run Mode** | Preview changes before applying |
| **Manual Guidance** | Step-by-step instructions for complex changes |

---

## Installation

### Prerequisites

- Linux-based operating system (Ubuntu, CentOS, RHEL, Debian)
- Root or sudo access
- Python 3.6 or higher
- 100MB free disk space

### Install Steps

```bash
# 1. Download the tool
cd /tmp
# [Copy all files to this directory: install.sh, engine.py, hardening_rules.yaml]

# 2. Make installer executable
chmod +x install.sh

# 3. Run installation
sudo ./install.sh
```

### Verify Installation

```bash
# Check if tool is installed
hardening-tool --help

# View man page
man hardening-tool

# Check version
hardening-tool --version
```

### Uninstall

```bash
sudo /opt/hardening-tool/install.sh --uninstall
```

---

## Quick Start

### 1. Run Your First Audit

```bash
sudo hardening-tool --audit
```

This will:
- Check all security configurations
- Generate a detailed report
- Save results to `/var/lib/hardening/logs/`
- **NOT make any changes**

### 2. Review the Report

```bash
# View the latest report
cat /var/lib/hardening/logs/report_*.txt | less

# Or check the summary
grep -A 20 "SUMMARY" /var/lib/hardening/logs/report_*.txt
```

### 3. Apply Fixes (Dry Run First)

```bash
# See what would be changed
sudo hardening-tool --remediate --dry-run
```

### 4. Apply Fixes

```bash
# Apply remediations
sudo hardening-tool --remediate
```

---

## Usage Guide

### Command Structure

```bash
hardening-tool [MODE] [OPTIONS]
```

### Modes

| Mode | Description | Example |
|------|-------------|---------|
| `--audit` | Check configurations only | `sudo hardening-tool --audit` |
| `--remediate` | Check and fix issues | `sudo hardening-tool --remediate` |
| `--rollback` | Restore from backup | `sudo hardening-tool --rollback /path/to/backup` |

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--dry-run` | Preview changes without applying | `--remediate --dry-run` |
| `--rules FILE` | Use custom rules file | `--rules /path/to/rules.yaml` |
| `--help` | Show help message | `--help` |

### Common Workflows

#### Workflow 1: Initial Audit

```bash
# Step 1: Run audit
sudo hardening-tool --audit

# Step 2: Review report
less /var/lib/hardening/logs/report_$(ls -t /var/lib/hardening/logs/ | head -1)

# Step 3: Understand what needs fixing
grep "FAIL" /var/lib/hardening/logs/report_*.txt
```

#### Workflow 2: Safe Remediation

```bash
# Step 1: Dry run to see changes
sudo hardening-tool --remediate --dry-run > /tmp/changes.txt

# Step 2: Review proposed changes
cat /tmp/changes.txt

# Step 3: Apply changes
sudo hardening-tool --remediate

# Step 4: Verify compliance
sudo hardening-tool --audit
```

#### Workflow 3: Rollback

```bash
# Step 1: List backups
ls -lt /var/lib/hardening/backups/

# Step 2: Rollback to specific backup
sudo hardening-tool --rollback /var/lib/hardening/backups/20250101_120000

# Step 3: Verify system state
sudo hardening-tool --audit
```

---

## Understanding Results

### Check Status Types

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| **PASS** ✅ | Configuration meets requirements | None |
| **FAIL** ❌ | Configuration does not meet requirements | Review and remediate |
| **MANUAL** ⚠️ | Requires manual intervention | Follow provided instructions |
| **SKIP** ⏭️ | Check skipped (prerequisite not met) | Address prerequisite first |

### Example Output

```
[1.a.i] Ensure cramfs kernel module is not available
[✓ PASS] Module cramfs properly disabled

[1.b.i] Ensure /tmp is a separate partition
[! MANUAL] Partition /tmp does not exist
Manual intervention required:
  1. Use 'lsblk' to identify available disk space
  2. Create partition: fdisk /dev/sdX
  ...

[1.b.ii] Ensure nodev option set on /tmp partition
[⏭️ SKIP] Partition /tmp does not exist
```

### Compliance Metrics

```
SUMMARY
==================================================
Total Checks:        50
Passed:              35 (70.0%)
Failed:              10 (20.0%)
Manual Required:     3 (6.0%)
Skipped:             2 (4.0%)

Compliance Rate:     70.0%
```

---

## Rollback Procedures

### Understanding Backups

Every time you run `--remediate`, the tool:
1. Creates a timestamped backup directory
2. Backs up all files before modification
3. Stores file hashes for integrity verification

### Backup Location

```
/var/lib/hardening/backups/
├── 20250101_120000/
│   ├── etc/
│   │   ├── fstab
│   │   └── modprobe.d/
│   │       └── cramfs.conf
│   └── ...
├── 20250101_150000/
└── ...
```

### Rollback Commands

#### List Available Backups

```bash
ls -lt /var/lib/hardening/backups/
```

#### Rollback to Specific Backup

```bash
sudo hardening-tool --rollback /var/lib/hardening/backups/20250101_120000
```

#### Rollback Most Recent Changes

```bash
LATEST=$(ls -t /var/lib/hardening/backups/ | head -1)
sudo hardening-tool --rollback /var/lib/hardening/backups/$LATEST
```

### Verification After Rollback

```bash
# Run audit to verify system state
sudo hardening-tool --audit

# Compare with original state
diff /var/lib/hardening/backups/20250101_120000/etc/fstab /etc/fstab
```

---

## Manual Interventions

### When Manual Intervention is Required

Some security configurations **cannot** be automated safely because they require:
- Creating new disk partitions
- Moving data between partitions
- Making architectural system changes
- Understanding business requirements

### Common Manual Tasks

#### 1. Creating Separate Partitions

**Task:** Create separate `/tmp` partition

**Why Manual:** Requires disk repartitioning and data migration

**Steps:**
```bash
# 1. Check available space
lsblk
df -h

# 2. Create partition (example)
sudo fdisk /dev/sda
# Press 'n' for new partition
# Follow prompts

# 3. Format partition
sudo mkfs.ext4 /dev/sda5

# 4. Backup existing /tmp
sudo tar -czf /root/tmp_backup.tar.gz /tmp

# 5. Add to /etc/fstab
echo "/dev/sda5 /tmp ext4 defaults,nodev,nosuid,noexec 0 0" | sudo tee -a /etc/fstab

# 6. Mount
sudo mount -a

# 7. Restore data
sudo tar -xzf /root/tmp_backup.tar.gz -C /

# 8. Verify
df -h /tmp
mount | grep /tmp

# 9. Re-audit
sudo hardening-tool --audit
```

#### 2. Verifying Partition Options

After creating partitions manually, run:

```bash
# Check mount options
mount | grep /tmp

# Should show: /dev/sda5 on /tmp type ext4 (rw,nodev,nosuid,noexec,...)
```

### Re-Audit After Manual Changes

**Always re-audit** after manual interventions:

```bash
sudo hardening-tool --audit
```

This ensures:
- Changes were applied correctly
- No new issues were introduced
- Compliance improved as expected

---

## Best Practices

### Before Running Hardening

1. **Backup System**
   ```bash
   # Full system backup
   sudo tar -czf /backup/system_$(date +%Y%m%d).tar.gz \
     /etc /boot /var/lib /usr/local
   ```

2. **Test in Non-Production**
   - Always test in development/staging first
   - Verify application compatibility

3. **Document Current State**
   ```bash
   # Save current configurations
   sudo hardening-tool --audit > /root/baseline_audit.txt
   ```

### During Hardening

1. **Use Dry-Run First**
   ```bash
   sudo hardening-tool --remediate --dry-run
   ```

2. **Read All Warnings**
   - Manual intervention warnings are important
   - Understand impact before proceeding

3. **Monitor Logs**
   ```bash
   tail -f /var/lib/hardening/logs/report_*.txt
   ```

### After Hardening

1. **Verify System Functionality**
   - Test all critical services
   - Verify user access
   - Check application behavior

2. **Document Changes**
   ```bash
   # Save final state
   sudo hardening-tool --audit > /root/post_hardening_audit.txt
   
   # Compare
   diff /root/baseline_audit.txt /root/post_hardening_audit.txt
   ```

3. **Keep Backups**
   - Don't delete backup directories
   - Archive to external storage

### Ongoing Maintenance

1. **Regular Audits**
   ```bash
   # Enable weekly audits
   sudo systemctl enable --now hardening-audit.timer
   ```

2. **Review Reports**
   ```bash
   # Check latest audit
   cat /var/lib/hardening/logs/report_$(ls -t /var/lib/hardening/logs/ | head -1)
   ```

3. **Update Rules**
   - Keep `hardening_rules.yaml` current
   - Adapt to organizational policies

---

## Troubleshooting

### Common Issues

#### Issue 1: Permission Denied

**Symptom:**
```
[ERROR] This script must be run as root
```

**Solution:**
```bash
sudo hardening-tool --audit
```

#### Issue 2: Module Not Found

**Symptom:**
```
ModuleNotFoundError: No module named 'yaml'
```

**Solution:**
```bash
sudo pip3 install pyyaml
```

#### Issue 3: Partition Remount Failed

**Symptom:**
```
[✗ ERROR] Failed to remount /tmp
```

**Solution:**
```bash
# Check if partition is in use
sudo lsof | grep /tmp

# Kill processes if safe
# Then retry remount
sudo mount -o remount,nodev,nosuid,noexec /tmp
```

#### Issue 4: Backup Directory Full

**Symptom:**
```
OSError: [Errno 28] No space left on device
```

**Solution:**
```bash
# Check space
df -h /var/lib/hardening

# Clean old backups (keep last 5)
cd /var/lib/hardening/backups
ls -t | tail -n +6 | xargs rm -rf
```

### Debug Mode

For detailed debugging:

```bash
# Run with Python verbose mode
sudo python3 -v /opt/hardening-tool/engine.py --audit

# Check system logs
sudo journalctl -xe | grep hardening
```

### Getting Help

1. **Check Logs**
   ```bash
   cat /var/lib/hardening/logs/report_*.txt
   ```

2. **View Man Page**
   ```bash
   man hardening-tool
   ```

3. **Contact Support**
   - Email: security-team@organization.in
   - Include: Report file and error messages

---

## FAQ

### Q1: Can I run this on production systems?

**A:** Yes, but:
- Test in staging first
- Use `--dry-run` mode initially
- Schedule during maintenance windows
- Have rollback plan ready

### Q2: Will this break my applications?

**A:** Unlikely, but:
- Some mount options (noexec) may affect scripts
- Test application compatibility first
- Review manual intervention warnings
- Can rollback if issues occur

### Q3: How long does hardening take?

**A:** Typically:
- Audit: 1-2 minutes
- Remediation: 5-10 minutes
- Manual tasks: 30-60 minutes (varies)

### Q4: Can I customize the rules?

**A:** Yes:
```bash
# Copy rules file
sudo cp /opt/hardening-tool/hardening_rules.yaml /etc/custom_rules.yaml

# Edit as needed
sudo nano /etc/custom_rules.yaml

# Use custom rules
sudo hardening-tool --audit --rules /etc/custom_rules.yaml
```

### Q5: What if I can't create separate partitions?

**A:** That's okay:
- Tool will mark as "MANUAL"
- System still hardens other areas
- Document exception
- Consider alternatives (bind mounts)

### Q6: How often should I audit?

**A:** Recommended:
- **Weekly:** Automated audits
- **Monthly:** Manual review
- **After changes:** Any system modifications
- **Quarterly:** Full compliance check

### Q7: Can I automate remediation?

**A:** Yes, but carefully:
```bash
# Create cron job (use with caution)
echo "0 2 * * 0 /usr/local/bin/hardening-tool --remediate" | sudo crontab -
```

### Q8: What's the compliance standard?

**A:** Based on:
- CIS Benchmarks
- NIST Guidelines
- Organizational security policies
- Industry best practices

---

## Appendix

### File Locations

| Path | Purpose |
|------|---------|
| `/opt/hardening-tool/` | Installation directory |
| `/opt/hardening-tool/engine.py` | Main engine |
| `/opt/hardening-tool/hardening_rules.yaml` | Rules configuration |
| `/var/lib/hardening/logs/` | Audit reports |
| `/var/lib/hardening/backups/` | Configuration backups |
| `/usr/local/bin/hardening-tool` | Command symlink |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Insufficient permissions |
| 4 | Dependencies missing |

### Support Contacts

- **Technical Support:** security-team@ntro.gov.in
- **Documentation:** https://docs.internal/hardening
- **Issues:** Submit via internal ticketing system

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-01  
**Next Review:** 2025-04-01