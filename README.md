# Shopzilla

A full-featured e-commerce application for Gloria's embroidery studio — selling hand-crafted digital designs and physical embroidery products with Stripe-powered checkout.

## Features

- Product catalog with search, category/format/stitch-count filtering, and pagination
- Digital downloads and physical (shippable) product support
- Stripe Checkout with webhook-driven order fulfillment
- Time-limited, token-authenticated secure download links
- User dashboard with order history, active downloads, and wishlist
- Wishlist management with Turbo Stream updates
- User profiles with avatar and rich-text bio
- Admin panel via ActiveAdmin (products, categories, orders, users)
- Responsive aurora-themed UI with Tailwind CSS and DaisyUI

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Ruby 3.4.2 |
| Framework | Rails 8.0.2 |
| Frontend | Hotwire (Turbo + Stimulus), esbuild |
| Styling | Tailwind CSS 4, DaisyUI 5 |
| Animations | GSAP |
| Auth | Devise |
| Payments | Stripe Checkout + Webhooks |
| Admin | ActiveAdmin |
| Storage | Active Storage (local / AWS S3 in production) |
| Queue / Cache | Solid Queue, Solid Cache, Solid Cable |
| Database | SQLite (development / test) |
| Deployment | Kamal (Docker) |
| Testing | Minitest, Capybara |

## Getting Started

### Prerequisites

- Ruby 3.4.2 (use `rbenv` or `asdf`)
- Node.js 20+
- SQLite3

### Installation

```bash
git clone <repo-url>
cd shopzilla

bundle install
npm install
```

### Credentials

The app expects Stripe API keys in Rails encrypted credentials:

```bash
EDITOR=nano bin/rails credentials:edit
```

```yaml
stripe:
  secret_key: sk_test_...
  webhook_secret: whsec_...

# Production file storage (optional in development)
aws:
  access_key_id: ...
  secret_access_key: ...
  region: us-east-1
  bucket: shopzilla-production
```

### Database Setup

```bash
bin/rails db:setup
```

### Building Assets

```bash
npm run build        # compiles JavaScript with esbuild
npm run build:css    # generates Tailwind CSS
```

For development with live reloading:

```bash
bin/dev              # starts Rails, esbuild watch, and CSS watch concurrently
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
      └─ Digital only? → Stripe session → redirect

Stripe → POST /webhooks/stripe (checkout.session.completed)
  → Creates Order, OrderItems, Payment
  → Creates DownloadAccess (30-day expiry) for non-shippable items
  → User lands on /pages/success
```

### Download Tokens

`DownloadAccess` stores a `SecureRandom.urlsafe_base64(32)` token with a 30-day expiry. `GET /downloads/:token` validates the token and expiry before streaming the file.

### Admin Access

The `admin` boolean on `User` gates product/category CRUD. Non-admins are redirected to root with an alert. ActiveAdmin provides a management UI at `/admin`.

## Testing

The suite uses Rails' built-in Minitest. Controller tests use `Devise::Test::IntegrationHelpers` for authentication.

```bash
bin/rails test                                  # all tests
bin/rails test:models                           # model unit tests
bin/rails test:controllers                      # controller integration tests
bin/rails test test/models/product_test.rb      # single file
```

### Stripe Webhook Testing (development)

```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

## Deployment

```bash
kamal setup      # first-time server provisioning
kamal deploy     # deploy latest build
```

Deployment config lives in `config/deploy.yml`.

## License

Proprietary. All rights reserved.
