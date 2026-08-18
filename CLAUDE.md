# Shopzilla

## Stack
Rails 8.0.5, Ruby 3.4.2, Hotwire (Turbo + Stimulus), esbuild, Tailwind CSS v4 + DaisyUI, ActiveAdmin, Three.js + GSAP for storefront animations

## Auth
Devise

## Storage
AWS S3 + ActiveStorage

## Database
PostgreSQL

## Deploy
AWS ECS (EC2 launch type, cluster `default`, service `shopzilla-web`, account 673588459621, us-east-2) via GitLab CI + Thruster

## Dev commands
```bash
bin/dev
bin/rails c
bin/rails test
bundle exec rubocop
```

## Conventions
- Uses Minitest for testing
