import { Controller } from "@hotwired/stimulus"
import gsap from "gsap"
import { ScrollTrigger } from "gsap/ScrollTrigger"

gsap.registerPlugin(ScrollTrigger)

export default class extends Controller {
  connect() {
    this.animatePageIn()
    this.setupTransitions()
  }

  setupTransitions() {
    this.boundBeforeCache = this.beforeCache.bind(this)
    this.boundAfterLoad = this.afterLoad.bind(this)

    document.addEventListener('turbo:before-cache', this.boundBeforeCache)
    document.addEventListener('turbo:load', this.boundAfterLoad)
  }

  disconnect() {
    document.removeEventListener('turbo:before-cache', this.boundBeforeCache)
    document.removeEventListener('turbo:load', this.boundAfterLoad)
  }

  animatePageIn() {
    gsap.fromTo('main',
      { opacity: 0, y: 20 },
      {
        opacity: 1,
        y: 0,
        duration: 0.4,
        ease: "power2.out",
        clearProps: "all"
      }
    )
  }

  beforeCache() {
    // Reset state before Turbo caches the page so cached version looks clean
    gsap.killTweensOf('main')
    gsap.set('main', { opacity: 1, y: 0, clearProps: "all" })
  }

  afterLoad() {
    gsap.killTweensOf('main')
    gsap.fromTo('main',
      { opacity: 0, y: 20 },
      {
        opacity: 1,
        y: 0,
        duration: 0.4,
        ease: "power2.out",
        clearProps: "all"
      }
    )

    ScrollTrigger.refresh()
  }
}
