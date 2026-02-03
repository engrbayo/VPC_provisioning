# Security Design Decisions

This document explains the security decisions made in this VPC architecture and the rationale behind them.

## Table of Contents

1. [Defense in Depth Strategy](#defense-in-depth-strategy)
2. [Network Segmentation](#network-segmentation)
3. [Security Groups vs NACLs](#security-groups-vs-nacls)
4. [Data Tier Isolation](#data-tier-isolation)
5. [Least Privilege Access](#least-privilege-access)
6. [Logging and Monitoring](#logging-and-monitoring)
7. [VPC Endpoints Security](#vpc-endpoints-security)
8. [Threat Model](#threat-model)

## Defense in Depth Strategy

### Principle

No single security control is sufficient. We implement multiple overlapping layers:

```
┌─────────────────────────────────────────────────────┐
│ Layer 7: Application-Level Security                 │
│ • Authentication, Authorization                     │
│ • WAF, Input validation                             │
└─────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│ Layer 4-7: Security Groups (Stateful)               │
│ • Instance-level filtering                          │
│ • Security group referencing                        │
└─────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│ Layer 3-4: Network ACLs (Stateless)                 │
│ • Subnet-level filtering                            │
│ • Explicit deny rules                               │
└─────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│ Layer 3: Network Segmentation                       │
│ • Separate subnets per tier                         │
│ • Route table isolation                             │
└─────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│ Layer 2: VPC Isolation                              │
│ • Logically isolated network                        │
│ • Private IP space                                  │
└─────────────────────────────────────────────────────┘
```

### Why Multiple Layers?

**Scenario: Compromised Application Server**

If an attacker compromises an application server:

1. ✅ **Security Groups** prevent lateral movement to other app servers
2. ✅ **NACLs** block subnet-to-subnet attacks
3. ✅ **Data tier routing** prevents database exfiltration via internet
4. ✅ **VPC Flow Logs** detect unusual traffic patterns
5. ✅ **Database SG** restricts access to known application IPs

Even with one layer breached, multiple barriers remain.

## Network Segmentation

### Decision: Three-Tier Architecture

**Why not a flat network?**

❌ **Flat Network:**
```
All resources in 10.0.0.0/16
• Web servers can talk to databases directly
• Database can access internet
• Harder to apply different security policies
```

✅ **Tiered Network:**
```
Public: Internet-facing only
Private: Application logic
Data: Databases, no internet

• Clear boundaries
• Different security policies per tier
• Minimize blast radius
```

### Subnet Sizing: /24 vs /16

**Decision: Use /24 subnets**

**Rationale:**
- 251 usable IPs per subnet sufficient for most applications
- Reduces IP waste (vs /16 with 65,531 IPs)
- Allows room for growth (can add more /24s)
- Industry best practice

**When to use /23 or larger:**
- Container workloads (one IP per pod)
- Very large auto-scaling groups
- Lambda VPC integration at scale

## Security Groups vs NACLs

### When to Use Each

| Aspect | Security Groups | Network ACLs |
|--------|-----------------|--------------|
| **Primary use** | Application access control | Subnet-wide blocks |
| **Best for** | "Who can talk to whom" | "Emergency blocks" |
| **Stateful** | Yes (return traffic automatic) | No (explicit rules needed) |
| **Evaluation** | All rules | Order matters |
| **Granularity** | Instance/ENI | Subnet |

### Decision: Security Groups as Primary Control

**Rationale:**
- More flexible (can reference other SGs)
- Stateful (easier to manage)
- Instance-level granularity
- Can be applied to multiple resources

### Decision: NACLs as Secondary Defense

**Rationale:**
- Subnet-wide emergency blocks
- Explicit deny capability
- Compliance requirements
- Defense against misconfigured SGs

### Example: Why Both?

**Scenario: Block a malicious IP**

```hcl
# NACL: Immediate subnet-wide block
resource "aws_network_acl_rule" "block_malicious_ip" {
  rule_number = 5  # High priority
  protocol    = "-1"
  rule_action = "deny"
  cidr_block  = "203.0.113.0/32"
}

# Security Group: More granular, but requires instances to reference it
# (If SG was misconfigured to allow 0.0.0.0/0, NACL still blocks)
```

## Data Tier Isolation

### Decision: No Internet Route for Data Tier

**Implementation:**
```hcl
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id
  
  # NO default route!
  # Only local VPC route (automatic)
}
```

**Rationale:**
1. **Prevents data exfiltration**: Even if database is compromised, attacker cannot send data out
2. **Reduces attack surface**: No inbound internet attacks possible
3. **Compliance**: Meets PCI-DSS, HIPAA requirements for data isolation
4. **Defense in depth**: Multiple security layers fail, this still protects

### Data Tier Access Patterns

**How do databases get updates?**

❌ **Bad:** Data tier has NAT Gateway route
```
Database → NAT → Internet → Ubuntu repos
(Potential for data exfiltration)
```

✅ **Good:** VPC Endpoints
```
Database → VPC Endpoint → S3 → Updates
(Cannot reach arbitrary internet hosts)
```

✅ **Better:** Bastion host access
```
Admin → Bastion → Database → Manual updates
(Audit trail, controlled access)
```

✅ **Best:** AWS Systems Manager
```
Admin → SSM → Database → Managed updates
(No SSH keys, session logging, IAM auth)
```

## Least Privilege Access

### Decision: Security Group Referencing

**Instead of:**
```hcl
# ❌ CIDR-based rules
resource "aws_security_group_ingress_rule" "app_from_alb" {
  from_port   = 8080
  to_port     = 8080
  cidr_ipv4   = "10.0.1.0/24"  # What if ALB moves?
}
```

**We use:**
```hcl
# ✅ Security group references
resource "aws_security_group_ingress_rule" "app_from_alb" {
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb.id
}
```

**Benefits:**
1. **Intent is clear**: "From ALB" vs "From this CIDR"
2. **Dynamic**: Works even if instances change IPs
3. **Maintainable**: Subnet changes don't break rules
4. **Zero trust**: Explicit trust relationships

### Decision: Database Egress Restricted to VPC

```hcl
resource "aws_vpc_security_group_egress_rule" "db_vpc_only" {
  security_group_id = aws_security_group.database.id
  cidr_ipv4         = var.vpc_cidr  # Not 0.0.0.0/0!
}
```

**Rationale:**
- Even if data tier route table is misconfigured
- Security group still prevents internet access
- Additional layer of protection

## Logging and Monitoring

### Decision: Dual-Destination Flow Logs

**Why both CloudWatch and S3?**

```
┌──────────────────────┐     ┌──────────────────────┐
│    CloudWatch        │     │         S3           │
├──────────────────────┤     ├──────────────────────┤
│ ✅ Real-time alerts   │     │ ✅ Long-term storage  │
│ ✅ Log Insights       │     │ ✅ Lower cost/GB      │
│ ✅ Lambda triggers    │     │ ✅ Athena queries     │
│ ✅ 7-day retention    │     │ ✅ Compliance         │
│ ❌ Expensive at scale │     │ ❌ Not real-time      │
└──────────────────────┘     └──────────────────────┘
```

**Use case matrix:**
| Need | Use |
|------|-----|
| Security alert | CloudWatch |
| Forensic analysis | S3 + Athena |
| Real-time dashboards | CloudWatch |
| 90-day compliance | S3 |
| Cost optimization | S3 after 7 days |

### Decision: Parquet Format for S3

```hcl
destination_options {
  file_format        = "parquet"
  per_hour_partition = true
}
```

**Rationale:**
- 87% smaller than text format
- Much faster Athena queries
- Columnar storage for analytics
- Hourly partitions for efficient queries

### What Flow Logs Capture

```
✅ Source/destination IPs
✅ Source/destination ports
✅ Protocol
✅ Packet/byte counts
✅ Accept/reject actions
✅ Start/end timestamps

❌ Packet contents
❌ Application-layer data
❌ DNS queries
❌ HTTP requests
```

**Privacy note:** Flow logs contain metadata only, not payload.

## VPC Endpoints Security

### Decision: VPC Endpoints for Data Tier

**Why not use NAT Gateway?**

```
❌ Via NAT:
Data Tier → NAT → Internet → S3
• Potential for internet access
• Higher cost
• Data leaves VPC

✅ Via VPC Endpoint:
Data Tier → VPC Endpoint → S3
• Cannot reach other internet hosts
• Lower cost
• Data stays in AWS network
```

### VPC Endpoint Security Groups

```hcl
resource "aws_security_group" "vpc_endpoints" {
  # Allow HTTPS from VPC
  ingress {
    from_port   = 443
    to_port     = 443
    cidr_ipv4   = var.vpc_cidr
  }
}
```

**Rationale:**
- Restrict who can use endpoints
- Audit trail of endpoint usage
- Additional layer if endpoint policy misconfigured

### VPC Endpoint Policies

Best practice endpoint policy:
```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-app-bucket/*"
      ]
    }
  ]
}
```

**Why limit actions?**
- Even if IAM is compromised
- Endpoint policy provides another barrier
- Prevent data exfiltration to arbitrary buckets

## Threat Model

### Threats We Defend Against

| Threat | Defense Layers |
|--------|----------------|
| **DDoS** | • CloudFront/WAF<br>• ALB<br>• NACLs |
| **SQL Injection** | • Application validation<br>• WAF<br>• Database SG limits blast radius |
| **Compromised App Server** | • Security groups prevent lateral movement<br>• Data tier has no internet<br>• Flow logs detect anomalies |
| **Data Exfiltration** | • No internet route from data tier<br>• VPC endpoints instead of NAT<br>• Flow logs track all connections |
| **Port Scanning** | • NACLs block at subnet level<br>• Security groups deny by default<br>• Flow logs alert on rejected connections |
| **Insider Threat** | • IAM policies<br>• VPC Flow Logs (audit trail)<br>• Security group changes logged |
| **Misconfiguration** | • Infrastructure as Code<br>• Multiple review layers<br>• Terraform plan before apply |

### Threats We Acknowledge But Don't Fully Mitigate

| Threat | Why | Mitigation Options |
|--------|-----|-------------------|
| **Application vulnerabilities** | Network layer can't see app logic | WAF, security scanning, code review |
| **Zero-day exploits** | Unknown vulnerabilities | Patch quickly, minimize attack surface |
| **Sophisticated APT** | Determined attacker may bypass | Assume breach, detect & respond |
| **Physical data center attack** | AWS responsibility | Multi-region deployment |

### Assumed Breach Strategy

Even with perfect network security, we plan for compromise:

1. **Detect**: VPC Flow Logs, CloudWatch alarms
2. **Contain**: Security groups limit lateral movement
3. **Investigate**: Flow logs in S3 for forensics
4. **Recover**: Infrastructure as Code for quick rebuild
5. **Learn**: Post-incident review, update defenses

## Security Checklist

Before going to production:

- [ ] VPC Flow Logs enabled to CloudWatch AND S3
- [ ] Data tier has NO default route (verify route table)
- [ ] Security groups use SG references, not 0.0.0.0/0
- [ ] NACLs configured on all subnets
- [ ] VPC Endpoints enabled for frequently used services
- [ ] CloudWatch alarms for security events
- [ ] Bastion host SSH restricted to specific IPs
- [ ] Database backups automated and encrypted
- [ ] Terraform state encrypted and in S3
- [ ] IAM roles follow least privilege
- [ ] All resources tagged for cost tracking
- [ ] Disaster recovery plan tested

## Compliance Mapping

### PCI-DSS Requirements

| Requirement | How We Meet It |
|-------------|----------------|
| 1.2 - Firewall configuration | Security groups, NACLs documented |
| 1.3 - Internet/cardholder data | Data tier isolated from internet |
| 10.1 - Audit trails | VPC Flow Logs to S3 |
| 10.7 - Log retention | S3 lifecycle policies |

### HIPAA Considerations

| Control | Implementation |
|---------|----------------|
| Access Control | Security groups, IAM policies |
| Audit Controls | VPC Flow Logs, CloudTrail |
| Integrity | VPC isolation, encryption |
| Transmission Security | TLS everywhere, VPC Endpoints |

### SOC 2 Type II

| Trust Service | Evidence |
|---------------|----------|
| Security | Security groups, NACLs, flow logs |
| Availability | Multi-AZ, NAT HA |
| Confidentiality | Data tier isolation |
| Processing Integrity | IaC, version control |

## Security Trade-offs

### Cost vs Security

| Decision | Security Benefit | Cost Impact |
|----------|------------------|-------------|
| NAT per AZ | None (availability only) | +$32/month |
| VPC Endpoints | Prevents internet access | +$7-15/month per endpoint |
| Flow Logs to S3 | Long-term forensics | ~$0.50/GB |
| Multiple NACLs | Defense in depth | No cost |

**Recommendation:** Always enable flow logs and data tier isolation (low/no cost). VPC endpoints provide security AND cost savings at scale.

### Usability vs Security

| Feature | Usability Impact | Security Benefit |
|---------|------------------|------------------|
| Bastion host | Need to SSH hop | No direct DB access from internet |
| VPC Endpoints | Transparent | Prevents internet routing |
| Security group references | Easier maintenance | Clearer intent |
| No internet for data tier | Manual updates required | Prevents exfiltration |

**Recommendation:** Use SSM Session Manager instead of bastion to balance usability and security.

## Incident Response Runbook

### Suspected Compromise

1. **Isolate:**
   ```bash
   # Update NACL to block all traffic
   aws ec2 create-network-acl-entry \
     --network-acl-id acl-xxx \
     --rule-number 1 \
     --protocol -1 \
     --rule-action deny \
     --cidr-block 0.0.0.0/0
   ```

2. **Investigate:**
   ```sql
   -- Query flow logs in Athena
   SELECT * FROM vpc_flow_logs
   WHERE srcaddr = '<suspected-ip>'
   AND action = 'ACCEPT'
   ORDER BY start DESC;
   ```

3. **Contain:**
   - Disable IAM credentials
   - Rotate database passwords
   - Update security groups

4. **Recover:**
   ```bash
   # Rebuild from Infrastructure as Code
   terraform destroy -target=aws_instance.compromised
   terraform apply
   ```

## Continuous Improvement

### Security Metrics to Track

- Rejected connections per day (Flow Logs)
- Security group changes (CloudTrail)
- NACL hits on deny rules
- VPC Endpoint usage vs NAT usage
- Mean time to detect/respond

### Regular Reviews

- Quarterly: Review security group rules for unused rules
- Monthly: Analyze flow logs for anomalies
- Weekly: Check CloudWatch alarms
- Daily: Monitor for security group changes

## References

- [AWS VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
