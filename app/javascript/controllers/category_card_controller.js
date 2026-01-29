import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"
import gsap from "gsap"

export default class extends Controller {
  static values = {
    color: { type: String, default: "#3b82f6" }
  }

  connect() {
    this.setupCard()
  }

  disconnect() {
    if (this.renderer) {
      this.renderer.dispose()
    }
  }

  setupCard() {
    // Get or create canvas container
    let canvas = this.element.querySelector('.three-canvas')
    if (!canvas) {
      canvas = document.createElement('div')
      canvas.className = 'three-canvas'
      canvas.style.position = 'absolute'
      canvas.style.top = '0'
      canvas.style.left = '0'
      canvas.style.width = '100%'
      canvas.style.height = '100%'
      canvas.style.pointerEvents = 'none'
      canvas.style.opacity = '0.3'
      this.element.style.position = 'relative'
      this.element.insertBefore(canvas, this.element.firstChild)
    }

    this.canvas = canvas
    this.initScene()
    this.createGeometry()
    this.animate()
  }

  initScene() {
    this.scene = new THREE.Scene()

    const width = this.element.clientWidth
    const height = this.element.clientHeight

    this.camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 100)
    this.camera.position.z = 3

    this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true })
    this.renderer.setSize(width, height)
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))

    this.canvas.appendChild(this.renderer.domElement)

    const light = new THREE.PointLight(0xffffff, 1)
    light.position.set(2, 2, 2)
    this.scene.add(light)

    const ambientLight = new THREE.AmbientLight(0xffffff, 0.5)
    this.scene.add(ambientLight)
  }

  createGeometry() {
    const geometry = new THREE.IcosahedronGeometry(0.8, 0)
    const material = new THREE.MeshPhongMaterial({
      color: this.colorValue,
      shininess: 100,
      transparent: true,
      opacity: 0.8,
      wireframe: false,
    })

    this.mesh = new THREE.Mesh(geometry, material)
    this.scene.add(this.mesh)
  }

  animate() {
    if (!this.mesh) return

    this.animationId = requestAnimationFrame(() => this.animate())

    this.mesh.rotation.x += 0.005
    this.mesh.rotation.y += 0.005

    this.renderer.render(this.scene, this.camera)
  }

  mouseenter() {
    if (!this.mesh) return

    gsap.to(this.mesh.rotation, {
      x: this.mesh.rotation.x + Math.PI,
      y: this.mesh.rotation.y + Math.PI,
      duration: 1,
      ease: "power2.out"
    })

    gsap.to(this.mesh.scale, {
      x: 1.2,
      y: 1.2,
      z: 1.2,
      duration: 0.5,
      ease: "power2.out"
    })

    gsap.to(this.canvas, {
      opacity: 0.6,
      duration: 0.3
    })
  }

  mouseleave() {
    if (!this.mesh) return

    gsap.to(this.mesh.scale, {
      x: 1,
      y: 1,
      z: 1,
      duration: 0.5,
      ease: "power2.out"
    })

    gsap.to(this.canvas, {
      opacity: 0.3,
      duration: 0.3
    })
  }
}
