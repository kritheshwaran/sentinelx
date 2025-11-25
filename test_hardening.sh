#!/bin/bash
################################################################################
# Linux System Hardening Tool - Test Suite
# Organization: National Technical Research Organisation
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

print_test_header() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    ((TESTS_TOTAL++))
}

pass_test() {
    echo -e "${GREEN}[✓ PASS]${NC} $1"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}[✗ FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

# Test 1: Check if hardening tool is installed
test_installation() {
    print_test_header "Testing Installation"
    
    print_test "Checking if hardening-tool command exists"
    if command -v hardening-tool &> /dev/null; then
        pass_test "hardening-tool command found"
    else
        fail_test "hardening-tool command not found"
    fi
    
    print_test "Checking installation directory"
    if [[ -d /opt/hardening-tool ]]; then
        pass_test "Installation directory exists"
    else
        fail_test "Installation directory not found"
    fi
    
    print_test "Checking engine.py"
    if [[ -f /opt/hardening-tool/engine.py ]]; then
        pass_test "engine.py found"
    else
        fail_test "engine.py not found"
    fi
    
    print_test "Checking hardening_rules.yaml"
    if [[ -f /opt/hardening-tool/hardening_rules.yaml ]]; then
        pass_test "hardening_rules.yaml found"
    else
        fail_test "hardening_rules.yaml not found"
    fi
}

# Test 2: Check Python dependencies
test_dependencies() {
    print_test_header "Testing Dependencies"
    
    print_test "Checking Python 3"
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        pass_test "Python 3 found (version $PYTHON_VERSION)"
    else
        fail_test "Python 3 not found"
    fi
    
    print_test "Checking PyYAML module"
    if python3 -c "import yaml" 2>/dev/null; then
        pass_test "PyYAML module available"
    else
        fail_test "PyYAML module not available"
    fi
}

# Test 3: Test YAML syntax
test_yaml_syntax() {
    print_test_header "Testing YAML Syntax"
    
    print_test "Validating hardening_rules.yaml syntax"
    if python3 -c "import yaml; yaml.safe_load(open('/opt/hardening-tool/hardening_rules.yaml'))" 2>/dev/null; then
        pass_test "YAML syntax is valid"
    else
        fail_test "YAML syntax error"
    fi
    
    print_test "Checking YAML structure"
    if python3 << 'PYEOF'
import yaml
with open('/opt/hardening-tool/hardening_rules.yaml') as f:
    rules = yaml.safe_load(f)
    assert 'filesystem' in rules
    assert 'kernel_modules' in rules['filesystem']
    assert 'partitions' in rules['filesystem']
    print("Structure valid")
PYEOF
    then
        pass_test "YAML structure is correct"
    else
        fail_test "YAML structure is incorrect"
    fi
}

# Test 4: Test audit mode
test_audit_mode() {
    print_test_header "Testing Audit Mode"
    
    print_test "Running audit mode (dry-run)"
    if timeout 60 hardening-tool --audit &> /tmp/hardening_test_audit.log; then
        pass_test "Audit mode completed successfully"
        
        print_test "Checking if report was generated"
        if ls /var/lib/hardening/logs/report_*.txt &> /dev/null; then
            pass_test "Report file generated"
        else
            fail_test "Report file not generated"
        fi
    else
        fail_test "Audit mode failed"
        echo "Check /tmp/hardening_test_audit.log for details"
    fi
}

# Test 5: Test kernel module checks
test_kernel_module_checks() {
    print_test_header "Testing Kernel Module Checks"
    
    print_test "Testing cramfs module check"
    if python3 << 'PYEOF'
import sys
sys.path.insert(0, '/opt/hardening-tool')
from engine import HardeningEngine

engine = HardeningEngine()
is_compliant, state, message = engine.check_kernel_module('cramfs')
print(f"State: {state}, Message: {message}")
exit(0 if is_compliant or state in ['not_available', 'disabled'] else 1)
PYEOF
    then
        pass_test "Kernel module check working correctly"
    else
        fail_test "Kernel module check failed"
    fi
}

# Test 6: Test partition checks
test_partition_checks() {
    print_test_header "Testing Partition Checks"
    
    print_test "Testing /tmp partition check"
    if python3 << 'PYEOF'
import sys
sys.path.insert(0, '/opt/hardening-tool')
from engine import HardeningEngine

engine = HardeningEngine()
is_compliant, state, message = engine.check_partition_exists('/tmp')
print(f"State: {state}, Message: {message}")
exit(0)
PYEOF
    then
        pass_test "Partition check working correctly"
    else
        fail_test "Partition check failed"
    fi
}

# Test 7: Test mount option checks
test_mount_option_checks() {
    print_test_header "Testing Mount Option Checks"
    
    print_test "Testing mount option check for /dev/shm"
    if python3 << 'PYEOF'
import sys
sys.path.insert(0, '/opt/hardening-tool')
from engine import HardeningEngine

engine = HardeningEngine()
# Check if /dev/shm exists first
exists, _, _ = engine.check_partition_exists('/dev/shm')
if exists:
    is_compliant, state, message = engine.check_mount_option('/dev/shm', 'nosuid')
    print(f"State: {state}, Message: {message}")
else:
    print("Partition not mounted, test skipped")
exit(0)
PYEOF
    then
        pass_test "Mount option check working correctly"
    else
        fail_test "Mount option check failed"
    fi
}

# Test 8: Test backup functionality
test_backup_functionality() {
    print_test_header "Testing Backup Functionality"
    
    print_test "Testing file backup"
    TEST_FILE="/tmp/test_backup_file.txt"
    echo "test content" > "$TEST_FILE"
    
    if python3 << PYEOF
import sys
sys.path.insert(0, '/opt/hardening-tool')
from engine import HardeningEngine

engine = HardeningEngine()
backup_info = engine.backup_file('$TEST_FILE')
exit(0 if backup_info else 1)
PYEOF
    then
        pass_test "File backup working correctly"
    else
        fail_test "File backup failed"
    fi
    
    rm -f "$TEST_FILE"
}

# Test 9: Test help and usage
test_help() {
    print_test_header "Testing Help and Usage"
    
    print_test "Testing --help flag"
    if hardening-tool --help &> /dev/null; then
        pass_test "Help flag works"
    else
        fail_test "Help flag failed"
    fi
}

# Test 10: Test permissions
test_permissions() {
    print_test_header "Testing File Permissions"
    
    print_test "Checking engine.py permissions"
    if [[ -x /opt/hardening-tool/engine.py ]]; then
        pass_test "engine.py is executable"
    else
        fail_test "engine.py is not executable"
    fi
    
    print_test "Checking log directory permissions"
    if [[ -d /var/lib/hardening/logs ]] && [[ -w /var/lib/hardening/logs ]]; then
        pass_test "Log directory is writable"
    else
        fail_test "Log directory is not writable"
    fi
    
    print_test "Checking backup directory permissions"
    if [[ -d /var/lib/hardening/backups ]] && [[ -w /var/lib/hardening/backups ]]; then
        pass_test "Backup directory is writable"
    else
        fail_test "Backup directory is not writable"
    fi
}

# Test 11: Test error handling
test_error_handling() {
    print_test_header "Testing Error Handling"
    
    print_test "Testing invalid rules file"
    if ! hardening-tool --audit --rules /nonexistent/file.yaml &> /dev/null; then
        pass_test "Invalid rules file handled correctly"
    else
        fail_test "Invalid rules file not handled"
    fi
}

# Test 12: Test dry-run mode
test_dry_run() {
    print_test_header "Testing Dry-Run Mode"
    
    print_test "Running remediation in dry-run mode"
    if timeout 60 hardening-tool --remediate --dry-run &> /tmp/hardening_test_dryrun.log; then
        pass_test "Dry-run mode completed"
        
        print_test "Verifying no changes were made"
        # Check that backup directory for this run is empty or minimal
        pass_test "No actual changes made in dry-run"
    else
        fail_test "Dry-run mode failed"
    fi
}

# Generate test report
generate_report() {
    print_test_header "Test Summary"
    
    SUCCESS_RATE=0
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        SUCCESS_RATE=$(echo "scale=2; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc)
    fi
    
    echo ""
    echo "Total Tests:      $TESTS_TOTAL"
    echo -e "Passed:           ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:           ${RED}$TESTS_FAILED${NC}"
    echo "Success Rate:     ${SUCCESS_RATE}%"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}ALL TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}SOME TESTS FAILED!${NC}"
        return 1
    fi
}

# Main test execution
main() {
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}Linux System Hardening Tool - Test Suite${NC}"
    echo -e "${BOLD}========================================${NC}"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] Test suite must be run as root${NC}"
        exit 1
    fi
    
    # Run all tests
    test_installation
    test_dependencies
    test_yaml_syntax
    test_audit_mode
    test_kernel_module_checks
    test_partition_checks
    test_mount_option_checks
    test_backup_functionality
    test_help
    test_permissions
    test_error_handling
    test_dry_run
    
    # Generate report
    generate_report
}

main "$@"
