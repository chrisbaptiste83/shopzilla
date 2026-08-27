# Reference Index

Last updated: 2026-08-20
Context: `main`

This index collects the most relevant documentation for the current embroidery catalog, checkout, download, and storage redesign work.

## Core Rails

### Active Storage Overview

Link:

- https://guides.rubyonrails.org/active_storage_overview.html

Why it matters:

- S3 service configuration and the production storage contract
- `has_one_attached` and `has_many_attached`
- blob URL and download behavior
- direct uploads if we later remove app-server-mediated upload paths

Most relevant sections:

- Setup
- S3 Service
- Attaching Files to Records
- Linking to Files
- Direct Uploads

### Active Record Associations

Link:

- https://guides.rubyonrails.org/association_basics.html

Why it matters:

- clarifies ownership between `Order`, `Payment`, `OrderItem`, and `DownloadAccess`
- helps keep the order pipeline coherent as we remove duplicate logic

Most relevant sections:

- `belongs_to`
- `has_one`
- `has_many`
- association options such as `dependent`

### Action Controller Overview

Link:

- https://guides.rubyonrails.org/action_controller_overview.html

Why it matters:

- download authorization flow
- success page request flow
- webhook controller behavior
- controller callback boundaries

Most relevant sections:

- Parameters
- Controller Callbacks
- Redirecting and Rendering

### Testing Rails Applications

Link:

- https://guides.rubyonrails.org/testing.html

Why it matters:

- controller and integration coverage for checkout, webhook, and downloads
- fixtures and request testing patterns used in this repo

Most relevant sections:

- Test Setup
- Fixtures
- Functional Testing for Controllers
- Integration Testing

### Active Job Basics

Link:

- https://guides.rubyonrails.org/active_job_basics.html

Why it matters:

- likely next step for bulk audit/import/migration tasks
- useful if S3 backfill or verification needs background execution

Most relevant sections:

- Create and Enqueue Jobs
- Queues
- Exceptions
- Job Testing

## Stripe

### Checkout Sessions API

Link:

- https://docs.stripe.com/payments/checkout-sessions

Why it matters:

- current checkout flow is built on Checkout Sessions
- documents session lifecycle and metadata usage

Most relevant sections:

- Checkout lifecycle
- Store information in metadata

### Metadata

Link:

- https://docs.stripe.com/metadata

Why it matters:

- applies directly to `user_id`, `order_id`, `product_ids`, and `product_quantities`
- important for understanding what does and does not persist across Stripe objects and events

Most relevant sections:

- Configuration
- Copy metadata to another object
- Events and webhook endpoints

## AWS / S3

### Naming Amazon S3 Objects

Link:

- https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html

Why it matters:

- informs the S3 key strategy from the catalog auditor
- helps avoid bad object key shapes before upload

Most relevant sections:

- Object key naming guidelines
- Safe characters
- Prefix limitations
- Object key sort order

### Presigned URLs

Link:

- https://docs.aws.amazon.com/cli/latest/reference/s3/presign.html

Why it matters:

- only relevant if we choose to issue raw S3 presigned download URLs instead of relying on Active Storage delivery

Most relevant sections:

- `presign`
- `--expires-in`

## GitHub Workflow

### Pull Requests Documentation

Link:

- https://docs.github.com/pull-requests

Why it matters:

- matches the branch and review workflow for this project:
  - feature branch
  - PR into `dev`
  - validation on `dev`
  - PR from `dev` into `main`

### Creating a Pull Request

Link:

- https://docs.github.com/articles/creating-a-pull-request?tool=cli

Why it matters:

- directly matches the `gh pr create` flow now being used in this repo

## Repo Documents

### Embroidery Storage Redesign Game Plan

Link:

- [embroidery_storage_game_plan.md](/Users/christopherbaptiste/Desktop/Development/Shopzilla/shopzilla/docs/embroidery_storage_game_plan.md)

Why it matters:

- this is the running project record for the redesign
- includes findings, decisions, migration phases, and work log

### Cloud Security Architecture

Link:

- [cloud_security_architecture.md](/Users/christopherbaptiste/Desktop/Development/Shopzilla/docs/cloud_security_architecture.md)

Why it matters:

- full security analysis of the ECS deployment: IAM, secrets management, network security, container hardening, CI/CD pipeline trust model
- STRIDE threat model for the application
- NIST SP 800-53 / CIS / OWASP control mapping
- known gaps and remediation roadmap

### ECS Deployment Runbook

Link:

- [ecs_deployment.md](/Users/christopherbaptiste/Desktop/Development/Shopzilla/shopzilla/docs/ecs_deployment.md)

Why it matters:

- step-by-step guide for first deploy and routine deploys
- IAM role creation commands
- environment variable and secrets reference
- rollback procedure

### Historical Pipeline Notes

Link:

- [Shopzilla Pipeline.md](/Users/christopherbaptiste/Desktop/Development/Shopzilla/Shopzilla%20Pipeline.md)

Why it matters:

- captures the old server-driven import and migration process that this redesign is replacing

## Suggested Study Order

1. Read [embroidery_storage_game_plan.md](/Users/christopherbaptiste/Desktop/Development/Shopzilla/shopzilla/docs/embroidery_storage_game_plan.md).
2. Read Rails Active Storage Overview.
3. Read Stripe Checkout Sessions API and Stripe Metadata.
4. Read AWS S3 object key naming guidelines.
5. Read Rails Associations and Action Controller Overview.
6. Read Rails Testing guide before expanding test coverage.
