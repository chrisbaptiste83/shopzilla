import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"
import gsap from "gsap"

export default class extends Controller {
  static values = {
    imageUrl: String
  }

  connect() {
    this.setupViewer()
  }

  disconnect() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
    }
    if (this.renderer) {
      this.renderer.dispose()
    }
  }

  setupViewer() {
    const container = document.createElement('div')
    container.className = 'product-viewer-3d'
    container.style.width = '100%'
    container.style.height = '400px'
    container.style.position = 'relative'
    container.style.borderRadius = '1rem'
    container.style.overflow = 'hidden'

    this.element.appendChild(container)
    this.container = container

    this.initScene()
    this.createProduct()
    this.setupInteraction()
    this.animate()
  }

  initScene() {
    this.scene = new THREE.Scene()
    this.scene.background = new THREE.Color(0xf0f0f0)

    const width = this.container.clientWidth
    const height = this.container.clientHeight

    this.camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000)
    this.camera.position.z = 5

    this.renderer = new THREE.WebGLRenderer({ antialias: true })
    this.renderer.setSize(width, height)
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.container.appendChild(this.renderer.domElement)

    // Lighting
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6)
    this.scene.add(ambientLight)

    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8)
    directionalLight.position.set(5, 5, 5)
    this.scene.add(directionalLight)

    const rimLight = new THREE.DirectionalLight(0x3b82f6, 0.5)
    rimLight.position.set(-5, 0, -5)
    this.scene.add(rimLight)
  }

  createProduct() {
    // Create a fabric-like plane with the product image (simulated)
    const geometry = new THREE.PlaneGeometry(3, 3, 32, 32)

    // Add wave deformation to simulate fabric
    const positions = geometry.attributes.position
    for (let i = 0; i < positions.count; i++) {
      const x = positions.getX(i)
      const y = positions.getY(i)
      const wave = Math.sin(x * 2) * Math.cos(y * 2) * 0.1
      positions.setZ(i, wave)
    }
    positions.needsUpdate = true

    const material = new THREE.MeshPhongMaterial({
      color: 0x3b82f6,
      shininess: 100,
      side: THREE.DoubleSide,
    })

    this.productMesh = new THREE.Mesh(geometry, material)
    this.scene.add(this.productMesh)

    // Add wireframe overlay for embroidery effect
    const wireframeGeometry = new THREE.EdgesGeometry(geometry)
    const wireframeMaterial = new THREE.LineBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0.3
    })
    const wireframe = new THREE.LineSegments(wireframeGeometry, wireframeMaterial)
    this.productMesh.add(wireframe)

    // Add decorative particles around the product
    this.createParticles()
  }

  createParticles() {
    const particlesGeometry = new THREE.BufferGeometry()
    const particlesCount = 50
    const positions = new Float32Array(particlesCount * 3)

    for (let i = 0; i < particlesCount; i++) {
      const angle = (i / particlesCount) * Math.PI * 2
      const radius = 3 + Math.random() * 1
      positions[i * 3] = Math.cos(angle) * radius
      positions[i * 3 + 1] = (Math.random() - 0.5) * 4
      positions[i * 3 + 2] = Math.sin(angle) * radius
    }

    particlesGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))

    const particlesMaterial = new THREE.PointsMaterial({
      color: 0x8b5cf6,
      size: 0.1,
      transparent: true,
      opacity: 0.6,
    })

    this.particles = new THREE.Points(particlesGeometry, particlesMaterial)
    this.scene.add(this.particles)
  }

  setupInteraction() {
    this.isDragging = false
    this.previousMousePosition = { x: 0, y: 0 }
    this.rotation = { x: 0, y: 0 }

    this.container.addEventListener('mousedown', (e) => {
      this.isDragging = true
      this.previousMousePosition = { x: e.clientX, y: e.clientY }
    })

    this.container.addEventListener('mousemove', (e) => {
      if (!this.isDragging) return

      const deltaX = e.clientX - this.previousMousePosition.x
      const deltaY = e.clientY - this.previousMousePosition.y

      this.rotation.y += deltaX * 0.01
      this.rotation.x += deltaY * 0.01

      this.previousMousePosition = { x: e.clientX, y: e.clientY }
    })

    this.container.addEventListener('mouseup', () => {
      this.isDragging = false
    })

    this.container.addEventListener('mouseleave', () => {
      this.isDragging = false
    })

    // Touch support
    this.container.addEventListener('touchstart', (e) => {
      this.isDragging = true
      this.previousMousePosition = {
        x: e.touches[0].clientX,
        y: e.touches[0].clientY
      }
    })

    this.container.addEventListener('touchmove', (e) => {
      if (!this.isDragging) return

      const deltaX = e.touches[0].clientX - this.previousMousePosition.x
      const deltaY = e.touches[0].clientY - this.previousMousePosition.y

      this.rotation.y += deltaX * 0.01
      this.rotation.x += deltaY * 0.01

      this.previousMousePosition = {
        x: e.touches[0].clientX,
        y: e.touches[0].clientY
      }
    })

    this.container.addEventListener('touchend', () => {
      this.isDragging = false
    })
  }

  animate() {
    this.animationId = requestAnimationFrame(() => this.animate())

    if (this.productMesh) {
      // Apply rotation from user interaction
      gsap.to(this.productMesh.rotation, {
        x: this.rotation.x,
        y: this.rotation.y,
        duration: 0.3,
        ease: "power2.out"
      })

      // Subtle auto-rotation when not dragging
      if (!this.isDragging) {
        this.rotation.y += 0.003
      }

      // Animate fabric wave
      const time = Date.now() * 0.001
      const positions = this.productMesh.geometry.attributes.position
      for (let i = 0; i < positions.count; i++) {
        const x = positions.getX(i)
        const y = positions.getY(i)
        const wave = Math.sin(x * 2 + time) * Math.cos(y * 2 + time) * 0.1
        positions.setZ(i, wave)
      }
      positions.needsUpdate = true
    }

    if (this.particles) {
      this.particles.rotation.y += 0.001
    }

    this.renderer.render(this.scene, this.camera)
  }
}
