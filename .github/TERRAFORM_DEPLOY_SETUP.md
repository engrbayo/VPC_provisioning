# Terraform Deploy Pipeline Setup Guide

This guide explains how to set up and use the automated Terraform deployment pipeline.

## 🎯 What This Pipeline Does

### Automatic (on every push to `main` or `develop`):
1. ✅ Runs `terraform fmt -check` (code formatting)
2. ✅ Runs `terraform init` (initialize)
3. ✅ Runs `terraform validate` (syntax check)
4. ✅ Runs `terraform plan` (shows what will change)
5. ✅ Uploads plan as artifact
6. ✅ Comments plan on PR (if it's a pull request)

### Manual Approval Required:
7. ⏸️ **WAITS** for you to review and approve
8. ✅ Runs `terraform apply` (only after approval)
9. ✅ Uploads outputs as artifact

---

## 🔐 Step 1: Configure AWS Credentials

You have two options for AWS authentication:

### Option A: AWS Access Keys (Easier to start)

1. **Create IAM user with programmatic access:**
   ```bash
   # In AWS Console:
   # IAM → Users → Add User
   # Name: github-actions-terraform
   # Access type: Programmatic access
   ```

2. **Attach policies:**
   - `AmazonVPCFullAccess`
   - `AmazonEC2FullAccess`
   - `IAMFullAccess` (for creating KMS keys, roles)
   - `AmazonS3FullAccess` (for flow logs bucket)
   - `CloudWatchLogsFullAccess`

3. **Add secrets to GitHub:**
   ```bash
   # Go to: https://github.com/engrbayo/VPC_provisioning/settings/secrets/actions
   # Click "New repository secret"

   # Add these two secrets:
   AWS_ACCESS_KEY_ID: <your-access-key>
   AWS_SECRET_ACCESS_KEY: <your-secret-key>
   ```

### Option B: OIDC (Recommended for production)

More secure - no long-lived credentials!

1. **Create OIDC provider in AWS IAM**
2. **Create IAM role that GitHub can assume**
3. **Uncomment OIDC section in workflow file**

See: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

---

## 🛡️ Step 2: Set Up Manual Approval

This is **critical** - it prevents accidental deployments!

### Create Production Environment with Protection Rules

1. **Go to Repository Settings:**
   ```
   https://github.com/engrbayo/VPC_provisioning/settings/environments
   ```

2. **Click "New environment"**
   - Name: `production`
   - Click "Configure environment"

3. **Enable "Required reviewers":**
   - ✅ Check "Required reviewers"
   - Add yourself: `engrbayo`
   - (You can add multiple reviewers)

4. **Optional: Add deployment branch rules:**
   - ✅ Check "Deployment branches"
   - Select "Selected branches"
   - Add: `main`

5. **Save protection rules**

**What this does:**
- Terraform plan runs automatically
- Before apply, GitHub pauses and asks for your approval
- You review the plan, then click "Approve and deploy"
- Only then does `terraform apply` run

---

## 🚀 Step 3: Test the Pipeline

### Method 1: Push to Main

```bash
# Make a small change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test Terraform pipeline"
git push origin main
```

**What happens:**
1. Pipeline starts automatically
2. Runs plan, shows what will change
3. **Pauses and waits for approval**
4. You go to Actions tab, click "Review deployments", approve
5. Apply runs and deploys infrastructure

### Method 2: Create a Pull Request

```bash
# Create feature branch
git checkout -b feature/test-pipeline

# Make changes
echo "# Test" >> README.md

# Push and create PR
git add README.md
git commit -m "Test changes"
git push origin feature/test-pipeline
gh pr create --fill
```

**What happens:**
1. Plan runs automatically
2. Plan is posted as PR comment
3. **No apply** (only runs on main branch)
4. You review plan in PR
5. Merge PR → triggers apply (with approval)

---

## 📊 Step 4: Monitor Deployment

### View Running Workflow

```bash
# In terminal
gh run watch

# Or visit:
https://github.com/engrbayo/VPC_provisioning/actions
```

### Review and Approve

1. Go to Actions tab
2. Click on running workflow
3. Click "Review deployments"
4. Review the plan output
5. Click "Approve and deploy" or "Reject"

### Download Artifacts

After deployment:
- **Plan output**: See what changed
- **Terraform outputs**: VPC ID, subnet IDs, etc.

```bash
# Download artifacts
gh run download
```

---

## 🎛️ Workflow Configuration Options

### Trigger Conditions (Edit if needed)

```yaml
on:
  push:
    branches:
      - main        # Runs on push to main
      - develop     # Also runs on develop
    paths:
      - '**.tf'     # Only when .tf files change
      - '**.tfvars' # Or .tfvars files change
```

### Change Terraform Version

```yaml
env:
  TF_VERSION: 1.0  # Change this to your preferred version
```

### Change AWS Region

```yaml
env:
  AWS_REGION: us-east-1  # Change to your region
```

---

## 🔒 Security Best Practices

### ✅ DO:
- Use OIDC instead of access keys (when possible)
- Always require manual approval for production
- Review plans carefully before approving
- Use separate environments for dev/staging/prod
- Limit who can approve deployments

### ❌ DON'T:
- Commit AWS credentials to the repository
- Skip manual approval for production
- Auto-approve infrastructure changes
- Give GitHub Actions more permissions than needed

---

## 🐛 Troubleshooting

### Pipeline Fails at Init

**Error:** `Backend initialization failed`

**Solution:** Configure S3 backend in `main.tf`:
```terraform
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Pipeline Fails at Plan

**Error:** `Error: Invalid AWS credentials`

**Solution:** Check that secrets are set correctly in GitHub

### Approval Not Required

**Error:** Apply runs immediately without approval

**Solution:** Ensure environment protection rules are configured (Step 2)

### Plan Shows Unexpected Changes

**Solution:**
- Check if someone made manual changes in AWS Console
- Review the plan carefully
- Don't approve if something looks wrong

---

## 📋 Complete Workflow Example

```bash
# 1. Make infrastructure changes
vim vpc.tf

# 2. Commit and push
git add vpc.tf
git commit -m "Add new subnet"
git push origin main

# 3. Watch the workflow
gh run watch

# 4. Review plan in Actions tab
# Visit: https://github.com/engrbayo/VPC_provisioning/actions

# 5. Approve deployment
# Click "Review deployments" → "Approve and deploy"

# 6. Monitor apply
# Watch logs in real-time

# 7. Verify infrastructure
aws ec2 describe-vpcs --region us-east-1
```

---

## 🎯 Next Steps

1. ✅ Add AWS credentials to GitHub Secrets (Step 1)
2. ✅ Configure production environment with approval (Step 2)
3. ✅ Test the pipeline with a small change (Step 3)
4. ✅ Set up Slack/email notifications (optional)
5. ✅ Configure remote state backend (recommended)

---

## 📚 Additional Resources

- [GitHub Actions for Terraform](https://github.com/hashicorp/setup-terraform)
- [AWS OIDC for GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)
- [Environment Protection Rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

---

**Your pipeline is now ready!** 🎉

Push to `main` → Plan runs automatically → Review → Approve → Infrastructure deployed!
