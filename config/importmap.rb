# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

pin_all_from "app/javascript/controllers", under: "controllers"

# Three.js (ESM)
pin "three", to: "https://esm.sh/three@0.160.0"

# GSAP (ESM via esm.sh)
pin "gsap", to: "https://esm.sh/gsap@3.12.5"
pin "gsap/ScrollTrigger", to: "https://esm.sh/gsap@3.12.5/ScrollTrigger"

# Action Text
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
