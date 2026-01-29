import { Controller } from "@hotwired/stimulus"
import gsap from "gsap"

export default class extends Controller {
  connect() {
    this.createLoader()
    this.setupTurboListeners()
  }

  disconnect() {
    if (this.loader) {
      this.loader.remove()
    }
    document.removeEventListener('turbo:before-fetch-request', this.showLoader)
    document.removeEventListener('turbo:before-fetch-response', this.hideLoader)
  }

  createLoader() {
    // Create loader overlay
    this.loader = document.createElement('div')
    this.loader.className = 'page-loader'
    this.loader.innerHTML = `
      <div class="loader-content">
        <div class="loader-spinner">
          <div class="spinner-ring"></div>
          <div class="spinner-ring"></div>
          <div class="spinner-ring"></div>
        </div>
        <div class="loader-text">Loading...</div>
      </div>
    `

    // Add styles
    const style = document.createElement('style')
    style.textContent = `
      .page-loader {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(10px);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 9999;
        opacity: 0;
        pointer-events: none;
        transition: opacity 0.3s ease;
      }

      .page-loader.active {
        opacity: 1;
        pointer-events: all;
      }

      .loader-content {
        text-align: center;
      }

      .loader-spinner {
        position: relative;
        width: 80px;
        height: 80px;
        margin: 0 auto 20px;
      }

      .spinner-ring {
        position: absolute;
        width: 100%;
        height: 100%;
        border: 4px solid transparent;
        border-top-color: #3b82f6;
        border-radius: 50%;
        animation: spin 1.5s cubic-bezier(0.68, -0.55, 0.265, 1.55) infinite;
      }

      .spinner-ring:nth-child(2) {
        border-top-color: #8b5cf6;
        animation-delay: 0.2s;
        width: 70%;
        height: 70%;
        top: 15%;
        left: 15%;
      }

      .spinner-ring:nth-child(3) {
        border-top-color: #ec4899;
        animation-delay: 0.4s;
        width: 40%;
        height: 40%;
        top: 30%;
        left: 30%;
      }

      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }

      .loader-text {
        font-size: 1.2rem;
        font-weight: 600;
        color: #1f2937;
        animation: pulse 1.5s ease-in-out infinite;
      }

      @keyframes pulse {
        0%, 100% { opacity: 0.6; }
        50% { opacity: 1; }
      }
    `

    document.head.appendChild(style)
    document.body.appendChild(this.loader)
  }

  setupTurboListeners() {
    this.showLoader = this.show.bind(this)
    this.hideLoader = this.hide.bind(this)

    document.addEventListener('turbo:before-fetch-request', this.showLoader)
    document.addEventListener('turbo:before-fetch-response', this.hideLoader)
  }

  show() {
    if (this.loader) {
      this.loader.classList.add('active')

      gsap.fromTo('.loader-content',
        { scale: 0.8, opacity: 0 },
        { scale: 1, opacity: 1, duration: 0.3, ease: "back.out" }
      )
    }
  }

  hide() {
    if (this.loader) {
      gsap.to('.loader-content',
        {
          scale: 0.8,
          opacity: 0,
          duration: 0.2,
          ease: "power2.in",
          onComplete: () => {
            this.loader.classList.remove('active')
          }
        }
      )
    }
  }
}
