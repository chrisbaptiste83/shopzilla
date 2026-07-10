# ECS Deployment Guide

Last updated: 2026-05-03
Owner: Engineering

## Architecture Overview

```
GitLab CI
    │
    ▼
Amazon ECR  ──────────────────────────────────┐
(container registry)                          │
                                              ▼
Route 53 / registrar ──▶ ALB (HTTPS 443) ──▶ ECS Cluster (EC2)
                          host routing              │
                                                    ▼
                                             ECS Service: shopzilla-web
                                                    │
                                                    ▼
                                             EC2 Instance (t3.micro)
                                                    │
                                             shopzilla container
                                             (Puma on port 3000)
                                                    │
                                         ┌──────────┴──────────┐
                                         ▼                     ▼
                              PostgreSQL on EC2 host     S3 (shopzilla-prod-assets)
```

**Key design decisions:**

- **EC2 launch type** — EC2 instances (not Fargate) host the containers. The instance IAM role grants S3 access without any stored credentials.
- **Dynamic host ports** — `hostPort: 0` in the task definition lets ECS assign a random host port per container. The ALB target group auto-registers each container's port.
- **Direct Puma on port 3000** — the live ECS task runs `./bin/rails server -b 0.0.0.0 -p 3000`. Thruster is not used in the live task.
- **Solid Queue in Puma** — Background jobs run inside the web process (`SOLID_QUEUE_IN_PUMA=true`). No separate worker task needed for current load.
- **Secrets Manager** — All sensitive values (master key, DB URL, Stripe secret) live in AWS Secrets Manager and are injected into containers at launch. No secrets in environment variable plain-text or in the repo.
- **Single-instance rollout tuning** — the service uses `minimumHealthyPercent=0`, `healthCheckGracePeriodSeconds=180`, and `availabilityZoneRebalancing=DISABLED` so a single EC2 instance can replace tasks in place.

---

## Prerequisites

Complete these steps once before the first deploy.

### 1. Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name shopzilla \
  --region us-east-2 \
  --image-scanning-configuration scanOnPush=true
```

### 2. Store Secrets in Secrets Manager

Store each secret individually so IAM policies can grant per-secret access:

```bash
# Rails master key (value from config/master.key)
aws secretsmanager create-secret \
  --name shopzilla/rails-master-key \
  --secret-string "YOUR_MASTER_KEY" \
  --region us-east-2

# PostgreSQL connection URL
aws secretsmanager create-secret \
  --name shopzilla/database-url \
  --secret-string "postgresql://rails:PASSWORD@YOUR_EC2_PRIVATE_IP:5432/shopzilla_production" \
  --region us-east-2

# Stripe secret key
aws secretsmanager create-secret \
  --name shopzilla/stripe-secret-key \
  --secret-string "sk_live_..." \
  --region us-east-2
```

### 3. Create the ECS Task Execution Role

This role lets ECS pull images from ECR and read secrets from Secrets Manager.

```bash
# Create role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ecs-tasks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach AWS managed policy for ECR + CloudWatch
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Allow reading the three Shopzilla secrets
aws iam put-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-name ShopzillaSecretsRead \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": [
        "arn:aws:secretsmanager:us-east-2:570823560193:secret:shopzilla/*"
      ]
    }]
  }'
```

### 4. Runtime S3 Access Comes From the EC2 Instance Profile

The live service does not use an ECS task role. Active Storage and other S3 access come from the EC2 instance profile attached to the ECS host (`ec2-s3-access-role`), which the AWS SDK resolves through IMDS.

### 5. Create the GitHub Actions OIDC Role

Lets GitHub Actions deploy without storing long-lived AWS credentials as GitHub secrets.

```bash
# Create OIDC identity provider (one-time per AWS account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create the role GitHub Actions will assume
aws iam create-role \
  --role-name github-actions-shopzilla \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::570823560193:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:chrisbaptiste83/shopzilla:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }]
  }'

# Grant the role: ECR push + ECS deploy + pass roles
aws iam put-role-policy \
  --role-name github-actions-shopzilla \
  --policy-name ShopzillaDeploy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "iam:PassRole",
        "Resource": [
          "arn:aws:iam::570823560193:role/service-role/ecsTaskExecutionRole"
        ]
      }
    ]
  }'
```

### 6. Create ECS Cluster

The target Shopzilla cluster is named `shopzilla`. The previous shared cluster was named
`default`; Shopzilla production traffic now runs from the dedicated `shopzilla` cluster.

```bash
aws ecs create-cluster \
  --cluster-name shopzilla \
  --region us-east-2
```

### 7. Create CloudWatch Log Group

```bash
aws logs create-log-group \
  --log-group-name /ecs/shopzilla \
  --region us-east-2
```

### 8. Set Up PostgreSQL

The live deployment currently runs PostgreSQL 16 as a Docker container on the ECS EC2 host and connects to it over the host private IP. If you later migrate to RDS, update the `DATABASE_URL` secret and this runbook to match.

### 9. Create the ALB and ECS Service

Do this through the ECS console (Create Service wizard) or with the AWS CLI. Key settings:

- **Launch type**: EC2
- **Task definition**: shopzilla (register it first — see First Deploy below)
- **Service name**: shopzilla-web
- **Desired count**: 1 (scale up when ready)
- **Load balancer**: Application Load Balancer
  - Listener: HTTPS 443, ACM certificate for gloriasembroideryshop.com
  - Target group: container port `3000`, health check path `/up`
  - Deregistration delay: 30 seconds (matches container `stopTimeout`)

---

## First Deploy

### Step 1 — Register the task definition

```bash
aws ecs register-task-definition \
  --cli-input-json file://.aws/task-definition.json \
  --region us-east-2
```

### Step 2 — Build and push the initial image

```bash
aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin \
  570823560193.dkr.ecr.us-east-2.amazonaws.com

docker build --platform linux/amd64 -t shopzilla .

docker tag shopzilla:latest \
  570823560193.dkr.ecr.us-east-2.amazonaws.com/shopzilla:latest

docker push 570823560193.dkr.ecr.us-east-2.amazonaws.com/shopzilla:latest
```

### Step 3 — Create the ECS service (once)

```bash
aws ecs create-service \
  --cluster shopzilla \
  --service-name shopzilla-web \
  --task-definition shopzilla \
  --desired-count 1 \
  --launch-type EC2 \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:us-east-2:570823560193:targetgroup/shopzilla/...,containerName=shopzilla,containerPort=3000" \
  --region us-east-2
```

### Step 4 — Run database migrations (first time only)

```bash
aws ecs run-task \
  --cluster shopzilla \
  --task-definition shopzilla \
  --overrides '{
    "containerOverrides": [{
      "name": "shopzilla",
      "command": ["bin/rails", "db:migrate"]
    }]
  }' \
  --region us-east-2
```

The `docker-entrypoint` script also runs `db:prepare` on each web container start, so migrations run automatically on rolling deploys. The one-time task is only needed if you want to run migrations before the service starts.

---

## Routine Deploys

All routine deploys are automated via GitLab CI:

> Migration note: `.gitlab-ci.yml` is the single authoritative deploy pipeline.
> The old `default` cluster and GitHub Actions workflows are retired.

1. Open a PR against `main`
2. CI runs (tests, security scan, lint)
3. Merge to `main`
4. GitLab CI (`.gitlab-ci.yml`) triggers automatically:
   - Builds a new image tagged with the commit SHA
   - Pushes to ECR
   - Registers a new task definition revision pointing at that image
   - Updates the ECS service — ECS performs a rolling deploy (new task up → old task drained → old task stopped)
5. The ALB health check (`/up`) gates traffic — new containers only receive requests after passing health checks

---

## Environment Variables Reference

| Variable | Where set | Value |
|---|---|---|
| `RAILS_ENV` | Task definition (clear) | `production` |
| `ACTIVE_STORAGE_SERVICE` | Task definition (clear) | `amazon` |
| `SOLID_QUEUE_IN_PUMA` | Task definition (clear) | `true` |
| `RAILS_LOG_TO_STDOUT` | Task definition (clear) | `true` |
| `STRIPE_PUBLISHABLE_KEY` | Task definition (clear) | `pk_live_...` |
| `RAILS_MASTER_KEY` | Secrets Manager | secret |
| `DATABASE_URL` | Secrets Manager | secret |
| `STRIPE_SECRET_KEY` | Secrets Manager | secret |

`ACTIVE_STORAGE_SERVICE` can be changed without a redeploy by updating the task definition:
- `amazon` — production S3 (default)
- `local_mirror_s3` — writes to disk AND S3 (cutover mode)
- `local` — disk only (emergency fallback)

---

## S3 Bucket Layout

The `shopzilla-prod-assets` bucket uses this key structure:

```
shopzilla-prod-assets/
  products/
    <category>/<design>/<size>/
      images/01-preview.png
      thumbnails/01-thumb.png

  downloads/
    purchased/<category>/<design>/<size>/v1/
      01-design.pes

  pipeline/
    manifests/<date>-<batch-id>.json    ← one per import run

  archive/
    embroidery-catalog-<date>/          ← full source backup
```

- `products/` — public assets served by CloudFront (no auth required)
- `downloads/` — private, served via ActiveStorage signed URLs only
- `pipeline/manifests/` — import run audit trail
- `archive/` — read-only backup of source files

---

## Rollback

To roll back to a previous task definition revision:

```bash
# List recent revisions
aws ecs describe-task-definition --task-definition shopzilla --region us-east-2

# Update service to a specific revision number
aws ecs update-service \
  --cluster shopzilla \
  --service shopzilla-web \
  --task-definition shopzilla:REVISION_NUMBER \
  --region us-east-2
```

---

## Monitoring

- **Container logs**: CloudWatch Logs → `/ecs/shopzilla`
- **Service health**: ECS console → shopzilla cluster → shopzilla-web service → Events tab
- **ALB health**: EC2 console → Target Groups → shopzilla → Targets tab (should show `healthy`)
- **Rails health check endpoint**: `GET /up` — returns 200 when the app is booted

---

## Work Log

### 2026-05-03

Completed:

- deployed on ECS EC2 + ECR via GitLab CI
- removed stored AWS credentials from `storage.yml` — ECS EC2 instance IAM role provides S3 access automatically
- updated `config/environments/production.rb` to use `ACTIVE_STORAGE_SERVICE` env var (was hardcoded `:local`)
- updated `config/storage.yml` bucket from `embroidery-files-667` to `shopzilla-prod-assets`
- created `.aws/task-definition.json` with EC2 launch type, dynamic port mapping, Secrets Manager injection
- `.gitlab-ci.yml` is the canonical pipeline — triggers on push to `main`, builds amd64 image, pushes to ECR, rolling ECS deploy
- created this deployment guide
