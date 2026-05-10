# Embroidery Storage Redesign Game Plan

Last updated: 2026-05-10
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
- one high-quality rendered preview image (generated from the PES file)
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
embroidery/<category>/<design>/<size>/preview/01-preview.png     ← rendered from PES (not a bundled image)
embroidery/<category>/<design>/<size>/metadata.json
```

Why this layout:

- stable and predictable
- easy to batch upload
- easy to diff against a manifest
- avoids dumping thousands of unrelated files into one prefix

## Preview Image Generation

As of 2026-05-10, the pipeline renders product preview images directly from the PES embroidery file rather than copying the low-quality bundled PNGs that come with the source directories.

### How it works

`bin/render_embroidery_preview.py` (called by `Embroidery::PreviewRenderer`) uses:

- `pyembroidery` — parses the PES file, extracts thread color list and stitch coordinates
- `Pillow` — renders stitches as colored line segments on a gray canvas at 3× resolution, then downscales (LANCZOS) for anti-aliasing

Output per design: a single `955×778px` PNG with:

- **Design area** — stitches drawn in their actual thread colors on a `#525252` gray background
- **Right panel** — Brother thread color swatches with name and catalog number (e.g. `1. Lime Green (519)`)
- **Bottom bar** — filename, dimensions in mm, stitch count, jump count, color count

Rendering is the default behavior (`render_previews: true`). If rendering fails for any design, the packager falls back to copying the bundled source PNG and logs a warning.

### Opting out

```bash
# Skip rendering, copy bundled source PNGs instead
bin/rails embroidery_catalog:package SOURCE_ROOT=... OUT_DIR=... RENDER_PREVIEWS=false
```

## Migration Strategy

### Phase 1: Audit and package ✅

Goal:
Turn a chosen raw folder subset into a reviewed manifest before any migration work touches the live catalog.

Deliverables (all complete):

| Service | Rake task |
|---|---|
| `Embroidery::CatalogAuditor` | `embroidery_catalog:audit` |
| `Embroidery::PackageBuilder` | `embroidery_catalog:package` |
| `Embroidery::PreviewRenderer` | (called by package; standalone via `embroidery_catalog:render_previews`) |
| `Embroidery::CatalogImporter` | `embroidery_catalog:import` |
| `Embroidery::SourceCleanup` | `embroidery_catalog:cleanup` |
| `Embroidery::S3Uploader` | `embroidery_catalog:upload` |
| — | `active_storage:s3:migrate` |
| — | `active_storage:s3:verify` |

What the audit does:

- scans folders in `<category>/<size>/<design>` form
- identifies embroidery files and preview images
- normalizes slugs and human-readable titles
- proposes deterministic S3 keys
- exports JSON and CSV for review
- flags obvious issues: missing embroidery files, missing previews (when required), duplicate normalized S3 prefixes

### Phase 2: Curate and fix the sample batch

For the first batch only:

- remove designs with no real downloadable file
- decide whether multiple embroidery files belong to one product or separate products
- confirm naming conventions for category, design, and size
- confirm which preview image should be primary

### Phase 3: Upload the curated batch to S3

After the manifest is reviewed:

- build the reviewed package directory with deterministic keys (previews rendered from PES)
- import only from the reviewed package manifest
- let Active Storage write the attached bytes to the currently configured storage service
- verify downloads work through Rails and Active Storage against S3 once the service is switched

### Phase 4: Refactor backend ownership

After the small batch proves out:

- remove success-page download creation logic based on Stripe line items
- make webhook-created order/download records the canonical source
- keep the reviewed manifest as the only import contract instead of raw server directories

## Command Reference

```bash
# Audit a batch
bin/rails embroidery_catalog:audit \
  "SOURCE_ROOT=/Users/christopherbaptiste/Desktop/Embroidery Files/Embroidery Catalog/Bundles" \
  LIMIT=20 OUT_DIR=tmp/embroidery_audit_sample

# Package with rendered previews (default)
bin/rails embroidery_catalog:package \
  "SOURCE_ROOT=/Users/christopherbaptiste/Desktop/Embroidery Files/Embroidery Catalog/Bundles" \
  LIMIT=20 OUT_DIR=tmp/embroidery_package_v3 READY_ONLY=true

# Package without rendering (copy bundled PNGs)
bin/rails embroidery_catalog:package \
  "SOURCE_ROOT=..." OUT_DIR=... RENDER_PREVIEWS=false

# Re-render previews into an existing package
bin/rails embroidery_catalog:render_previews \
  MANIFEST_PATH=tmp/embroidery_package_v3/manifest.json

# Upload dry-run
bin/rails embroidery_catalog:upload \
  MANIFEST_PATH=tmp/embroidery_package_v3/manifest.json DRY_RUN=true

# Live upload to dev
bin/rails embroidery_catalog:upload \
  MANIFEST_PATH=tmp/embroidery_package_v3/manifest.json DRY_RUN=false \
  S3_BUCKET=shopzilla-dev-assets

# Live upload to prod
bin/rails embroidery_catalog:upload \
  MANIFEST_PATH=tmp/embroidery_package_v3/manifest.json DRY_RUN=false \
  S3_BUCKET=shopzilla-prod-assets

# Import into Rails DB + ActiveStorage
bin/rails embroidery_catalog:import \
  MANIFEST_PATH=tmp/embroidery_package_v3/manifest.json IMPORT_PRICE_CENTS=500

# Migrate existing ActiveStorage blobs to S3
bin/rails active_storage:s3:migrate DRY_RUN=1 LIMIT=500
bin/rails active_storage:s3:migrate LIMIT=2000
bin/rails active_storage:s3:verify

# Cleanup source dirs (after import confirmed good)
bin/rails embroidery_catalog:cleanup \
  MANIFEST_PATH=tmp/embroidery_package_v3/manifest.json
bin/rails embroidery_catalog:cleanup \
  MANIFEST_PATH=tmp/embroidery_package_v3/manifest.json DRY_RUN=false CONFIRM=DELETE
```

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

- resolved the bundle blocker: ran `bundle install` to completion (159 gems)
- confirmed source catalog structure: 55 top-level category directories
- ran first live `embroidery_catalog:audit` (LIMIT=20): 20 ready, 5 `duplicate_s3_prefix` issues
- ran `embroidery_catalog:package` (LIMIT=20): 20 packaged, 72 files → `tmp/embroidery_package_sample/`

### 2026-04-30 (second pass)

Completed:

- fixed `PackageBuilder` duplicate handling: first-occurrence-wins using `Set`
- built `Embroidery::S3Uploader` with AES256 SSE, dry-run, overwrite check, `upload_report.json`
- added `rake embroidery_catalog:upload`, `rake active_storage:s3:migrate`, `rake active_storage:s3:verify`
- enabled `local_mirror_s3` in `config/storage.yml`
- re-ran package → `tmp/embroidery_package_v2/`: 17 packaged, 3 skipped (duplicate prefixes excluded)
- dry-run upload: 68 files, 3.63 MB, 0 errors ✅

### 2026-05-04

Completed:

- import run: 17/17 products updated in dev DB, 0 errors ✅ (`tmp/embroidery_package_v2/import_report.json`)
- live upload blocked: `embroidery-files-667` bucket no longer exists

### 2026-05-09

Completed:

- confirmed active buckets: `shopzilla-dev-assets`, `shopzilla-prod-assets`
- dev upload succeeded: 68/68 files, 3.63 MB → `s3://shopzilla-dev-assets/embroidery/` ✅

### 2026-05-10 — Preview rendering

Problem: bundled source PNGs are mostly black-and-white sketches with no thread color information.
Goal: generate StitchMaster Pro-style renders (colored stitches on gray background, thread panel, metadata bar) from the PES files directly.

Completed:

- built `bin/render_embroidery_preview.py`:
  - reads PES with `pyembroidery`; renders stitch segments in actual thread colors (3× canvas, LANCZOS downscale)
  - composites: design area on gray bg | right panel with color swatches + thread name + catalog number | bottom bar with filename, mm size, stitch count
  - outputs `955×778px` PNG
  - system deps already present: `pyembroidery 1.5.1`, `Pillow 12.1.1`, Python 3.14.4
- built `app/services/embroidery/preview_renderer.rb`: Ruby service that shells to the Python script; raises on non-zero exit; returns file metadata hash
- updated `Embroidery::PackageBuilder`:
  - new option `render_previews: true` (default)
  - renders from PES file → `preview/01-preview.png` in the output package
  - falls back to copying bundled source PNG on any render error
- updated `lib/tasks/embroidery_catalog.rake`:
  - `package` task gains `RENDER_PREVIEWS=true/false` env var
  - new `render_previews` task: re-renders previews into an existing package from its manifest
- updated `test/services/embroidery/package_builder_test.rb`:
  - existing tests now explicit with `render_previews: false`
  - new test validates real render against a live PES file (skipped if source unavailable)
- live test: 5 designs packaged, all 5 previews rendered successfully

All 3 PackageBuilder tests pass ✅

Next steps:

1. Scale to full 55-category Bundles catalog: audit → review issues → package (with rendering) → upload to `shopzilla-dev-assets`
2. Production cutover: upload to `shopzilla-prod-assets`, deploy mirror service, migrate, verify, switch

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

### Decision: Render previews from PES, not bundled images

Reason:

- Bundled PNGs vary wildly in quality; most are monochrome sketches with no color information.
- Rendering directly from the PES file via `pyembroidery` produces consistent, color-accurate previews across all designs.
- The render also encodes thread metadata (color name, catalog number) and design dimensions, which are useful to customers before purchase.
