# Shopzilla

A full-featured e-commerce application for Gloria's embroidery studio — selling hand-crafted digital designs and physical embroidery products with Stripe-powered checkout.

[![Ruby](https://img.shields.io/badge/Ruby-3.4.2-CC342D?logo=ruby&logoColor=white)](https://ruby-lang.org)
[![Rails](https://img.shields.io/badge/Rails-8.0.2-CC0000?logo=rubyonrails&logoColor=white)](https://rubyonrails.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql&logoColor=white)](https://postgresql.org)
[![Stripe](https://img.shields.io/badge/Stripe-Payments-635BFF?logo=stripe&logoColor=white)](https://stripe.com)

## Features

- **Product catalog** — Search, category/format/stitch-count filtering, and pagination via Kaminari
- **Digital downloads and physical products** — Dual fulfillment paths for shippable and downloadable items
- **Stripe Checkout** — Webhook-driven order fulfillment with idempotent event processing
- **Secure download links** — Time-limited, token-authenticated URLs (30-day expiry per `DownloadAccess` record)
- **User dashboard** — Order history, active downloads, and wishlist management
- **Wishlist** — Add/remove items with real-time Turbo Stream updates (no full-page reload)
- **User profiles** — Avatar upload via Active Storage, rich-text bio via ActionText
- **Admin panel** — Full CRUD for products, categories, orders, and users via ActiveAdmin (`/admin`)
- **Responsive aurora-themed UI** — Tailwind CSS 4 + DaisyUI 5 with GSAP animations

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Ruby 3.4.2 |
| Framework | Rails 8.0.2 |
| Database | PostgreSQL 16 |
| Frontend | Hotwire (Turbo + Stimulus), esbuild |
| Styling | Tailwind CSS 4, DaisyUI 5, GSAP |
| Auth | Devise 4.9 |
| Payments | Stripe Checkout + Webhooks |
| Admin | ActiveAdmin 3.3 |
| Storage | Active Storage — local disk (dev), AWS S3 via instance profile (production) |
| Background Jobs | Solid Queue |
| Cache | Solid Cache |
| Deployment | AWS ECS on EC2 + ECR + ALB |
| Testing | Minitest, Capybara |

## Getting Started

### Prerequisites

- Ruby 3.4.2 (use `rbenv` — see `.ruby-version`)
- Node.js 20+ and npm
- PostgreSQL 14+

### Installation

```bash
git clone git@github.com:chrisbaptiste83/shopzilla.git
cd shopzilla

bundle install
npm install
```

### Environment Setup

The app uses Rails encrypted credentials for API keys and secrets:

```bash
EDITOR=nvim bin/rails credentials:edit
```

Add the following structure:

```yaml
stripe:
  secret_key: sk_live_...
  webhook_secret: whsec_...

```

Production on ECS does not use static AWS access keys in Rails credentials. Active Storage uses the EC2 instance profile automatically, and the bucket is configured in `config/storage.yml`.

For local development, set PostgreSQL credentials if needed:

```bash
export PGUSER=your_pg_user
export PGPASSWORD=your_pg_password
```

### Database Setup

```bash
bin/rails db:create db:migrate db:seed
```

### Building Assets

```bash
npm run build        # compile JavaScript with esbuild
npm run build:css    # generate Tailwind CSS
```

For development with live reloading:

```bash
bin/dev   # starts Rails, esbuild watcher, and CSS watcher via Foreman
```

Visit `http://localhost:3000`.

## Architecture

### Cart

Cart state lives in the session as `{ product_id => quantity }`. No database table is required. The cart is cleared from the session when checkout begins.

### Checkout Flow

```
User adds to cart
  → POST /checkout
      ├─ Physical items? → Render shipping address form
      │    └─ POST /checkout/process_shipping_address → Stripe session → redirect
      └─ Digital only?  → Stripe session → redirect

Stripe → POST /webhooks/stripe (checkout.session.completed)
  → Creates Order, OrderItems, Payment
  → Creates DownloadAccess (30-day expiry) for non-shippable items
  → User lands on /pages/success
```

### Download Tokens

`DownloadAccess` stores a `SecureRandom.urlsafe_base64(32)` token with a 30-day expiry. `GET /downloads/:token` validates the token and expiry, then redirects through Active Storage to the backing file in S3.

### Admin Access

The `admin` boolean on `User` gates product/category CRUD. Non-admins are redirected to root with an alert. ActiveAdmin provides a management UI at `/admin`.

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `RAILS_MASTER_KEY` | Yes | Decrypts `credentials.yml.enc` |
| `DATABASE_URL` | Production | Full PostgreSQL connection URL |
| `PGUSER` | Dev/Test | PostgreSQL user (default: `chris`) |
| `PGPASSWORD` | Dev/Test | PostgreSQL password |
| `ACTIVE_STORAGE_SERVICE` | Production | Active Storage backend (`amazon`) |
| `STRIPE_SECRET_KEY` | Production | Stripe live secret key |

## Testing

The suite uses Rails' built-in Minitest. Controller tests use `Devise::Test::IntegrationHelpers` for authentication.

```bash
bin/rails test                                   # all tests
bin/rails test:models                            # model unit tests
bin/rails test:controllers                       # controller integration tests
bin/rails test test/models/product_test.rb       # single file
```

### Stripe Webhook Testing (development)

```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

## Deployment

Deployed to AWS ECS (EC2 launch type) behind an ALB at `gloriasembroideryshop.com`.

- App images are built in GitHub Actions and pushed to ECR.
- ECS runs the Rails container on port `3000` with dynamic host ports.
- Production secrets are injected from AWS Secrets Manager.
- Active Storage uses the `amazon` service and stores files in `shopzilla-dev-assets`.

The current deployment reference lives in `docs/ecs_deployment.md`.

## License

Proprietary. All rights reserved.
