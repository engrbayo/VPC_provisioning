#!/bin/bash
# Local KICS scanner for Terraform code
# Run this before creating a PR to catch issues early

set -e

echo "🔒 Running KICS Security Scan Locally..."
echo ""

# Create results directory test
mkdir -p kics-results

# Check if KICS is installed natively
if command -v kics &> /dev/null; then
    echo "✓ Found KICS installed locally"
    echo ""
    echo "🔍 Scanning Terraform files..."
    echo ""

    kics scan \
      --path . \
      --exclude-paths ".terraform/**,.git/**,.kics/**,kics-results/**" \
      --output-path ./kics-results \
      --output-name results \
      --report-formats json,html,sarif \
      --type terraform \
      --fail-on high,critical

    SCAN_EXIT_CODE=$?

# Check if Docker is available and running
elif command -v docker &> /dev/null && docker info &> /dev/null; then
    echo "✓ Using Docker to run KICS"
    echo ""
    echo "📦 Pulling latest KICS image..."
    docker pull checkmarx/kics:latest

    echo ""
    echo "🔍 Scanning Terraform files..."
    echo ""

    docker run --rm \
      -v "$(pwd):/path" \
      checkmarx/kics:latest scan \
      --path /path \
      --exclude-paths "/path/.terraform/**,/path/.git/**,/path/.kics/**" \
      --output-path /path/kics-results \
      --output-name results \
      --report-formats json,html,sarif \
      --type terraform \
      --fail-on high,critical \
      --verbose

    SCAN_EXIT_CODE=$?

else
    echo "❌ Error: KICS is not installed and Docker is not available"
    echo ""
    echo "Install KICS using Homebrew (recommended for macOS):"
    echo "  brew install kics"
    echo ""
    echo "Or install Docker Desktop:"
    echo "  https://docs.docker.com/desktop/install/mac-install/"
    echo ""
    exit 1
fi

echo ""
echo "=================================================="
echo "📊 KICS Scan Complete!"
echo "=================================================="
echo ""

# Check if results exist
if [ -f "kics-results/results.json" ]; then
    # Parse results
    TOTAL=$(jq '.total_counter' kics-results/results.json)
    CRITICAL=$(jq '.severity_counters.CRITICAL // 0' kics-results/results.json)
    HIGH=$(jq '.severity_counters.HIGH // 0' kics-results/results.json)
    MEDIUM=$(jq '.severity_counters.MEDIUM // 0' kics-results/results.json)
    LOW=$(jq '.severity_counters.LOW // 0' kics-results/results.json)
    INFO=$(jq '.severity_counters.INFO // 0' kics-results/results.json)

    echo "Results Summary:"
    echo "  🔴 Critical: $CRITICAL"
    echo "  🟠 High:     $HIGH"
    echo "  🟡 Medium:   $MEDIUM"
    echo "  🟢 Low:      $LOW"
    echo "  ℹ️  Info:     $INFO"
    echo "  ━━━━━━━━━━━━━━━━"
    echo "  📊 Total:    $TOTAL"
    echo ""

    # Open HTML report if available
    if [ -f "kics-results/results.html" ]; then
        echo "📄 Detailed report: kics-results/results.html"

        # Open in default browser (macOS/Linux)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "🌐 Opening report in browser..."
            open kics-results/results.html
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open kics-results/results.html 2>/dev/null || echo "Open manually: kics-results/results.html"
        fi
    fi

    echo ""

    # Exit with appropriate code
    if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
        echo "❌ Scan failed: Found CRITICAL or HIGH severity issues"
        echo "⚠️  Fix these issues before creating a PR"
        exit 1
    else
        echo "✅ Scan passed: No critical or high severity issues found"
        echo "💡 Review medium/low findings when possible"
        exit 0
    fi
else
    echo "⚠️  No results file found. Check for errors above."
    exit $SCAN_EXIT_CODE
fi
