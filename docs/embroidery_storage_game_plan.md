# Embroidery Storage Redesign Game Plan

Last updated: 2026-04-28
Owner: Codex working session

## Purpose

This document is the working record for the embroidery catalog and storage redesign. It has two jobs:

1. Capture the current state clearly enough to reason about cleanup and migration.
2. Record each concrete step taken so the process can be reviewed and repeated.

## Current State Findings

### Source of truth is split

- Raw embroidery bundles were copied onto the app server filesystem.
- A custom import process then created `Category` and `Product` records from those directories.
- Product downloads are represented in Rails through `ActiveStorage` attachments and `DownloadAccess` tokens.

### The current import path is filesystem-driven

From [Shopzilla Pipeline.md](</Users/christopherbaptiste/Desktop/Development/Shopzilla/Shopzilla Pipeline.md>), the expected folder layout is:

- `<root>/<category>/<size>/<design>/...`

Each design directory may contain:

- one or more embroidery files such as `.pes`
- optional preview images
- optional `metadata.json`

### The current backend boundaries are weak

- Filesystem organization, import logic, and product modeling are tightly coupled.
- `PagesController#success` rebuilds download access from Stripe line item descriptions instead of relying only on the webhook/order pipeline.
- The app is partly prepared for S3 via Active Storage, but there is no clean catalog audit step before import or migration.

## Target State

### Storage

- S3 becomes the durable store for embroidery downloads and preview assets.
- The app server stops being the long-term home of the embroidery catalog.
- Rails continues to use Active Storage, but the catalog is organized before attachment/import instead of after the fact.

### Catalog shape

Each importable design should become one normalized product unit with:

- category
- design name
- size
- one canonical embroidery file payload
- zero to two preview images
- optional metadata such as stitch count

### Purchase and delivery

- Stripe webhook is the only place that creates orders, payments, and download access.
- The download endpoint validates ownership and token state, then redirects to the Active Storage-backed object URL.
- Success pages should read existing persisted order/download records instead of rebuilding them from Stripe presentation data.

## Proposed S3 Layout

Proposed object prefix per design:

```text
embroidery/<category-slug>/<design-slug>/<size-slug>/
```

Proposed contents:

```text
embroidery/<category>/<design>/<size>/download/01-original-file.pes
embroidery/<category>/<design>/<size>/preview/01-cover.jpg
embroidery/<category>/<design>/<size>/preview/02-alt.jpg
embroidery/<category>/<design>/<size>/metadata.json
```

Why this layout:

- stable and predictable
- easy to batch upload
- easy to diff against a manifest
- avoids dumping thousands of unrelated files into one prefix

## Migration Strategy

### Phase 1: Audit a small batch

Goal:
Turn a chosen raw folder subset into a reviewed manifest before any migration work touches the live catalog.

Deliverable added in this session:

- `Embroidery::CatalogAuditor`
- `rake embroidery_catalog:audit`

What it does:

- scans folders in `<category>/<size>/<design>` form
- identifies embroidery files and preview images
- normalizes slugs and human-readable titles
- proposes deterministic S3 keys
- exports JSON and CSV for review
- flags obvious issues:
  - missing embroidery files
  - missing preview images when required
  - duplicate normalized S3 prefixes

Example run:

```bash
cd shopzilla
bin/rails embroidery_catalog:audit SOURCE_ROOT=/absolute/path/to/sample_batch LIMIT=50
```

Optional strict preview requirement:

```bash
bin/rails embroidery_catalog:audit SOURCE_ROOT=/absolute/path/to/sample_batch REQUIRE_PREVIEW=true
```

Default output directory:

```text
shopzilla/tmp/embroidery_catalog_audit
```

Generated files:

- `manifest.json`
- `products.csv`
- `issues.csv`

### Phase 2: Curate and fix the sample batch

For the first batch only:

- remove designs with no real downloadable file
- decide whether multiple embroidery files belong to one product or separate products
- confirm naming conventions for category, design, and size
- confirm which preview image should be primary

### Phase 3: Upload the curated batch to S3

After the manifest is reviewed:

- upload files to the exact proposed keys
- attach/import only reviewed files
- verify downloads work through Rails and Active Storage against S3

### Phase 4: Refactor backend ownership

After the small batch proves out:

- remove success-page download creation logic based on Stripe line items
- make webhook-created order/download records the canonical source
- add a dedicated import/migration service that reads the reviewed manifest instead of raw server directories

## Work Log

### 2026-04-28

Completed:

- inspected repo structure and current Rails models/controllers for products, downloads, storage, checkout, and Stripe webhook flow
- reviewed `Shopzilla Pipeline.md` to reconstruct the existing import and S3 migration assumptions
- identified the main architecture breakpoints:
  - filesystem is treated as de facto catalog source
  - download creation logic is split between webhook and success page
  - no audit/curation layer exists before import or S3 placement
- added a first-pass audit tool for small-batch catalog cleanup:
  - [catalog_auditor.rb](/Users/christopherbaptiste/Desktop/Development/Shopzilla/shopzilla/app/services/embroidery/catalog_auditor.rb)
  - [embroidery_catalog.rake](/Users/christopherbaptiste/Desktop/Development/Shopzilla/shopzilla/lib/tasks/embroidery_catalog.rake)
  - [catalog_auditor_test.rb](/Users/christopherbaptiste/Desktop/Development/Shopzilla/shopzilla/test/services/embroidery/catalog_auditor_test.rb)
- set up branch workflow for team-style delivery:
  - `feature/embroidery-storage-redesign` for implementation
  - `dev` for integration testing before promotion to `main`
- removed success-page dependency on live Stripe lookups and line-item title matching:
  - success page now reads persisted `Order` and `DownloadAccess` records for the checkout session
  - added controller tests covering matching-order and missing-order behavior

Observed blocker:

- local bundle is incomplete in this workspace, so Rails commands that boot the app could not be executed yet

Next recommended step:

- run the new audit task against a deliberately small sample directory, ideally 20 to 50 designs from one category

## Decision Record

### Decision: Start with manifest generation before live migration

Reason:

- The file organization problem is bigger than the storage provider problem.
- Moving disorganized files directly to S3 would preserve the mess and make cleanup harder.
- A reviewable manifest creates a stable contract between raw intake, product creation, and storage layout.

### Decision: Keep Active Storage for delivery, improve catalog prep

Reason:

- Direct purchase downloads already fit the current app shape reasonably well through `DownloadAccess` and Active Storage.
- The immediate failure is not the existence of Active Storage. The failure is the lack of an explicit catalog normalization layer.
