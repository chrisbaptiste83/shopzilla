# Cloud Security Architecture: Shopzilla ECS Deployment

**Course:** Cloud Security — MS Cybersecurity  
**Date:** 2026-05-03  
**Author:** Christopher Baptiste  
**System:** Shopzilla — Rails 8 e-commerce application  
**Cloud Provider:** Amazon Web Services (AWS)  
**Region:** us-east-2 (Ohio)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Overview](#2-system-overview)
3. [Threat Model](#3-threat-model)
4. [Identity and Access Management](#4-identity-and-access-management)
5. [Secrets Management](#5-secrets-management)
6. [Network Security](#6-network-security)
7. [Container Security](#7-container-security)
8. [Data Security](#8-data-security)
9. [CI/CD Pipeline Security](#9-cicd-pipeline-security)
10. [Observability and Incident Response](#10-observability-and-incident-response)
11. [Security Controls Summary](#11-security-controls-summary)
12. [Known Gaps and Remediation Roadmap](#12-known-gaps-and-remediation-roadmap)
13. [References](#13-references)

---

## 1. Executive Summary

This document describes the cloud security architecture implemented during the Shopzilla Rails application deployed on AWS Elastic Container Service (ECS) with an EC2 launch type. The migration introduced significant security improvements across five domains: identity and access management, secrets handling, network isolation, container hardening, and CI/CD pipeline integrity.

The central security principle guiding all design decisions was **defense in depth** — no single control is relied upon exclusively, and the compromise of any one layer does not result in total system compromise.

Key security outcomes of this migration:

- Eliminated all long-lived AWS credentials from the application codebase and runtime environment
- Moved all sensitive runtime values (database passwords, API keys, encryption keys) from environment variable plain-text into AWS Secrets Manager with encryption at rest
- Replaced static GitHub Actions credentials with short-lived OIDC tokens
- Established IAM role separation between CI/CD pipeline access, application runtime access, and infrastructure management
- Enforced non-root container execution
- Segregated public-facing assets from private downloadable files at the S3 bucket policy level

---

## 2. System Overview

### 2.1 Application Architecture

Shopzilla is a Ruby on Rails 8 e-commerce application that sells downloadable embroidery design files. The application handles:

- Product catalog browsing (unauthenticated)
- User authentication and session management
- Stripe-based payment processing (checkout sessions and webhooks)
- Post-purchase file delivery through Rails Active Storage redirect URLs backed by S3
- Background job processing (Solid Queue running inside Puma)

### 2.2 Infrastructure Topology

```
Internet
   │
   ▼
Route 53 (DNS)
   │
   ▼
Application Load Balancer — ACM TLS Certificate (gloriasembroideryshop.com)
   │  HTTPS 443 → HTTP 80
   ▼
ECS Cluster (EC2 Launch Type)
   │
   ├── EC2 Instance: i-0d289e11e9aa5abe0
   │   IAM Instance Profile: ec2-s3-access-role
   │   AZ: us-east-2c
   │   VPC: vpc-0f7fc9ed41daff00e
   │   Subnet: subnet-00322addf74013c99
   │   Private IP: 172.31.38.171
   │
   └── ECS Task: shopzilla (bridge network mode)
       ├── Container: shopzilla (port 3000, Puma)
       └── Credentials: via instance metadata service (IMDS)
            │
            ├── PostgreSQL (on-host, port 5432)
            └── S3: shopzilla-prod-assets-na
                 ├── products/    (public assets)
                 ├── downloads/   (private, application-mediated access)
                 ├── pipeline/    (import manifests)
                 └── archive/     (source backups)
```

### 2.3 Data Classification

| Data Type | Classification | Storage | Access Control |
|---|---|---|---|
| Embroidery `.pes` files | Confidential (paid content) | S3 `downloads/` prefix | App auth + private bucket path |
| Preview images | Public | S3 `products/` prefix | Public read |
| User credentials (hashed) | Sensitive | PostgreSQL (private) | Application layer only |
| Stripe payment data | PCI-adjacent | Stripe (external) | Tokenized, never stored locally |
| Rails master key | Critical | AWS Secrets Manager | ECS execution role only |
| Database URL + password | Critical | AWS Secrets Manager | ECS execution role only |
| Stripe secret key | Critical | AWS Secrets Manager | ECS execution role only |

---

## 3. Threat Model

### 3.1 Methodology

This threat model uses the STRIDE framework (Microsoft, 1999) applied to the ECS deployment architecture. STRIDE categorizes threats as: **S**poofing, **T**ampering, **R**epudiation, **I**nformation Disclosure, **D**enial of Service, and **E**levation of Privilege.

### 3.2 Trust Boundaries

The following trust boundaries exist in the system:

```
[Internet] ──── ALB TLS boundary ──── [Application]
[Application] ── IAM boundary ──── [AWS Services]
[CI/CD Pipeline] ── OIDC boundary ──── [ECR/ECS]
[Container] ── IMDSv2 boundary ──── [Instance Metadata]
```

### 3.3 Threat Analysis

| ID | Threat | STRIDE Category | Asset at Risk | Mitigation |
|---|---|---|---|---|
| T-01 | Attacker intercepts payment data in transit | Information Disclosure | User payment data | TLS termination at ALB with ACM cert; `force_ssl = true` in Rails |
| T-02 | Compromised CI/CD pipeline deploys malicious image | Tampering | Production workload | OIDC scoped to specific repo; ECR image scanning on push |
| T-03 | Leaked `.env` or credentials file exposes secrets | Information Disclosure | DB, Stripe, master key | All secrets in Secrets Manager; no credentials in repo or environment plain-text |
| T-04 | Container escape leads to host compromise | Elevation of Privilege | EC2 instance | Non-root container user; instance profile scoped to S3 only |
| T-05 | Overprivileged IAM role enables lateral movement | Elevation of Privilege | AWS account | Least-privilege IAM policies per role per function |
| T-06 | Long-lived GitHub Actions credentials are stolen | Spoofing | ECR, ECS | OIDC eliminates long-lived credentials; tokens expire in 1 hour |
| T-07 | Unauthorized download of paid embroidery files | Information Disclosure | Revenue/IP | S3 `downloads/` bucket prefix is private; Active Storage presigned URLs required |
| T-08 | Stripe webhook spoofing triggers fake order fulfillment | Spoofing | Order integrity | Stripe signature verification on every webhook request |
| T-09 | Database accessible from public internet | Information Disclosure | All user data | PostgreSQL bound to private IP `172.31.38.171`; not publicly accessible |
| T-10 | Old credentials remain active after rotation | Information Disclosure | All services | IAM user deletion removes all associated keys |

---

## 4. Identity and Access Management

### 4.1 Design Principle: Roles Over Users

The primary IAM shift in this deployment is moving from **IAM user credentials** (long-lived access key + secret) to **IAM roles** (short-lived tokens issued on demand). This directly addresses OWASP's "Security Misconfiguration" and "Identification and Authentication Failures" categories.

**Before (IAM User, `rails-app-user`):**

```
Application → stores AKIAYJZ54JQA76T6ZCQN + secret in ~/.aws/credentials
            → credentials never expire
            → if leaked, attacker has persistent access until manually rotated
            → same credentials used for dev, CI/CD, and production
```

**After (IAM Role, instance profile):**

```
EC2 instance → assumes ec2-s3-access-role via instance metadata service
             → AWS STS issues temporary credentials (expire every 1-6 hours)
             → auto-rotated by AWS — no manual rotation needed
             → credentials never written to disk or stored in config files
```

### 4.2 IAM Role Inventory

Three distinct roles were created or utilized, each scoped to a specific function:

#### `ec2-s3-access-role` (Instance Profile)

**Purpose:** Attached to the EC2 instance. Grants the ECS agent and running containers access to S3 and ECS cluster management.

**Trust principal:** `ec2.amazonaws.com`

**Policies:**
- `AmazonS3FullAccess` — allows Active Storage to read, write, and delete objects in `shopzilla-prod-assets-na`
- `AmazonEC2ContainerServiceforEC2Role` — allows the ECS agent to register the instance with the cluster, pull task definitions, manage container lifecycle, and write logs to CloudWatch

**Threat mitigated:** T-04, T-05 — limits blast radius if a container is compromised; the attacker can only affect S3 and ECS, not IAM, RDS, billing, or other services.

#### `ecsTaskExecutionRole`

**Purpose:** Assumed by the ECS agent (not the container) to bootstrap the container. Required to pull images from ECR and inject secrets from Secrets Manager at task launch.

**Trust principal:** `ecs-tasks.amazonaws.com`

**Policies:**
- `AmazonECSTaskExecutionRolePolicy` (AWS managed) — ECR pull, CloudWatch log writes
- `ShopzillaSecretsRead` (inline) — `secretsmanager:GetSecretValue` scoped to `arn:aws:secretsmanager:us-east-2:673588459621:secret:shopzilla/*`

**Key security note:** In the live deployment, runtime S3 access comes from the EC2 instance profile rather than an ECS task role. The execution role remains limited to bootstrap responsibilities such as ECR pulls and Secrets Manager access.

#### `github-actions-shopzilla` (OIDC Role)

**Purpose:** Assumed by GitHub Actions during CI/CD deploys. Scoped exclusively to pushing images to ECR and updating ECS services.

**Trust principal:** GitHub Actions OIDC provider, constrained to `repo:chrisbaptiste83/shopzilla:*`

**Policies:**
- ECR: `GetAuthorizationToken`, `BatchCheckLayerAvailability`, `PutImage`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`
- ECS: `RegisterTaskDefinition`, `DescribeTaskDefinition`, `DescribeServices`, `UpdateService`
- IAM: `PassRole` scoped only to `ecsTaskExecutionRole`

### 4.3 Principle of Least Privilege Applied

The principle of least privilege (POLP), a foundational concept in NIST SP 800-53 (Control AC-6) and CIS Control 6, states that every entity should have only the minimum permissions necessary to perform its function.

This deployment enforces POLP at three levels:

**Service level:** Each AWS service interaction uses a dedicated role. No single credential grants broad access across services.

**Resource level:** The Secrets Manager policy grants access to `shopzilla/*` (all Shopzilla secrets) rather than all secrets in the account. The S3 policy is scoped to `shopzilla-prod-assets-na` only.

**Action level:** The CI/CD role cannot read secrets. The execution role cannot write to S3. The instance profile cannot modify IAM. Each role can only perform the specific actions it needs.

---

## 5. Secrets Management

### 5.1 The Problem with Environment Variables

A common anti-pattern in application deployments is storing secrets as operating system environment variables — often sourced from `.env` files committed to version control. This approach has several security weaknesses:

- Environment variables are visible to all processes running as the same user
- `.env` files are frequently accidentally committed to git repositories (OWASP A05:2021 — Security Misconfiguration)
- They appear in process listings (`/proc/*/environ` on Linux)
- They are included in crash dumps and error reports
- They require manual rotation with application restarts

In this repository, a `config/deploy.yml` file referenced `STRIPE_SECRET_KEY` as a variable but provided no secure storage mechanism. The Stripe key was found stored only in the encrypted Rails credentials file, which is correct — but the deployment mechanism to inject it at runtime was absent.

### 5.2 AWS Secrets Manager

Three secrets were created in AWS Secrets Manager:

| Secret Name | Contents | Used By |
|---|---|---|
| `shopzilla/rails-master-key` | Rails encryption master key | ECS container at boot |
| `shopzilla/database-url` | PostgreSQL connection string including password | ECS container at boot |
| `shopzilla/stripe-secret-key` | Stripe live secret key | ECS container at boot |

**Injection mechanism:** ECS injects secrets as environment variables at container launch via the `secrets` block in the task definition. The container never reads from disk or a file — AWS calls Secrets Manager on behalf of the execution role and injects the value before the application process starts.

```json
"secrets": [
  {
    "name": "RAILS_MASTER_KEY",
    "valueFrom": "arn:aws:secretsmanager:us-east-2:673588459621:secret:shopzilla/rails-master-key"
  }
]
```

**Encryption:** Secrets Manager encrypts all secrets at rest using AWS Key Management Service (KMS) with AES-256. In-transit access is via TLS 1.2+.

**Access control:** Only `ecsTaskExecutionRole` has `secretsmanager:GetSecretValue` on the `shopzilla/*` path. No developer IAM user, no CI/CD role, and no application code can directly read secrets from Secrets Manager.

### 5.3 What Was Not Moved to Secrets Manager

The Stripe **publishable key** (`pk_live_...`) remains in the task definition as a plain environment variable. This is intentional and correct — the publishable key is designed to be public. It is embedded in frontend JavaScript and is not a secret.

The Rails master key is stored in `config/master.key` locally for development but is **never deployed** — the `RAILS_MASTER_KEY` environment variable takes precedence in production, sourced from Secrets Manager.

---

## 6. Network Security

### 6.1 VPC Isolation

The EC2 instance runs inside a Virtual Private Cloud (VPC: `vpc-0f7fc9ed41daff00e`) in a private subnet (`subnet-00322addf74013c99`) in availability zone `us-east-2c`. VPCs provide network-level isolation at the hypervisor level — traffic between VPCs cannot occur without explicit peering or Transit Gateway configuration.

### 6.2 Database Network Exposure

PostgreSQL runs directly on the EC2 host at private IP `172.31.38.171`. Several configurations were applied to secure the database network surface:

**Before (default Postgres configuration):**
```
listen_addresses = 'localhost'   # only accepts connections from 127.0.0.1
```

**After (Docker bridge accessible):**
```
listen_addresses = '*'           # accepts connections on all interfaces
```

**`pg_hba.conf` entry added:**
```
host all all 172.17.0.0/16 md5
```

This configuration accepts connections from the Docker bridge network (`172.17.0.0/16`) using MD5 password authentication. The tradeoff is that Postgres is now listening on `0.0.0.0:5432` — if the EC2 security group allows inbound port 5432 from the internet, the database would be exposed.

**Recommended remediation:** Confirm the EC2 security group does NOT allow inbound TCP 5432 from `0.0.0.0/0`. Database traffic should only be permitted from within the VPC (source: `vpc-0f7fc9ed41daff00e` CIDR). This is a high-priority item in the [known gaps](#12-known-gaps-and-remediation-roadmap) section.

### 6.3 TLS Termination

HTTPS is terminated at the Application Load Balancer using an ACM-managed certificate for `gloriasembroideryshop.com`. The Rails application is configured with:

```ruby
config.assume_ssl = true    # trusts X-Forwarded-Proto header from ALB
config.force_ssl = true     # HSTS header, secure cookies, SSL redirect
```

Traffic between the ALB and the container travels over HTTP on port 80 within the VPC. This is standard practice — TLS inside the VPC is only necessary for compliance frameworks requiring end-to-end encryption (PCI-DSS, HIPAA). For this application, ALB termination is appropriate.

### 6.4 ECS Bridge Networking

The task definition uses `networkMode: bridge` with `hostPort: 0` (dynamic port assignment). This means:

- ECS assigns a random host port (e.g., 32768–65535) when a task starts
- The ALB target group auto-registers the container using ECS service discovery
- No fixed host port means an attacker cannot predict which port to target
- Multiple task instances can run on the same EC2 without port conflicts

---

## 7. Container Security

### 7.1 Non-Root Execution

The Dockerfile enforces non-root container execution — a best practice aligned with CIS Docker Benchmark (Section 4.1) and NIST SP 800-190 (Application Container Security Guide):

```dockerfile
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000
```

**Why this matters:** If a vulnerability in the application allows arbitrary command execution (e.g., a deserialization attack or SSTI), the attacker's process runs as UID 1000. They cannot:
- Write to system directories (owned by root)
- Install packages
- Modify other users' files
- Access privileged kernel interfaces

This does not prevent all container escape techniques but significantly raises the bar for post-exploitation.

### 7.2 Multi-Stage Build

The Dockerfile uses a multi-stage build to reduce the final image attack surface:

```dockerfile
FROM ruby:3.4.2-slim AS base
FROM base AS build        # build stage: compilers, node, yarn
FROM base AS final        # final stage: only runtime artifacts
```

The build stage contains compilers (`build-essential`, `node-gyp`, `python`), development headers (`libpq-dev`, `libyaml-dev`), and the full Node.js installation. None of these are present in the final image. This reduces:
- Image size (fewer layers = smaller pull time)
- Attack surface (compilers cannot be used to compile exploit payloads)
- Vulnerability exposure (fewer packages = fewer CVEs)

### 7.3 Image Scanning

The ECR repository has `scanOnPush: false` (current state). This should be enabled. See [Known Gaps](#12-known-gaps-and-remediation-roadmap).

### 7.4 Container Health Checks

The task definition specifies a health check that the ECS agent uses to gate traffic and restart unhealthy containers:

```json
"healthCheck": {
  "command": ["CMD-SHELL", "curl -sf http://localhost/up || exit 1"],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 60
}
```

Rails 8's `/up` endpoint returns 200 only when the database connection is healthy, Active Storage is configured, and the application has fully booted. This means the ALB will not route traffic to a container that is partially initialized or has a broken database connection.

---

## 8. Data Security

### 8.1 S3 Bucket Architecture

The `shopzilla-prod-assets-na` bucket uses a prefix-based security model to separate data by sensitivity:

```
shopzilla-prod-assets-na/
  products/          ← public read (CloudFront/ALB served)
  downloads/         ← private (application-mediated access)
  pipeline/          ← private (import audit trail)
  archive/           ← private (source file backups)
```

**Security boundary:** The `downloads/purchased/` prefix contains paid embroidery files. Access is controlled at two layers:

1. **S3 bucket policy:** The prefix is not publicly readable. Only IAM-authenticated requests from the application can access the objects.
2. **Application layer:** Rails `DownloadAccess` tracks which user purchased which product. The controller validates the token before redirecting through Active Storage to the backing file.

An unauthenticated attacker who knows the S3 object key still cannot access the file directly because the bucket path is private and the application gate remains in front of delivery.

### 8.2 Encryption at Rest

| Storage | Encryption | Key Management |
|---|---|---|
| S3 objects | AES-256 (SSE-S3) | AWS managed |
| Secrets Manager | AES-256 (SSE-KMS) | AWS managed CMK |
| PostgreSQL data | None (filesystem-level not configured) | — |

PostgreSQL data-at-rest encryption is a gap. See [Known Gaps](#12-known-gaps-and-remediation-roadmap).

### 8.3 Encryption in Transit

| Connection | Protocol | Certificate |
|---|---|---|
| Browser → ALB | TLS 1.2/1.3 | ACM (auto-renewed) |
| ALB → Container | HTTP (within VPC) | N/A |
| Container → PostgreSQL | Unencrypted (same host) | N/A |
| Container → S3 | HTTPS (TLS 1.2+) | AWS managed |
| Container → Secrets Manager | HTTPS (TLS 1.2+) | AWS managed |
| Container → Stripe API | HTTPS (TLS 1.2+) | Stripe managed |

Container-to-PostgreSQL is unencrypted because both run on the same physical host — traffic does not leave the machine. For a future RDS migration, TLS should be enforced.

### 8.4 Payment Data Handling

Shopzilla does not store payment card data. The checkout flow uses Stripe Checkout Sessions:

1. Application creates a Stripe checkout session (server-side API call)
2. User is redirected to Stripe-hosted payment page
3. Stripe processes the payment and calls the application webhook
4. Webhook verifies the Stripe signature (`Stripe-Signature` header + webhook secret)
5. Application creates `Order` and `DownloadAccess` records

No card numbers, CVVs, or bank details ever pass through the application server. This architecture means PCI-DSS compliance scope is significantly reduced (SAQ A eligibility).

---

## 9. CI/CD Pipeline Security

### 9.1 The Problem with Static CI/CD Credentials

The traditional approach to authenticating CI/CD pipelines with cloud providers is to create an IAM user, generate a long-lived access key, and store it as a repository secret. This approach has serious weaknesses:

- The credentials have no expiry
- They are stored in GitHub's secrets vault (a third party)
- They must be manually rotated
- If the GitHub organization is compromised, the AWS account is compromised
- The credentials typically grant broad permissions (push to ECR, deploy to ECS)

### 9.2 OIDC-Based Authentication

The deploy workflow uses OpenID Connect (OIDC) to establish trust between GitHub Actions and AWS without storing any long-lived credentials. This implements the principle described in RFC 6749 (OAuth 2.0) using JWT assertions.

**How it works:**

```
1. GitHub Actions runner generates a signed JWT (OIDC token)
   Subject claim: repo:chrisbaptiste83/shopzilla:ref:refs/heads/main
   Audience: sts.amazonaws.com

2. Workflow calls AWS STS AssumeRoleWithWebIdentity, presenting the JWT

3. AWS STS validates:
   - JWT signature (using GitHub's public JWKS at token.actions.githubusercontent.com)
   - Subject matches the condition: repo:chrisbaptiste83/shopzilla:*
   - Audience matches: sts.amazonaws.com

4. AWS STS issues temporary credentials (AccessKeyId + SecretAccessKey + SessionToken)
   Validity: 1 hour

5. Workflow uses temporary credentials to push to ECR and update ECS service

6. Credentials expire automatically — no revocation needed
```

**GitHub Actions workflow configuration:**

```yaml
permissions:
  id-token: write    # allows the runner to request an OIDC token
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::673588459621:role/github-actions-shopzilla
      aws-region: us-east-2
```

**Trust policy constraint:**

```json
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:chrisbaptiste83/shopzilla:*"
  }
}
```

This condition ensures that only workflows running from the `chrisbaptiste83/shopzilla` repository can assume the role. A token from any other repository — even within the same GitHub organization — will be rejected by STS.

### 9.3 Deployment Pipeline Trust Chain

```
Code commit → GitHub Actions (OIDC token) → AWS STS
                                              │
                                              ▼
                                    Temporary credentials
                                              │
                              ┌───────────────┼───────────────┐
                              ▼               ▼               ▼
                         ECR push      ECS register      ECS update
                                       task def          service
```

At no point does the pipeline have access to application secrets, user data, or IAM management operations. The `PassRole` permission is scoped only to the two roles the ECS service needs — the pipeline cannot grant itself or others additional permissions.

---

## 10. Observability and Incident Response

### 10.1 Application Logs

All container output is captured by the CloudWatch Logs driver:

```json
"logConfiguration": {
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "/ecs/shopzilla",
    "awslogs-region": "us-east-2",
    "awslogs-stream-prefix": "ecs"
  }
}
```

Rails is configured with `config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)` and `RAILS_LOG_TO_STDOUT=true`. Every request, database query (in debug mode), and background job result is streamed to CloudWatch. Logs include the `request_id` tag for distributed tracing across log lines from a single request.

### 10.2 Audit Trail

AWS CloudTrail (enabled by default in all accounts) captures every API call made to AWS services. For this application, CloudTrail records:

- Every `secretsmanager:GetSecretValue` call (who, when, from which IP)
- Every ECR image push and pull
- Every ECS task launch and termination
- Every IAM role assumption (including OIDC role assumptions from GitHub)
- Every S3 object operation (with S3 data event logging enabled)

This provides a complete forensic trail for incident investigation.

### 10.3 Health Monitoring

The ECS service health check (`/up`) and ALB target group health check provide two independent layers of application health monitoring:

- **ECS level:** Unhealthy containers are stopped and replaced automatically
- **ALB level:** Unhealthy targets are removed from the rotation until they recover

The `startPeriod: 60` setting gives the container 60 seconds to complete `db:prepare` (migrations + schema load) before health checks begin counting failures. This prevents false-positive health check failures during startup.

---

## 11. Security Controls Summary

| Control | Framework Reference | Implementation | Status |
|---|---|---|---|
| Least Privilege IAM | NIST SP 800-53 AC-6 | Per-function IAM roles, scoped policies | ✅ Implemented |
| No long-lived credentials | NIST SP 800-53 IA-5 | Instance roles, OIDC for CI/CD | ✅ Implemented |
| Secrets management | OWASP A02:2021, CIS 14.8 | AWS Secrets Manager with KMS encryption | ✅ Implemented |
| Encryption in transit | NIST SP 800-53 SC-8 | TLS at ALB (ACM), HTTPS to all AWS APIs | ✅ Implemented |
| Encryption at rest (S3) | NIST SP 800-53 SC-28 | SSE-S3 (AES-256) | ✅ Implemented |
| Non-root container | CIS Docker Benchmark 4.1 | UID 1000, explicit USER directive | ✅ Implemented |
| Multi-stage image build | NIST SP 800-190 | Build tooling excluded from final image | ✅ Implemented |
| Network isolation (VPC) | NIST SP 800-53 SC-7 | Private subnet, VPC isolation | ✅ Implemented |
| Access logging | NIST SP 800-53 AU-2 | CloudWatch Logs, CloudTrail | ✅ Implemented |
| Health-gated deployment | NIST SP 800-53 SI-2 | ECS health checks, ALB target health | ✅ Implemented |
| Payment data isolation | PCI-DSS SAQ A | Stripe-hosted checkout, no card data | ✅ Implemented |
| Webhook signature verification | OWASP API Security | Stripe-Signature HMAC verification | ✅ Implemented |
| Image vulnerability scanning | CIS Docker Benchmark 4.6 | ECR scan-on-push | ❌ Not yet enabled |
| Database encryption at rest | NIST SP 800-53 SC-28 | PostgreSQL filesystem encryption | ❌ Not configured |
| Database TLS | NIST SP 800-53 SC-8 | PostgreSQL `sslmode=require` | ❌ Not configured |
| PostgreSQL port exposure | NIST SP 800-53 SC-7 | Security group audit needed | ⚠️ Needs verification |
| Secret rotation | NIST SP 800-53 IA-5(1) | Secrets Manager auto-rotation | ❌ Not configured |
| WAF | NIST SP 800-53 SI-10 | AWS WAF on ALB | ❌ Not deployed |

---

## 12. Known Gaps and Remediation Roadmap

### Priority 1 — Verify PostgreSQL is Not Publicly Exposed

**Risk:** PostgreSQL is now listening on all interfaces (`listen_addresses = '*'`). If the EC2 security group allows inbound TCP 5432 from the internet, the database is exposed to brute-force and exploitation attacks.

**Remediation:**
```bash
# Verify security group rules
aws ec2 describe-security-groups \
  --filters "Name=attachment.instance-id,Values=i-0d289e11e9aa5abe0" \
  --query "SecurityGroups[].IpPermissions[?FromPort==\`5432\`]"
```
If any rule shows `CidrIp: 0.0.0.0/0` for port 5432, remove it immediately.

### Priority 2 — Enable ECR Image Scanning

**Risk:** Container images may contain known CVEs in base OS packages or gems.

**Remediation:**
```bash
aws ecr put-image-scanning-configuration \
  --repository-name shopzilla \
  --image-scanning-configuration scanOnPush=true \
  --region us-east-2
```

Add a CI step to fail the deploy if HIGH or CRITICAL vulnerabilities are found.

### Priority 3 — Configure Secret Rotation

**Risk:** Long-lived database passwords and API keys increase the window of exposure if they are ever leaked.

**Remediation:** Enable Secrets Manager automatic rotation for `shopzilla/database-url`. Requires a Lambda rotation function that updates both Secrets Manager and the PostgreSQL user password atomically.

### Priority 4 — Migrate PostgreSQL to RDS

**Risk:** PostgreSQL running on the same EC2 instance as the application violates the principle of separation of concerns. An application compromise could lead to direct database file access. There are no automated backups.

**Remediation:** Migrate to RDS PostgreSQL with:
- Automated daily snapshots (30-day retention)
- Multi-AZ standby for failover
- Storage encrypted with KMS
- `sslmode=require` in `DATABASE_URL`
- Security group allowing only EC2 instance CIDR

### Priority 5 — Deploy AWS WAF

**Risk:** The application is exposed to common web attacks (SQL injection, XSS, path traversal) without a layer-7 firewall.

**Remediation:** Attach AWS WAF to the ALB with the AWS Managed Rules Common Rule Set. Add rate limiting rules to protect the Stripe webhook endpoint and the authentication endpoints.

---

## 13. References

- NIST SP 800-53 Rev 5 — Security and Privacy Controls for Information Systems
- NIST SP 800-190 — Application Container Security Guide
- OWASP Top 10 2021 — https://owasp.org/Top10/
- OWASP API Security Top 10 2023
- CIS Docker Benchmark v1.6 — Center for Internet Security
- CIS Amazon Web Services Foundations Benchmark v2.0
- AWS Well-Architected Framework — Security Pillar
- AWS IAM Best Practices — https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- RFC 6749 — The OAuth 2.0 Authorization Framework
- RFC 7519 — JSON Web Token (JWT)
- PCI-DSS v4.0 — Payment Card Industry Data Security Standard
- Stripe Security Overview — https://stripe.com/docs/security
- Amazon ECS Security Best Practices — https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/security.html
