# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

pin_all_from "app/javascript/controllers", under: "controllers"

# Three.js
pin "three", to: "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js"

# GSAP (ESM builds)
pin "gsap", to: "https://cdn.jsdelivr.net/npm/gsap@3.12.5/dist/gsap.min.js"
pin "gsap/ScrollTrigger", to: "https://cdn.jsdelivr.net/npm/gsap@3.12.5/dist/ScrollTrigger.min.js"

# Action Text
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
