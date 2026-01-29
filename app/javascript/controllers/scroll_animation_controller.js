import { Controller } from "@hotwired/stimulus"
import gsap from "gsap"
import { ScrollTrigger } from "gsap/ScrollTrigger"

gsap.registerPlugin(ScrollTrigger)

export default class extends Controller {
  static values = {
    animation: { type: String, default: "fade-up" },
    delay: { type: Number, default: 0 },
    duration: { type: Number, default: 0.8 },
    stagger: { type: Number, default: 0 }
  }

  connect() {
    this.setupAnimation()
  }

  disconnect() {
    if (this.scrollTrigger) {
      this.scrollTrigger.kill()
    }
  }

  setupAnimation() {
    const animations = {
      "fade-up": {
        from: { opacity: 0, y: 60, scale: 0.98 },
        to: { opacity: 1, y: 0, scale: 1 }
      },
      "fade-down": {
        from: { opacity: 0, y: -60, scale: 0.98 },
        to: { opacity: 1, y: 0, scale: 1 }
      },
      "fade-left": {
        from: { opacity: 0, x: 80, rotateY: -5 },
        to: { opacity: 1, x: 0, rotateY: 0 }
      },
      "fade-right": {
        from: { opacity: 0, x: -80, rotateY: 5 },
        to: { opacity: 1, x: 0, rotateY: 0 }
      },
      "scale-up": {
        from: { opacity: 0, scale: 0.85, rotateX: 10 },
        to: { opacity: 1, scale: 1, rotateX: 0 }
      },
      "rotate-in": {
        from: { opacity: 0, rotation: -15, scale: 0.9, y: 30 },
        to: { opacity: 1, rotation: 0, scale: 1, y: 0 }
      },
      "blur-in": {
        from: { opacity: 0, filter: "blur(10px)", y: 40 },
        to: { opacity: 1, filter: "blur(0px)", y: 0 }
      },
      "slide-reveal": {
        from: { opacity: 0, clipPath: "inset(0 100% 0 0)" },
        to: { opacity: 1, clipPath: "inset(0 0% 0 0)" }
      },
      "bounce-in": {
        from: { opacity: 0, scale: 0.3, y: 100 },
        to: { opacity: 1, scale: 1, y: 0 }
      }
    }

    const animation = animations[this.animationValue] || animations["fade-up"]

    gsap.set(this.element, {
      ...animation.from,
      willChange: "transform, opacity"
    })

    const ease = this.animationValue === "bounce-in"
      ? "elastic.out(1, 0.5)"
      : "power3.out"

    this.scrollTrigger = ScrollTrigger.create({
      trigger: this.element,
      start: "top 92%",
      end: "bottom 10%",
      onEnter: () => {
        gsap.to(this.element, {
          ...animation.to,
          duration: this.durationValue,
          delay: this.delayValue,
          ease: ease,
          clearProps: "willChange"
        })
      },
      onLeaveBack: () => {
        gsap.to(this.element, {
          ...animation.from,
          duration: this.durationValue * 0.5,
          ease: "power2.in"
        })
      }
    })
  }
}
