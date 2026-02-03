# Architecture Deep Dive

## Table of Contents

1. [Network Architecture](#network-architecture)
2. [Traffic Flows](#traffic-flows)
3. [Security Layers](#security-layers)
4. [High Availability Design](#high-availability-design)
5. [VPC Flow Logs Architecture](#vpc-flow-logs-architecture)
6. [VPC Endpoints Strategy](#vpc-endpoints-strategy)

## Network Architecture

### Three-Tier Subnet Design

Our VPC implements a classic three-tier architecture that separates concerns and provides defense in depth:

```
┌─────────────────────────────────────────────────────────────────┐
│                          VPC (10.0.0.0/16)                      │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ PUBLIC TIER - Internet-Facing Resources                   │  │
│  │ • Application Load Balancer                               │  │
│  │ • NAT Gateway                                             │  │
│  │ • Bastion Host (optional)                                 │  │
│  │ • Route: 0.0.0.0/0 → Internet Gateway                     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ PRIVATE TIER - Application Servers                        │  │
│  │ • Web servers                                             │  │
│  │ • App servers                                             │  │
│  │ • Container instances                                     │  │
│  │ • Route: 0.0.0.0/0 → NAT Gateway (outbound only)          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ DATA TIER - Database Layer                                │  │
│  │ • RDS instances                                           │  │
│  │ • ElastiCache clusters                                    │  │
│  │ • Sensitive data stores                                   │  │
│  │ • Route: NO DEFAULT ROUTE (VPC-only)                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Design?

**Public Tier (10.0.1.0/24, 10.0.2.0/24)**
- Contains only resources that must be publicly accessible
- Minimizes attack surface
- Internet Gateway provides bi-directional internet access

**Private Tier (10.0.10.0/24, 10.0.20.0/24)**
- Application logic runs here
- Can initiate outbound connections (updates, API calls)
- Cannot receive unsolicited inbound connections from internet
- NAT Gateway provides outbound-only internet access

**Data Tier (10.0.100.0/24, 10.0.200.0/24)**
- Most restrictive tier
- NO internet route at all
- Accessible only from private tier
- Uses VPC endpoints for AWS service access

## Traffic Flows

### Inbound User Request

```
Internet User
    │
    ▼
Internet Gateway (Public IP)
    │
    ▼
Application Load Balancer (Public Subnet)
    │ Security Group: Allow 443 from 0.0.0.0/0
    ▼
Application Server (Private Subnet)
    │ Security Group: Allow 8080 from ALB-SG
    ▼
Database Server (Data Subnet)
    │ Security Group: Allow 5432 from App-SG
    ▼
Response flows back (stateful connections)
```

### Outbound Application Request

```
Application Server (Private Subnet)
    │
    ▼
NAT Gateway (Public Subnet)
    │ Uses Elastic IP
    ▼
Internet Gateway
    │
    ▼
External API / Package Repository
```

### AWS Service Access (with VPC Endpoints)

```
Application Server (Private Subnet)
    │
    ▼
VPC Endpoint (Private Subnet)
    │ Private IP, no internet routing
    ▼
AWS Service (S3, ECR, Secrets Manager, etc.)
    │
    └── Reduces cost, improves security
```

## Security Layers

### Layer 1: Network ACLs (Subnet Boundary)

Network ACLs act as stateless firewalls at the subnet level:

**Public Subnet NACL**
```
Inbound Rules:
- Rule 100: Allow TCP 80 from 0.0.0.0/0
- Rule 110: Allow TCP 443 from 0.0.0.0/0
- Rule 120: Allow TCP 22 from <your-ip>/32
- Rule 140: Allow TCP 1024-65535 from 0.0.0.0/0 (ephemeral)

Outbound Rules:
- Rule 100: Allow TCP 80 to 0.0.0.0/0
- Rule 110: Allow TCP 443 to 0.0.0.0/0
- Rule 140: Allow TCP 1024-65535 to 0.0.0.0/0 (ephemeral)
- Rule 150: Allow ALL to VPC CIDR
```

**Private Subnet NACL**
```
Inbound Rules:
- Rule 100: Allow ALL from VPC CIDR
- Rule 140: Allow TCP 1024-65535 from 0.0.0.0/0 (return traffic)

Outbound Rules:
- Rule 100: Allow TCP 80 to 0.0.0.0/0
- Rule 110: Allow TCP 443 to 0.0.0.0/0
- Rule 120: Allow ALL to VPC CIDR
- Rule 140: Allow TCP 1024-65535 to 0.0.0.0/0
```

**Data Subnet NACL**
```
Inbound Rules:
- Rule 100: Allow ALL from VPC CIDR only

Outbound Rules:
- Rule 100: Allow ALL to VPC CIDR only
```

### Layer 2: Security Groups (Instance Boundary)

Security groups are stateful and more granular:

**ALB Security Group**
```
Ingress:
- TCP 443 from 0.0.0.0/0
- TCP 80 from 0.0.0.0/0

Egress:
- ALL to 0.0.0.0/0
```

**Application Security Group**
```
Ingress:
- TCP 8080 from ALB-SG (not a CIDR!)
- TCP 22 from Bastion-SG

Egress:
- ALL to 0.0.0.0/0
```

**Database Security Group**
```
Ingress:
- TCP 5432 from App-SG
- TCP 5432 from Bastion-SG (maintenance)

Egress:
- ALL to VPC CIDR only
```

### Why Security Group References?

Using security group IDs instead of CIDR blocks provides:

1. **Dynamic Updates**: When instances change IPs, rules still work
2. **Clarity**: Clear intent (e.g., "from ALB" vs "from 10.0.1.0/24")
3. **Maintenance**: Change subnet CIDR without updating all SGs
4. **Zero Trust**: Explicit trust relationships

## High Availability Design

### Multi-AZ Deployment

Every tier spans two availability zones:

```
Availability Zone A          Availability Zone B
┌─────────────────┐          ┌─────────────────┐
│ Public Subnet   │          │ Public Subnet   │
│ 10.0.1.0/24     │          │ 10.0.2.0/24     │
│ • NAT Gateway A │          │ • NAT Gateway B │
│ • ALB (active)  │          │ • ALB (active)  │
└─────────────────┘          └─────────────────┘
        │                            │
┌─────────────────┐          ┌─────────────────┐
│ Private Subnet  │          │ Private Subnet  │
│ 10.0.10.0/24    │          │ 10.0.20.0/24    │
│ • App Server(s) │          │ • App Server(s) │
└─────────────────┘          └─────────────────┘
        │                            │
┌─────────────────┐          ┌─────────────────┐
│ Data Subnet     │          │ Data Subnet     │
│ 10.0.100.0/24   │          │ 10.0.200.0/24   │
│ • RDS Primary   │          │ • RDS Standby   │
└─────────────────┘          └─────────────────┘
```

### NAT Gateway High Availability

**Option 1: NAT Gateway per AZ (Production)**
- Each private subnet uses NAT in its own AZ
- If one AZ fails, other AZ is unaffected
- Cost: ~$32/month × 2 = ~$64/month

**Option 2: Single NAT Gateway (Development)**
- All private subnets use one NAT Gateway
- Lower cost but single point of failure
- Cost: ~$32/month

Configure via:
```hcl
single_nat_gateway = false  # High availability
single_nat_gateway = true   # Cost optimization
```

## VPC Flow Logs Architecture

### Dual Destination Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                      VPC Flow Logs                          │
│              (ALL traffic metadata captured)                │
└──────────────────────┬──────────────────────────────────────┘
                       │
           ┌───────────┴───────────┐
           ▼                       ▼
  ┌─────────────────┐    ┌─────────────────┐
  │   CloudWatch    │    │       S3        │
  │     Logs        │    │     Bucket      │
  │                 │    │                 │
  │ • Real-time     │    │ • Long-term     │
  │ • Alerting      │    │ • Compliance    │
  │ • 7-day retain  │    │ • Athena query  │
  │ • Log Insights  │    │ • Parquet fmt   │
  └─────────────────┘    └─────────────────┘
           │                       │
           ▼                       ▼
  ┌─────────────────┐    ┌─────────────────┐
  │  CloudWatch     │    │  Amazon Athena  │
  │   Alarms        │    │   Analytics     │
  └─────────────────┘    └─────────────────┘
```

### Flow Log Format

```
version account-id interface-id srcaddr dstaddr 
srcport dstport protocol packets bytes start 
end action log-status
```

Example log entry:
```
2 123456789012 eni-abc12345 203.0.113.12 10.0.10.5 
43418 443 6 20 4000 1620140661 1620140721 
ACCEPT OK
```

### Use Cases

**Real-time Detection (CloudWatch)**
- Detect port scanning attempts
- Alert on unusual traffic patterns
- Monitor rejected connections
- Track top talkers

**Historical Analysis (S3 + Athena)**
- Compliance reporting
- Forensic investigation
- Cost optimization (data transfer patterns)
- Capacity planning

## VPC Endpoints Strategy

### Gateway Endpoints (Free)

```
┌──────────────────────────────────────────────────────┐
│              S3 Gateway Endpoint                     │
│                                                      │
│  Private Subnet → VPC Endpoint → S3                  │
│  (No NAT, no internet, no cost)                      │
└──────────────────────────────────────────────────────┘
```

**Services**: S3, DynamoDB  
**Cost**: Free  
**Configuration**: Route table entry  

### Interface Endpoints (Hourly charge)

```
┌──────────────────────────────────────────────────────┐
│           Interface VPC Endpoint (ENI)               │
│                                                      │
│  Private Subnet → Private IP → AWS Service           │
│  (No internet, reduces data transfer costs)          │
└──────────────────────────────────────────────────────┘
```

**Services**: ECR, Secrets Manager, SSM, CloudWatch, etc.  
**Cost**: ~$0.01/hour per endpoint + data transfer  
**Configuration**: ENI in private subnets  

### Cost-Benefit Analysis

**Without VPC Endpoints:**
```
Private Instance → NAT Gateway → Internet → S3
Cost: Data processing ($0.045/GB) + data transfer
```

**With VPC Endpoints:**
```
Private Instance → VPC Endpoint → S3
Cost: Interface endpoint ($0.01/hr) or Free (Gateway)
```

**Break-even**: If transferring >10 GB/day, endpoints save money

### Recommended Endpoints

**Always Enable (Gateway - Free):**
- S3
- DynamoDB

**Enable for Heavy Use (Interface):**
- ECR (container images)
- CloudWatch Logs
- Secrets Manager
- SSM (Session Manager instead of bastion)

**Optional:**
- EC2 API
- ECS
- Lambda

## Design Decisions Summary

| Decision | Rationale | Alternative |
|----------|-----------|-------------|
| Three-tier subnets | Separation of concerns, defense in depth | Flat network |
| /24 subnets | Right-sized for most apps (254 IPs) | /16 (wasteful) |
| Data tier no internet | Maximum security for sensitive data | Internet via NAT |
| VPC Flow Logs | Visibility, compliance, troubleshooting | No logging |
| Security group references | Dynamic, clear, maintainable | CIDR blocks |
| Multi-AZ | High availability | Single AZ |
| VPC Endpoints | Cost savings, security | All via NAT |

## Scalability Considerations

### Subnet Sizing

```
/24 subnet = 251 usable IPs (AWS reserves 5)
- .0: Network address
- .1: VPC router
- .2: DNS server
- .3: Future use
- .255: Broadcast

For 100+ instances per AZ: Use /23 or multiple /24s
```

### IP Address Planning

**Current allocation:**
```
Public:  10.0.1.0/24, 10.0.2.0/24     (500 IPs)
Private: 10.0.10.0/24, 10.0.20.0/24   (500 IPs)
Data:    10.0.100.0/24, 10.0.200.0/24 (500 IPs)
Total used: 1,500 IPs out of 65,536
```

**Reserved for growth:**
```
10.0.3.0-9.0: Additional public subnets
10.0.21.0-99.0: Additional private subnets
10.0.201.0-255.0: Additional data subnets
```

## Monitoring and Observability

### Key Metrics to Monitor

**VPC Flow Logs:**
- Rejected connections (potential attacks)
- Top talkers (capacity planning)
- Protocol distribution
- Bytes transferred by destination

**NAT Gateway:**
- Bytes processed
- Packets dropped
- Connection count
- Active connection count

**VPC Endpoints:**
- Bytes transferred (cost optimization)
- Packets processed

### CloudWatch Alarms

Recommended alarms:
```
1. NAT Gateway > 1M packets/min (potential DDoS)
2. Flow Logs REJECT > 1000/min (port scan)
3. VPC Endpoint errors > 10/min
4. Data transfer cost > $100/day
```

## Disaster Recovery

### Backup Strategy

**State:** Terraform state in S3 with versioning  
**Flow Logs:** S3 with lifecycle policies  
**Configuration:** Git repository  

### Recovery Steps

```bash
# 1. Clone repository
git clone <repo>

# 2. Initialize Terraform
terraform init -backend-config="bucket=<state-bucket>"

# 3. Review current state
terraform plan

# 4. Recreate infrastructure
terraform apply

# 5. Verify
terraform output
```

**RTO**: ~15 minutes (infrastructure only)  
**RPO**: 0 (infrastructure as code)
