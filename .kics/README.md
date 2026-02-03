# KICS Security Scanning

This directory contains configuration for [KICS (Keeping Infrastructure as Code Secure)](https://kics.io/) - an open-source security scanner for Infrastructure as Code.

## 🔍 What is KICS?

KICS scans your Terraform code for:
- **Security vulnerabilities** (exposed resources, weak encryption)
- **Compliance violations** (CIS benchmarks, PCI-DSS, HIPAA)
- **Best practice deviations** (resource tagging, naming conventions)
- **Cost optimization opportunities** (unused resources, oversized instances)

## 🚀 How It Works

### Automated Scanning on Pull Requests

When you create a PR to `main` or `master`:

1. **KICS automatically scans** all `.tf` and `.tfvars` files
2. **Results are posted** as a PR comment with severity breakdown
3. **Artifacts are uploaded**:
   - `kics-results-html` - Human-readable report with remediation guidance
   - `kics-results-json` - Machine-readable results
   - `kics-results-sarif` - GitHub Security tab integration
4. **Workflow fails** if CRITICAL or HIGH severity issues are found
5. **Manual review required** before merging

### Manual Scanning (Local Development)

Run KICS locally before pushing:

```bash
# Using Docker (recommended)
docker run -v $(pwd):/path checkmarx/kics:latest scan \
  --path /path \
  --output-path /path/kics-results \
  --output-name results \
  --config /path/.kics/kics.config

# Using Homebrew (macOS)
brew install kics
kics scan --path . --output-path ./kics-results
```

## 📋 Workflow Process

1. **Create PR** with Terraform changes
2. **KICS scan runs automatically**
3. **Review results** in PR comment
4. **Download HTML report** from workflow artifacts
5. **Fix issues** in your Terraform code:
   - Update security group rules
   - Enable encryption
   - Add missing tags
   - Fix resource configurations
6. **Push fixes** - KICS re-scans automatically
7. **Verify scan passes** (green check ✅)
8. **Manually merge** PR

## 🎯 Severity Levels

| Severity | Description | Action Required |
|----------|-------------|-----------------|
| 🔴 **CRITICAL** | Immediate security risk | Must fix before merge |
| 🟠 **HIGH** | Significant security issue | Must fix before merge |
| 🟡 **MEDIUM** | Potential security concern | Recommended to fix |
| 🟢 **LOW** | Minor improvement | Optional fix |
| ℹ️ **INFO** | Best practice suggestion | Optional fix |

## 🔧 Configuration

### Customize Scanning

Edit [`.kics/kics.config`](kics.config) to:
- Exclude specific paths or files
- Disable specific security checks
- Change severity thresholds
- Adjust timeout settings

### Exclude Specific Findings

If a finding is a false positive, add the query ID to `exclude-queries`:

```yaml
exclude-queries:
  - "e38a8e0a-b88b-4902-b3fe-b0fcb17d5c10"  # Example query ID
```

Find query IDs in the KICS results or [KICS documentation](https://docs.kics.io/latest/queries/).

## 🛡️ Common Findings for This Project

Based on your VPC infrastructure, expect findings about:

1. **Flow Logs Encryption** - CloudWatch log group should use KMS
2. **S3 Bucket Logging** - Flow logs bucket should have access logging
3. **Security Group Descriptions** - All rules should have descriptions (✅ already done)
4. **Resource Tags** - All resources should be tagged (✅ already done)
5. **VPC Endpoints** - Private subnets should use VPC endpoints (✅ already done)

## 📚 Resources

- [KICS Official Documentation](https://docs.kics.io/)
- [KICS Queries Database](https://docs.kics.io/latest/queries/)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)

## 🔄 Updating KICS

The GitHub Action uses `checkmarx/kics-github-action@v2.1.0`. To update:

1. Check [latest releases](https://github.com/checkmarx/kics-github-action/releases)
2. Update version in [`.github/workflows/kics-scan.yml`](../.github/workflows/kics-scan.yml)
3. Test with a sample PR

## 💡 Tips

- **Run locally first** before pushing to catch issues early
- **Review HTML reports** - they include detailed remediation steps
- **Don't blindly ignore findings** - understand the security impact
- **Keep KICS updated** - new security checks are added regularly
- **Integrate with IDE** - Use [VS Code KICS extension](https://marketplace.visualstudio.com/items?itemName=checkmarx.kics) for real-time scanning
