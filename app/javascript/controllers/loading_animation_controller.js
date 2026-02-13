import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.createLoader()
    this.setupTurboListeners()
    this.isNavigating = false
  }

  disconnect() {
    if (this.loader) {
      this.loader.remove()
    }
    if (this.loaderStyle) {
      this.loaderStyle.remove()
    }
    document.removeEventListener('turbo:before-visit', this.boundShow)
    document.removeEventListener('turbo:load', this.boundHide)
    document.removeEventListener('turbo:render', this.boundHide)
    document.removeEventListener('turbo:fetch-request-error', this.boundHide)
    window.removeEventListener('pageshow', this.boundHide)
  }

  createLoader() {
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

    this.loaderStyle = document.createElement('style')
    this.loaderStyle.textContent = `
      .page-loader {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(247, 243, 239, 0.85);
        backdrop-filter: blur(4px);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 9999;
        opacity: 0;
        pointer-events: none;
        transition: opacity 0.2s ease;
      }

      .page-loader.active {
        opacity: 1;
        pointer-events: none;
      }

      .loader-content {
        text-align: center;
      }

      .loader-spinner {
        position: relative;
        width: 60px;
        height: 60px;
        margin: 0 auto 16px;
      }

      .spinner-ring {
        position: absolute;
        width: 100%;
        height: 100%;
        border: 3px solid transparent;
        border-top-color: #0f766e;
        border-radius: 50%;
        animation: loader-spin 1.2s cubic-bezier(0.5, 0, 0.5, 1) infinite;
      }

      .spinner-ring:nth-child(2) {
        border-top-color: #b45309;
        animation-delay: 0.15s;
        width: 70%;
        height: 70%;
        top: 15%;
        left: 15%;
      }

      .spinner-ring:nth-child(3) {
        border-top-color: #ea580c;
        animation-delay: 0.3s;
        width: 40%;
        height: 40%;
        top: 30%;
        left: 30%;
      }

      @keyframes loader-spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }

      .loader-text {
        font-size: 1rem;
        font-weight: 600;
        color: #1f2937;
        animation: loader-pulse 1.5s ease-in-out infinite;
      }

      @keyframes loader-pulse {
        0%, 100% { opacity: 0.5; }
        50% { opacity: 1; }
      }
    `

    document.head.appendChild(this.loaderStyle)
    document.body.appendChild(this.loader)
  }

  setupTurboListeners() {
    this.boundShow = this.show.bind(this)
    this.boundHide = this.hide.bind(this)

    // Only show loader on actual page navigation, NOT on every fetch request
    document.addEventListener('turbo:before-visit', this.boundShow)

    // Hide on page load completion
    document.addEventListener('turbo:load', this.boundHide)
    document.addEventListener('turbo:render', this.boundHide)
    document.addEventListener('turbo:fetch-request-error', this.boundHide)
    window.addEventListener('pageshow', this.boundHide)
  }

  show() {
    if (this.isNavigating) return
    this.isNavigating = true

    // Small delay before showing loader to avoid flash on fast navigations
    this.showTimer = setTimeout(() => {
      if (this.loader && this.isNavigating) {
        this.loader.classList.add('active')
      }
    }, 200)
  }

  hide() {
    this.isNavigating = false
    if (this.showTimer) {
      clearTimeout(this.showTimer)
      this.showTimer = null
    }
    if (this.loader) {
      this.loader.classList.remove('active')
    }
  }
}
