#!/usr/bin/env python3
"""
Linux System Hardening Engine
Organization: National Technical Research Organisation
Category: Software | Theme: Cyber Security
"""

import os
import sys
import yaml
import json
import subprocess
import shutil
from datetime import datetime
from pathlib import Path
import tempfile
import hashlib

class Colors:
    """ANSI color codes for terminal output"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

class HardeningEngine:
    """Main hardening engine class"""
    
    def __init__(self, rules_file='hardening_rules.yaml', dry_run=False):
        self.rules_file = rules_file
        self.dry_run = dry_run
        self.rules = {}
        self.results = {
            'passed': [],
            'failed': [],
            'manual': [],
            'skipped': []
        }
        self.rollback_data = {}
        self.backup_dir = f"/var/lib/hardening/backups/{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        # Ensure we're running as root
        if os.geteuid() != 0:
            print(f"{Colors.FAIL}[ERROR] This script must be run as root{Colors.ENDC}")
            sys.exit(1)
            
        # Create necessary directories
        Path(self.backup_dir).mkdir(parents=True, exist_ok=True)
        Path("/var/lib/hardening/logs").mkdir(parents=True, exist_ok=True)
        
    def load_rules(self):
        """Load hardening rules from YAML file"""
        try:
            with open(self.rules_file, 'r') as f:
                self.rules = yaml.safe_load(f)
            print(f"{Colors.OKGREEN}[✓] Rules loaded successfully from {self.rules_file}{Colors.ENDC}")
            return True
        except Exception as e:
            print(f"{Colors.FAIL}[ERROR] Failed to load rules: {e}{Colors.ENDC}")
            return False
    
    def run_command(self, command, shell=True, capture=True):
        """Execute shell command with error handling"""
        try:
            if capture:
                result = subprocess.run(
                    command,
                    shell=shell,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=30
                )
                return result.returncode, result.stdout, result.stderr
            else:
                result = subprocess.run(command, shell=shell, timeout=30)
                return result.returncode, "", ""
        except subprocess.TimeoutExpired:
            return -1, "", "Command timeout"
        except Exception as e:
            return -1, "", str(e)
    
    def backup_file(self, filepath):
        """Backup a file before modification"""
        if not os.path.exists(filepath):
            return None
            
        backup_path = os.path.join(self.backup_dir, filepath.lstrip('/'))
        Path(os.path.dirname(backup_path)).mkdir(parents=True, exist_ok=True)
        
        try:
            shutil.copy2(filepath, backup_path)
            # Store file hash for integrity verification
            with open(filepath, 'rb') as f:
                file_hash = hashlib.sha256(f.read()).hexdigest()
            return {'path': backup_path, 'hash': file_hash}
        except Exception as e:
            print(f"{Colors.WARNING}[WARN] Failed to backup {filepath}: {e}{Colors.ENDC}")
            return None
    
    def check_kernel_module(self, module_name):
        """
        Check if kernel module is properly disabled
        Returns: (is_compliant, current_state, message)
        """
        # Check if module is blacklisted
        blacklist_files = [
            f"/etc/modprobe.d/{module_name}.conf",
            "/etc/modprobe.d/blacklist.conf"
        ]
        
        is_blacklisted = False
        has_install_false = False
        
        for filepath in blacklist_files:
            if os.path.exists(filepath):
                with open(filepath, 'r') as f:
                    content = f.read()
                    if f"blacklist {module_name}" in content:
                        is_blacklisted = True
                    if f"install {module_name} /bin/false" in content or f"install {module_name} /bin/true" in content:
                        has_install_false = True
        
        # Check if module is currently loaded
        rc, stdout, _ = self.run_command(f"lsmod | grep -w {module_name}")
        is_loaded = (rc == 0 and stdout.strip())
        
        # Check if module exists in the system
        rc, stdout, _ = self.run_command(f"modinfo {module_name} 2>/dev/null")
        module_exists = (rc == 0)
        
        if not module_exists:
            return True, "not_available", f"Module {module_name} not available in kernel"
        
        # Proper check: blacklisted AND install /bin/false AND not loaded
        if is_blacklisted and has_install_false and not is_loaded:
            return True, "disabled", f"Module {module_name} properly disabled"
        elif is_loaded:
            return False, "loaded", f"Module {module_name} is currently loaded"
        elif not (is_blacklisted and has_install_false):
            return False, "not_blacklisted", f"Module {module_name} not properly blacklisted"
        else:
            return False, "unknown", f"Module {module_name} state unclear"
    
    def fix_kernel_module(self, module_name):
        """Disable kernel module properly"""
        modprobe_file = f"/etc/modprobe.d/{module_name}.conf"
        
        # Backup if exists
        if os.path.exists(modprobe_file):
            self.backup_file(modprobe_file)
        
        # Create proper blacklist configuration
        config_content = f"""# Disable {module_name} module - Hardening Tool
# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
blacklist {module_name}
install {module_name} /bin/false
"""
        
        try:
            with open(modprobe_file, 'w') as f:
                f.write(config_content)
            
            # Unload module if currently loaded
            self.run_command(f"modprobe -r {module_name} 2>/dev/null")
            
            # Update initramfs
            self.run_command("update-initramfs -u 2>/dev/null || dracut -f 2>/dev/null")
            
            return True, f"Module {module_name} disabled successfully"
        except Exception as e:
            return False, f"Failed to disable module {module_name}: {e}"
    
    def check_partition_exists(self, mount_point):
        """Check if a partition exists and is mounted"""
        rc, stdout, _ = self.run_command(f"findmnt -n {mount_point}")
        
        if rc == 0 and stdout.strip():
            return True, "mounted", f"Partition {mount_point} exists and is mounted"
        
        # Check if it's in fstab but not mounted
        rc, stdout, _ = self.run_command(f"grep -E '^[^#].*{mount_point}' /etc/fstab")
        if rc == 0 and stdout.strip():
            return False, "in_fstab_not_mounted", f"Partition {mount_point} in fstab but not mounted"
        
        return False, "not_exists", f"Partition {mount_point} does not exist"
    
    def check_mount_option(self, mount_point, option):
        """Check if a mount point has a specific option"""
        rc, stdout, _ = self.run_command(f"findmnt -n -o OPTIONS {mount_point}")
        
        if rc != 0:
            return False, "not_mounted", f"Mount point {mount_point} not found"
        
        options = stdout.strip().split(',')
        
        if option in options:
            return True, "set", f"Option {option} is set on {mount_point}"
        else:
            return False, "not_set", f"Option {option} is NOT set on {mount_point}"
    
    def fix_mount_option(self, mount_point, option):
        """Add mount option to a partition"""
        fstab_path = "/etc/fstab"
        
        # Backup fstab
        backup_info = self.backup_file(fstab_path)
        if not backup_info:
            return False, "Failed to backup /etc/fstab"
        
        self.rollback_data['fstab'] = backup_info
        
        try:
            # Read current fstab
            with open(fstab_path, 'r') as f:
                lines = f.readlines()
            
            # Find and update the line for this mount point
            updated = False
            new_lines = []
            
            for line in lines:
                # Skip comments and empty lines
                if line.strip().startswith('#') or not line.strip():
                    new_lines.append(line)
                    continue
                
                parts = line.split()
                if len(parts) >= 4 and parts[1] == mount_point:
                    # Found the mount point
                    device, mount, fstype, options = parts[0], parts[1], parts[2], parts[3]
                    rest = ' '.join(parts[4:]) if len(parts) > 4 else '0 0'
                    
                    # Add option if not present
                    option_list = options.split(',')
                    if option not in option_list:
                        option_list.append(option)
                        options = ','.join(option_list)
                        updated = True
                    
                    new_line = f"{device} {mount} {fstype} {options} {rest}\n"
                    new_lines.append(new_line)
                else:
                    new_lines.append(line)
            
            if not updated:
                return False, f"Mount point {mount_point} not found in /etc/fstab"
            
            # Write updated fstab
            with open(fstab_path, 'w') as f:
                f.writelines(new_lines)
            
            # Remount with new options
            rc, stdout, stderr = self.run_command(f"mount -o remount,{option} {mount_point}")
            
            if rc == 0:
                return True, f"Option {option} added to {mount_point} and remounted"
            else:
                return True, f"Option {option} added to {mount_point} (will apply on next boot)"
                
        except Exception as e:
            # Restore fstab on error
            if backup_info:
                shutil.copy2(backup_info['path'], fstab_path)
            return False, f"Failed to add option: {e}"
    
    def check_filesystem_rules(self):
        """Check all filesystem hardening rules"""
        if 'filesystem' not in self.rules:
            return
        
        print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
        print(f"{Colors.HEADER}{Colors.BOLD}FILESYSTEM HARDENING CHECKS{Colors.ENDC}")
        print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")
        
        # Check kernel modules
        if 'kernel_modules' in self.rules['filesystem']:
            print(f"{Colors.OKCYAN}[*] Checking Kernel Modules...{Colors.ENDC}\n")
            
            for module in self.rules['filesystem']['kernel_modules']:
                module_name = module['name']
                check_id = module['id']
                description = module['description']
                
                print(f"  [{check_id}] {description}")
                
                is_compliant, state, message = self.check_kernel_module(module_name)
                
                if is_compliant:
                    print(f"  {Colors.OKGREEN}[✓ PASS]{Colors.ENDC} {message}")
                    self.results['passed'].append({
                        'id': check_id,
                        'description': description,
                        'status': state,
                        'message': message
                    })
                else:
                    print(f"  {Colors.FAIL}[✗ FAIL]{Colors.ENDC} {message}")
                    self.results['failed'].append({
                        'id': check_id,
                        'description': description,
                        'status': state,
                        'message': message,
                        'module': module
                    })
                print()
        
        # Check partitions
        if 'partitions' in self.rules['filesystem']:
            print(f"\n{Colors.OKCYAN}[*] Checking Filesystem Partitions...{Colors.ENDC}\n")
            
            for partition_group, checks in self.rules['filesystem']['partitions'].items():
                for check in checks:
                    check_id = check['id']
                    description = check['description']
                    check_type = check['check_type']
                    automated = check.get('automated', False)
                    
                    print(f"  [{check_id}] {description}")
                    
                    if check_type == 'partition_exists':
                        mount_point = check['mount_point']
                        is_compliant, state, message = self.check_partition_exists(mount_point)
                        
                        if is_compliant:
                            print(f"  {Colors.OKGREEN}[✓ PASS]{Colors.ENDC} {message}")
                            self.results['passed'].append({
                                'id': check_id,
                                'description': description,
                                'message': message
                            })
                        else:
                            if automated:
                                print(f"  {Colors.WARNING}[! MANUAL]{Colors.ENDC} {message}")
                                print(f"  {Colors.WARNING}Manual intervention required:{Colors.ENDC}")
                                print(f"  {check.get('manual_instruction', 'No instructions available')}")
                                self.results['manual'].append({
                                    'id': check_id,
                                    'description': description,
                                    'message': message,
                                    'instruction': check.get('manual_instruction', '')
                                })
                            else:
                                print(f"  {Colors.FAIL}[✗ FAIL]{Colors.ENDC} {message}")
                                self.results['failed'].append({
                                    'id': check_id,
                                    'description': description,
                                    'message': message
                                })
                    
                    elif check_type == 'mount_option':
                        mount_point = check['mount_point']
                        option = check['option']
                        
                        # First check if partition exists
                        exists, _, _ = self.check_partition_exists(mount_point)
                        
                        if not exists:
                            print(f"  {Colors.WARNING}[! SKIP]{Colors.ENDC} Partition {mount_point} does not exist")
                            self.results['skipped'].append({
                                'id': check_id,
                                'description': description,
                                'message': f"Partition {mount_point} does not exist"
                            })
                        else:
                            is_compliant, state, message = self.check_mount_option(mount_point, option)
                            
                            if is_compliant:
                                print(f"  {Colors.OKGREEN}[✓ PASS]{Colors.ENDC} {message}")
                                self.results['passed'].append({
                                    'id': check_id,
                                    'description': description,
                                    'message': message
                                })
                            else:
                                print(f"  {Colors.FAIL}[✗ FAIL]{Colors.ENDC} {message}")
                                self.results['failed'].append({
                                    'id': check_id,
                                    'description': description,
                                    'message': message,
                                    'check': check
                                })
                    
                    print()
    
    def remediate_filesystem(self):
        """Apply remediations for filesystem checks"""
        print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
        print(f"{Colors.HEADER}{Colors.BOLD}APPLYING FILESYSTEM REMEDIATIONS{Colors.ENDC}")
        print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")
        
        if self.dry_run:
            print(f"{Colors.WARNING}[DRY RUN MODE] No changes will be applied{Colors.ENDC}\n")
        
        # Remediate kernel modules
        failed_modules = [item for item in self.results['failed'] if 'module' in item]
        
        if failed_modules:
            print(f"{Colors.OKCYAN}[*] Remediating Kernel Modules...{Colors.ENDC}\n")
            
            for item in failed_modules:
                module = item['module']
                module_name = module['name']
                check_id = module['id']
                
                print(f"  [{check_id}] Disabling {module_name}...")
                
                if self.dry_run:
                    print(f"  {Colors.WARNING}[DRY RUN]{Colors.ENDC} Would disable module {module_name}")
                else:
                    success, message = self.fix_kernel_module(module_name)
                    
                    if success:
                        print(f"  {Colors.OKGREEN}[✓ FIXED]{Colors.ENDC} {message}")
                    else:
                        print(f"  {Colors.FAIL}[✗ ERROR]{Colors.ENDC} {message}")
                print()
        
        # Remediate mount options
        failed_mounts = [item for item in self.results['failed'] if 'check' in item]
        
        if failed_mounts:
            print(f"\n{Colors.OKCYAN}[*] Remediating Mount Options...{Colors.ENDC}\n")
            
            for item in failed_mounts:
                check = item['check']
                check_id = check['id']
                mount_point = check['mount_point']
                option = check['option']
                
                print(f"  [{check_id}] Adding {option} to {mount_point}...")
                
                if self.dry_run:
                    print(f"  {Colors.WARNING}[DRY RUN]{Colors.ENDC} Would add option {option} to {mount_point}")
                else:
                    success, message = self.fix_mount_option(mount_point, option)
                    
                    if success:
                        print(f"  {Colors.OKGREEN}[✓ FIXED]{Colors.ENDC} {message}")
                    else:
                        print(f"  {Colors.FAIL}[✗ ERROR]{Colors.ENDC} {message}")
                print()
    
    def generate_report(self):
        """Generate detailed hardening report"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        report_file = f"/var/lib/hardening/logs/report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        
        total_checks = sum(len(v) for v in self.results.values())
        passed = len(self.results['passed'])
        failed = len(self.results['failed'])
        manual = len(self.results['manual'])
        skipped = len(self.results['skipped'])
        
        compliance_rate = (passed / total_checks * 100) if total_checks > 0 else 0
        
        report = f"""
{'='*80}
LINUX SYSTEM HARDENING REPORT
Organization: National Technical Research Organisation
{'='*80}
Generated: {timestamp}
Backup Location: {self.backup_dir}

SUMMARY
{'='*80}
Total Checks:        {total_checks}
Passed:              {passed} ({passed/total_checks*100:.1f}%)
Failed:              {failed} ({failed/total_checks*100:.1f}%)
Manual Required:     {manual} ({manual/total_checks*100:.1f}%)
Skipped:             {skipped} ({skipped/total_checks*100:.1f}%)

Compliance Rate:     {compliance_rate:.1f}%

"""
        
        if self.results['passed']:
            report += f"\n{'='*80}\nPASSED CHECKS ({len(self.results['passed'])})\n{'='*80}\n"
            for item in self.results['passed']:
                report += f"\n[{item['id']}] {item['description']}\n"
                report += f"Status: PASS\n"
                report += f"Message: {item['message']}\n"
        
        if self.results['failed']:
            report += f"\n{'='*80}\nFAILED CHECKS ({len(self.results['failed'])})\n{'='*80}\n"
            for item in self.results['failed']:
                report += f"\n[{item['id']}] {item['description']}\n"
                report += f"Status: FAIL\n"
                report += f"Message: {item['message']}\n"
        
        if self.results['manual']:
            report += f"\n{'='*80}\nMANUAL INTERVENTION REQUIRED ({len(self.results['manual'])})\n{'='*80}\n"
            for item in self.results['manual']:
                report += f"\n[{item['id']}] {item['description']}\n"
                report += f"Status: MANUAL\n"
                report += f"Message: {item['message']}\n"
                report += f"\nInstructions:\n{item['instruction']}\n"
                report += f"\n{'-'*80}\n"
        
        if self.results['skipped']:
            report += f"\n{'='*80}\nSKIPPED CHECKS ({len(self.results['skipped'])})\n{'='*80}\n"
            for item in self.results['skipped']:
                report += f"\n[{item['id']}] {item['description']}\n"
                report += f"Status: SKIPPED\n"
                report += f"Message: {item['message']}\n"
        
        report += f"\n{'='*80}\n"
        report += f"END OF REPORT\n"
        report += f"{'='*80}\n"
        
        # Write report to file
        with open(report_file, 'w') as f:
            f.write(report)
        
        # Print summary to console
        print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
        print(f"{Colors.HEADER}{Colors.BOLD}HARDENING SUMMARY{Colors.ENDC}")
        print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")
        print(f"  Total Checks:        {total_checks}")
        print(f"  {Colors.OKGREEN}Passed:              {passed} ({passed/total_checks*100:.1f}%){Colors.ENDC}")
        print(f"  {Colors.FAIL}Failed:              {failed} ({failed/total_checks*100:.1f}%){Colors.ENDC}")
        print(f"  {Colors.WARNING}Manual Required:     {manual} ({manual/total_checks*100:.1f}%){Colors.ENDC}")
        print(f"  {Colors.OKCYAN}Skipped:             {skipped} ({skipped/total_checks*100:.1f}%){Colors.ENDC}")
        print(f"\n  {Colors.BOLD}Compliance Rate:     {compliance_rate:.1f}%{Colors.ENDC}")
        print(f"\n  Report saved to: {report_file}")
        print(f"  Backups saved to: {self.backup_dir}")
        print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}\n")
        
        return report_file
    
    def rollback(self, rollback_dir=None):
        """Rollback changes from a specific backup"""
        if rollback_dir is None:
            rollback_dir = self.backup_dir
        
        print(f"\n{Colors.WARNING}[!] ROLLBACK MODE{Colors.ENDC}")
        print(f"Restoring from: {rollback_dir}\n")
        
        if not os.path.exists(rollback_dir):
            print(f"{Colors.FAIL}[ERROR] Backup directory not found: {rollback_dir}{Colors.ENDC}")
            return False
        
        try:
            # Restore all backed up files
            for root, dirs, files in os.walk(rollback_dir):
                for file in files:
                    backup_file = os.path.join(root, file)
                    original_file = '/' + os.path.relpath(backup_file, rollback_dir)
                    
                    print(f"  Restoring: {original_file}")
                    shutil.copy2(backup_file, original_file)
            
            print(f"\n{Colors.OKGREEN}[✓] Rollback completed successfully{Colors.ENDC}")
            return True
            
        except Exception as e:
            print(f"{Colors.FAIL}[ERROR] Rollback failed: {e}{Colors.ENDC}")
            return False

def main():
    """Main execution function"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Linux System Hardening Tool - Annexure B Implementation',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Audit only (no changes)
  sudo python3 engine.py --audit
  
  # Audit and remediate
  sudo python3 engine.py --remediate
  
  # Dry run (show what would be changed)
  sudo python3 engine.py --remediate --dry-run
  
  # Rollback changes
  sudo python3 engine.py --rollback /var/lib/hardening/backups/20250101_120000
        """
    )
    
    parser.add_argument('--audit', action='store_true', help='Run audit checks only')
    parser.add_argument('--remediate', action='store_true', help='Run audit and apply fixes')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without applying')
    parser.add_argument('--rollback', metavar='BACKUP_DIR', help='Rollback to a specific backup')
    parser.add_argument('--rules', default='hardening_rules.yaml', help='Path to rules file')
    
    args = parser.parse_args()
    
    if not any([args.audit, args.remediate, args.rollback]):
        parser.print_help()
        sys.exit(1)
    
    # Print banner
    print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}Linux System Hardening Tool v1.0{Colors.ENDC}")
    print(f"{Colors.HEADER}Organization: National Technical Research Organisation{Colors.ENDC}")
    print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")
    
    if args.rollback:
        engine = HardeningEngine()
        engine.rollback(args.rollback)
        sys.exit(0)
    
    engine = HardeningEngine(rules_file=args.rules, dry_run=args.dry_run)
    
    if not engine.load_rules():
        sys.exit(1)
    
    # Run audit
    engine.check_filesystem_rules()
    
    # Apply remediations if requested
    if args.remediate:
        engine.remediate_filesystem()
    
    # Generate report
    report_file = engine.generate_report()
    
    print(f"{Colors.OKGREEN}[✓] Hardening process completed{Colors.ENDC}\n")

if __name__ == '__main__':
    main()
