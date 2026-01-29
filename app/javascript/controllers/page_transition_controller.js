import { Controller } from "@hotwired/stimulus"
import gsap from "gsap"
import { ScrollTrigger } from "gsap/ScrollTrigger"

gsap.registerPlugin(ScrollTrigger)

export default class extends Controller {
  connect() {
    this.setupTransitions()
    this.animatePageIn()
  }

  setupTransitions() {
    this.boundBeforeVisit = this.beforeVisit.bind(this)
    this.boundAfterLoad = this.afterLoad.bind(this)

    document.addEventListener('turbo:before-visit', this.boundBeforeVisit)
    document.addEventListener('turbo:load', this.boundAfterLoad)
  }

  disconnect() {
    document.removeEventListener('turbo:before-visit', this.boundBeforeVisit)
    document.removeEventListener('turbo:load', this.boundAfterLoad)
  }

  animatePageIn() {
    gsap.fromTo('main',
      {
        opacity: 0,
        y: 30
      },
      {
        opacity: 1,
        y: 0,
        duration: 0.6,
        ease: "power3.out",
        clearProps: "all"
      }
    )

    gsap.fromTo('.navbar',
      {
        y: -100,
        opacity: 0
      },
      {
        y: 0,
        opacity: 1,
        duration: 0.5,
        ease: "power3.out",
        delay: 0.1
      }
    )
  }

  beforeVisit(event) {
    gsap.to('main', {
      opacity: 0,
      y: -30,
      scale: 0.98,
      duration: 0.3,
      ease: "power2.in"
    })
  }

  afterLoad(event) {
    gsap.fromTo('main',
      {
        opacity: 0,
        y: 40,
        scale: 0.98
      },
      {
        opacity: 1,
        y: 0,
        scale: 1,
        duration: 0.6,
        ease: "power3.out",
        clearProps: "all"
      }
    )

    ScrollTrigger.refresh()
  }
}
