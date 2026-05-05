# Embroidery Storage Redesign Game Plan

Last updated: 2026-04-30
Owner: Codex + Claude Code working sessions

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

Deliverables across sessions:

- `Embroidery::CatalogAuditor` — `rake embroidery_catalog:audit`
- `Embroidery::PackageBuilder` — `rake embroidery_catalog:package`
- `Embroidery::CatalogImporter` — `rake embroidery_catalog:import`
- `Embroidery::SourceCleanup` — `rake embroidery_catalog:cleanup`
- `Embroidery::S3Uploader` — `rake embroidery_catalog:upload`
- `rake active_storage:s3:migrate` and `rake active_storage:s3:verify`

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

Packaging flow now available:

```bash
bin/rails embroidery_catalog:package SOURCE_ROOT=/absolute/path/to/sample_batch OUT_DIR=/absolute/path/to/package_dir
```

Cleanup defaults to dry run and requires an explicit delete confirmation:

```bash
bin/rails embroidery_catalog:cleanup MANIFEST_PATH=/absolute/path/to/package_dir/manifest.json
bin/rails embroidery_catalog:cleanup MANIFEST_PATH=/absolute/path/to/package_dir/manifest.json DRY_RUN=false CONFIRM=DELETE
```

Import from the reviewed package into Rails and Active Storage:

```bash
bin/rails embroidery_catalog:import MANIFEST_PATH=/absolute/path/to/package_dir/manifest.json IMPORT_PRICE_CENTS=500
```

### Phase 2: Curate and fix the sample batch

For the first batch only:

- remove designs with no real downloadable file
- decide whether multiple embroidery files belong to one product or separate products
- confirm naming conventions for category, design, and size
- confirm which preview image should be primary

### Phase 3: Upload the curated batch to S3

After the manifest is reviewed:

- build the reviewed package directory with deterministic keys
- import only from the reviewed package manifest
- let Active Storage write the attached bytes to the currently configured storage service
- verify downloads work through Rails and Active Storage against S3 once the service is switched

### Phase 4: Refactor backend ownership

After the small batch proves out:

- remove success-page download creation logic based on Stripe line items
- make webhook-created order/download records the canonical source
- keep the reviewed manifest as the only import contract instead of raw server directories

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
- hardened checkout and webhook order bookkeeping:
  - checkout now sends `product_quantities` metadata into Stripe checkout sessions
  - webhook now creates one `Payment` per order instead of one payment per product
  - webhook now creates `OrderItem` quantities from metadata instead of assuming quantity `1`
  - added webhook coverage for a mixed multi-item checkout path

Observed blocker:

- local bundle was incomplete in this workspace, so Rails commands that boot the app could not be executed yet

### 2026-04-30

Completed (Claude Code continuation — annotation session):

- resolved the bundle blocker: ran `bundle install` to completion (159 gems now installed including rails 8.0.5 and pg 1.6.3)
- confirmed source catalog structure at `/Users/christopherbaptiste/Desktop/Embroidery Catalog/Bundles`:
  - 55 top-level category directories
  - layout confirmed as `<category>/<size>/<design>` matching the auditor's expected depth
- ran the first live execution of `embroidery_catalog:audit` against the full Bundles root, LIMIT=20:
  - `bin/rails embroidery_catalog:audit SOURCE_ROOT="…/Bundles" LIMIT=20 OUT_DIR=tmp/embroidery_audit_sample`
  - scanned 20 products, all 20 status=ready
  - 5 issues flagged — all `duplicate_s3_prefix` type:
    - `animals/4x4/Bird`, `Bird__2`, `Bird__3` → all collapse to `embroidery/animals/bird/4x4`
    - `animals/10x14/Eo 181 F Here A Chicken There A Chicken__13` and `__20` → same prefix
  - 0 missing embroidery files, 0 missing previews, 0 invalid metadata
  - output at `tmp/embroidery_audit_sample/` (manifest.json, products.csv, issues.csv)
- ran `embroidery_catalog:package` against the same sample:
  - `bin/rails embroidery_catalog:package SOURCE_ROOT="…/Bundles" LIMIT=20 OUT_DIR=tmp/embroidery_package_sample READY_ONLY=true`
  - 20 products packaged, 0 skipped, 72 total files
  - S3-layout directory written to `tmp/embroidery_package_sample/`
  - each design slot has `download/<n>-<filename>.pes` and `preview/<n>-<image>` plus `metadata.json`
  - duplicate prefix designs (Bird variants, Eo 181 duplicates) all landed in same S3 prefix — last-write-wins; those slots need manual curation before S3 upload

Known issues in this batch requiring human review before Phase 3:

- `embroidery/animals/bird/4x4` — three source folders (`Bird`, `Bird__2`, `Bird__3`) map to one prefix; need to decide which is canonical or create distinct slugs
- `embroidery/animals/eo-181-f-here-a-chicken-there-a-chicken/10x14` — two numbered variants (`__13`, `__20`) collapse to one prefix; same decision needed

Known issues in `tmp/embroidery_package_v2` (resolved via duplicate-skip fix):

- `Bird`, `Bird__2`, `Bird__3` → only `Bird` packaged; `Bird__2` and `Bird__3` skipped with reason `duplicate_s3_prefix`
- `Eo 181 F…__13` and `__20` → only `__13` packaged; `__20` skipped

### 2026-04-30 (second pass — Claude Code continued)

Completed:

- fixed `Embroidery::PackageBuilder` to track seen S3 prefixes and skip duplicates (first occurrence wins, rest go to `skipped_products` with reason `duplicate_s3_prefix`)
- built `Embroidery::S3Uploader`:
  - reads `packaged_products` from the package manifest
  - collects embroidery files, preview images, and `metadata.json` for each product
  - uploads each file to S3 under the exact `proposed_s3_key` path
  - supports `DRY_RUN=true` (default), `OVERWRITE=false` (skips existing keys), and server-side encryption (`AES256`)
  - writes `upload_report.json` beside the manifest
  - reads bucket and region from `config/storage.yml` automatically, or accepts `S3_BUCKET=` / `S3_REGION=` overrides
- added `rake embroidery_catalog:upload` task wrapping S3Uploader
- added `rake active_storage:s3:migrate` and `rake active_storage:s3:verify` tasks for migrating existing ActiveStorage blobs to S3 post-import
- enabled `local_mirror_s3` service in `config/storage.yml` (primary: local, mirrors: [amazon]) for the mirror-mode cutover phase
- re-ran package with `OUT_DIR=tmp/embroidery_package_v2`: 17 packaged, 3 skipped (duplicate prefixes correctly excluded)
- ran `embroidery_catalog:upload DRY_RUN=true` against v2 manifest: 68 files, 3.63 MB, bucket `embroidery-files-667`, 0 errors
- current agreed bucket for this pipeline is `shopzilla-dev-assets`; any future dry runs or live uploads should target that bucket instead of `embroidery-files-667`

S3 upload format (the canonical key shape written to S3):

```text
embroidery/<category-slug>/<design-slug>/<size-slug>/download/01-<filename>.pes
embroidery/<category-slug>/<design-slug>/<size-slug>/preview/01-<image>.png
embroidery/<category-slug>/<design-slug>/<size-slug>/preview/02-<image>_grid.png
embroidery/<category-slug>/<design-slug>/<size-slug>/metadata.json
```

All upload keys are stable and deterministic — derived from the normalized slug pipeline in `CatalogAuditor`.

Next recommended step:

- run the full pipeline end-to-end on the dev database:
  1. `bin/rails embroidery_catalog:import MANIFEST_PATH=tmp/embroidery_package_v2/manifest.json IMPORT_PRICE_CENTS=500`
  2. verify products and attachments in Rails dev DB
  3. when credentials are available: `bin/rails embroidery_catalog:upload MANIFEST_PATH=tmp/embroidery_package_v2/manifest.json DRY_RUN=false`
  4. verify with `bin/rails active_storage:s3:verify LIMIT=100`
- scale up: run audit + package on the full 55-category Bundles root, resolve any new duplicate prefix issues found, then import + upload in batches
- cutover production: deploy with `ACTIVE_STORAGE_SERVICE=local_mirror_s3`, run `active_storage:s3:migrate`, verify, then switch to `ACTIVE_STORAGE_SERVICE=amazon`

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
