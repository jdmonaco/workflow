#!/usr/bin/env /opt/homebrew/bin/bash
# Test runner for WireFlow test suite
# Provides convenient commands for running different test categories

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_DIR="$SCRIPT_DIR/unit"
INTEGRATION_DIR="$SCRIPT_DIR/integration"

# Check for bats
if ! command -v bats &> /dev/null; then
    echo -e "${RED}Error: bats is not installed${NC}"
    echo "Please install bats-core: brew install bats-core"
    exit 1
fi

# Check for modern bash
if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
    echo -e "${YELLOW}Warning: Bash version < 4.0${NC}"
    echo "Tests require bash 4.0+. Using /opt/homebrew/bin/bash"
    if [[ ! -x /opt/homebrew/bin/bash ]]; then
        echo -e "${RED}Error: /opt/homebrew/bin/bash not found${NC}"
        echo "Please install modern bash: brew install bash"
        exit 1
    fi
fi

# Print usage
usage() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    unit [FILE]        Run unit tests (optionally specify file)
    integration [FILE] Run integration tests (optionally specify file)
    all                Run all tests (unit + integration)
    quick              Run quick unit tests only
    coverage           Run tests with coverage analysis
    clean              Clean test artifacts
    help               Show this help message

Options:
    -v, --verbose      Verbose output
    -t, --tap          TAP format output
    -j, --jobs N       Run N tests in parallel
    -f, --filter REGEX Filter tests by name

Examples:
    $0 unit                    # Run all unit tests
    $0 unit utils.bats         # Run specific unit test file
    $0 integration             # Run all integration tests
    $0 all -v                  # Run all tests with verbose output
    $0 quick                   # Run quick unit tests only

EOF
}

# Parse arguments
COMMAND="${1:-help}"
shift || true

VERBOSE=""
TAP=""
JOBS=""
FILTER=""
TEST_FILES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -t|--tap)
            TAP="--formatter tap"
            shift
            ;;
        -j|--jobs)
            JOBS="--jobs $2"
            shift 2
            ;;
        -f|--filter)
            FILTER="--filter $2"
            shift 2
            ;;
        *.bats)
            TEST_FILES="$TEST_FILES $1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Build bats command
build_bats_cmd() {
    local files="$1"
    echo "bats $VERBOSE $TAP $JOBS $FILTER $files"
}

# Run unit tests
run_unit_tests() {
    echo -e "${BLUE}Running Unit Tests...${NC}"

    if [[ ! -d "$UNIT_DIR" ]]; then
        echo -e "${YELLOW}Unit test directory not found. Creating...${NC}"
        mkdir -p "$UNIT_DIR"
    fi

    local files=""
    if [[ -n "$TEST_FILES" ]]; then
        # Convert relative test file names to full paths
        for f in $TEST_FILES; do
            if [[ -f "$UNIT_DIR/$f" ]]; then
                files="$files $UNIT_DIR/$f"
            elif [[ -f "$f" ]]; then
                files="$files $f"
            else
                echo -e "${RED}Test file not found: $f${NC}"
                return 1
            fi
        done
    else
        files="$UNIT_DIR/*.bats"
    fi

    if compgen -G "$UNIT_DIR/*.bats" > /dev/null || [[ -n "$TEST_FILES" ]]; then
        eval "$(build_bats_cmd "$files")"
    else
        echo -e "${YELLOW}No unit tests found in $UNIT_DIR${NC}"
        echo "Example unit test created at: $UNIT_DIR/utils.bats"
        return 0
    fi
}

# Run integration tests
run_integration_tests() {
    echo -e "${BLUE}Running Integration Tests...${NC}"

    if [[ ! -d "$INTEGRATION_DIR" ]]; then
        echo -e "${YELLOW}Integration test directory not found. Creating...${NC}"
        mkdir -p "$INTEGRATION_DIR"
    fi

    local files=""
    if [[ -n "$TEST_FILES" ]]; then
        # Convert relative test file names to full paths
        for f in $TEST_FILES; do
            if [[ -f "$INTEGRATION_DIR/$f" ]]; then
                files="$files $INTEGRATION_DIR/$f"
            elif [[ -f "$f" ]]; then
                files="$files $f"
            else
                echo -e "${RED}Test file not found: $f${NC}"
                return 1
            fi
        done
    else
        files="$INTEGRATION_DIR/*.bats"
    fi

    if compgen -G "$INTEGRATION_DIR/*.bats" > /dev/null || [[ -n "$TEST_FILES" ]]; then
        eval "$(build_bats_cmd "$files")"
    else
        echo -e "${YELLOW}No integration tests found in $INTEGRATION_DIR${NC}"
        echo "Example integration test created at: $INTEGRATION_DIR/workflow-execution.bats"
        return 0
    fi
}

# Run all tests
run_all_tests() {
    echo -e "${BLUE}Running All Tests...${NC}"
    echo

    local failed=0

    run_unit_tests || failed=$((failed + 1))
    echo

    run_integration_tests || failed=$((failed + 1))

    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Some test suites failed${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
    fi
}

# Run quick tests (unit tests only, no slow operations)
run_quick_tests() {
    echo -e "${BLUE}Running Quick Tests (Unit Only)...${NC}"

    # Run only unit tests with no slow operations
    JOBS="${JOBS:---jobs 4}"  # Default to parallel execution for speed
    run_unit_tests
}

# Run tests with coverage
run_coverage() {
    echo -e "${BLUE}Running Tests with Coverage Analysis...${NC}"

    # Check for kcov or similar coverage tool
    if command -v kcov &> /dev/null; then
        echo "Using kcov for coverage analysis"
        kcov --exclude-path=/usr,/opt coverage/ bats "$SCRIPT_DIR"
    else
        echo -e "${YELLOW}Coverage tool not found. Install kcov for coverage analysis${NC}"
        echo "Running tests without coverage..."
        run_all_tests
    fi
}

# Clean test artifacts
clean_test_artifacts() {
    echo -e "${BLUE}Cleaning test artifacts...${NC}"

    # Clean coverage data
    rm -rf "$SCRIPT_DIR/coverage"

    # Clean temp test directories
    rm -rf "$SCRIPT_DIR/tmp"
    rm -rf /tmp/bats.*
    rm -rf /tmp/test-wireflow*

    echo -e "${GREEN}Test artifacts cleaned${NC}"
}

# Main execution
case "$COMMAND" in
    unit)
        run_unit_tests
        ;;
    integration)
        run_integration_tests
        ;;
    all)
        run_all_tests
        ;;
    quick)
        run_quick_tests
        ;;
    coverage)
        run_coverage
        ;;
    clean)
        clean_test_artifacts
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        usage
        exit 1
        ;;
esac