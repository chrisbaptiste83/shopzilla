import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"

export default class extends Controller {
  connect() {
    this.initScene()
    this.createParticleSystem()
    this.animate()
    this.handleResize()
  }

  disconnect() {
    window.removeEventListener('resize', this.onResize)
    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
    }
    if (this.renderer) {
      this.renderer.dispose()
    }
  }

  initScene() {
    this.scene = new THREE.Scene()

    this.camera = new THREE.PerspectiveCamera(
      75,
      window.innerWidth / window.innerHeight,
      0.1,
      1000
    )
    this.camera.position.z = 5

    this.renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true
    })
    this.renderer.setSize(window.innerWidth, window.innerHeight)
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.renderer.domElement.style.position = 'fixed'
    this.renderer.domElement.style.top = '0'
    this.renderer.domElement.style.left = '0'
    this.renderer.domElement.style.zIndex = '-1'
    this.renderer.domElement.style.pointerEvents = 'none'

    this.element.appendChild(this.renderer.domElement)
  }

  createParticleSystem() {
    const particlesGeometry = new THREE.BufferGeometry()
    const particlesCount = 200
    const positions = new Float32Array(particlesCount * 3)
    const colors = new Float32Array(particlesCount * 3)

    for (let i = 0; i < particlesCount; i++) {
      // Position
      positions[i * 3] = (Math.random() - 0.5) * 20
      positions[i * 3 + 1] = (Math.random() - 0.5) * 20
      positions[i * 3 + 2] = (Math.random() - 0.5) * 20

      // Colors - using embroidery-themed colors
      const colorPalette = [
        [0.23, 0.51, 0.96], // blue
        [0.55, 0.36, 0.96], // purple
        [0.93, 0.29, 0.60], // pink
        [0.02, 0.71, 0.83], // cyan
      ]
      const color = colorPalette[Math.floor(Math.random() * colorPalette.length)]
      colors[i * 3] = color[0]
      colors[i * 3 + 1] = color[1]
      colors[i * 3 + 2] = color[2]
    }

    particlesGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))
    particlesGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3))

    const particlesMaterial = new THREE.PointsMaterial({
      size: 0.1,
      transparent: true,
      opacity: 0.6,
      vertexColors: true,
      blending: THREE.AdditiveBlending,
    })

    this.particles = new THREE.Points(particlesGeometry, particlesMaterial)
    this.scene.add(this.particles)

    // Create connecting lines for fabric texture effect
    const linesMaterial = new THREE.LineBasicMaterial({
      color: 0x3b82f6,
      transparent: true,
      opacity: 0.1,
    })

    const linesGeometry = new THREE.BufferGeometry()
    const linePositions = []

    for (let i = 0; i < particlesCount; i += 2) {
      linePositions.push(
        positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2],
        positions[(i + 1) * 3], positions[(i + 1) * 3 + 1], positions[(i + 1) * 3 + 2]
      )
    }

    linesGeometry.setAttribute('position', new THREE.Float32BufferAttribute(linePositions, 3))
    this.lines = new THREE.LineSegments(linesGeometry, linesMaterial)
    this.scene.add(this.lines)
  }

  animate() {
    this.animationId = requestAnimationFrame(() => this.animate())

    // Slow rotation of entire particle system
    if (this.particles) {
      this.particles.rotation.y += 0.0005
      this.particles.rotation.x += 0.0002
    }

    if (this.lines) {
      this.lines.rotation.y += 0.0005
      this.lines.rotation.x += 0.0002
    }

    this.renderer.render(this.scene, this.camera)
  }

  handleResize() {
    this.onResize = () => {
      this.camera.aspect = window.innerWidth / window.innerHeight
      this.camera.updateProjectionMatrix()
      this.renderer.setSize(window.innerWidth, window.innerHeight)
    }

    window.addEventListener('resize', this.onResize)
  }
}
