import { Controller } from "@hotwired/stimulus"
import gsap from "gsap"

export default class extends Controller {
  static values = {
    effect: { type: String, default: "lift" },
    scale: { type: Number, default: 1.03 },
    duration: { type: Number, default: 0.4 }
  }

  connect() {
    this.setupHoverEffect()
    this.isHovered = false
  }

  setupHoverEffect() {
    this.originalState = {
      scale: 1,
      y: 0,
      x: 0,
      rotation: 0,
      rotationX: 0,
      rotationY: 0,
      boxShadow: window.getComputedStyle(this.element).boxShadow || "none"
    }

    gsap.set(this.element, {
      transformPerspective: 1000,
      transformStyle: "preserve-3d"
    })
  }

  mouseenter(event) {
    this.isHovered = true
    const effects = {
      lift: () => {
        gsap.to(this.element, {
          y: -12,
          scale: this.scaleValue,
          boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.2), 0 10px 25px -5px rgba(59, 130, 246, 0.1)",
          duration: this.durationValue,
          ease: "power2.out"
        })
      },
      scale: () => {
        gsap.to(this.element, {
          scale: this.scaleValue,
          boxShadow: "0 20px 40px rgba(0, 0, 0, 0.12)",
          duration: this.durationValue,
          ease: "elastic.out(1, 0.5)"
        })
      },
      rotate: () => {
        gsap.to(this.element, {
          rotation: 2,
          scale: this.scaleValue,
          y: -8,
          boxShadow: "0 20px 40px rgba(0, 0, 0, 0.15)",
          duration: this.durationValue,
          ease: "power2.out"
        })
      },
      glow: () => {
        gsap.to(this.element, {
          boxShadow: "0 0 40px rgba(59, 130, 246, 0.4), 0 0 80px rgba(139, 92, 246, 0.2)",
          scale: this.scaleValue,
          duration: this.durationValue,
          ease: "power2.out"
        })
      },
      tilt: () => {
        this.updateTilt(event)
        gsap.to(this.element, {
          scale: this.scaleValue,
          boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.2)",
          duration: this.durationValue,
          ease: "power2.out"
        })
      },
      magnetic: () => {
        const rect = this.element.getBoundingClientRect()
        const x = event.clientX - rect.left - rect.width / 2
        const y = event.clientY - rect.top - rect.height / 2
        gsap.to(this.element, {
          x: x * 0.2,
          y: y * 0.2,
          scale: this.scaleValue,
          duration: this.durationValue,
          ease: "power2.out"
        })
      },
      float: () => {
        gsap.to(this.element, {
          y: -15,
          scale: this.scaleValue,
          boxShadow: "0 30px 60px -15px rgba(0, 0, 0, 0.25)",
          duration: this.durationValue * 1.5,
          ease: "power2.out"
        })
        gsap.to(this.element, {
          y: -12,
          yoyo: true,
          repeat: -1,
          duration: 1,
          ease: "sine.inOut"
        })
      }
    }

    const effect = effects[this.effectValue] || effects.lift
    effect()
  }

  mouseleave() {
    this.isHovered = false

    gsap.killTweensOf(this.element)

    gsap.to(this.element, {
      ...this.originalState,
      duration: this.durationValue,
      ease: "power3.out",
      clearProps: "boxShadow"
    })
  }

  mousemove(event) {
    if (!this.isHovered) return

    if (this.effectValue === 'tilt') {
      this.updateTilt(event)
    } else if (this.effectValue === 'magnetic') {
      const rect = this.element.getBoundingClientRect()
      const x = event.clientX - rect.left - rect.width / 2
      const y = event.clientY - rect.top - rect.height / 2
      gsap.to(this.element, {
        x: x * 0.15,
        y: y * 0.15,
        duration: 0.3,
        ease: "power2.out"
      })
    }
  }

  updateTilt(event) {
    const rect = this.element.getBoundingClientRect()
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    const centerX = rect.width / 2
    const centerY = rect.height / 2
    const rotateX = ((y - centerY) / centerY) * -8
    const rotateY = ((x - centerX) / centerX) * 8

    gsap.to(this.element, {
      rotationX: rotateX,
      rotationY: rotateY,
      duration: 0.3,
      ease: "power2.out"
    })
  }
}
