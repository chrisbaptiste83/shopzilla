import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"
import gsap from "gsap"

export default class extends Controller {
  connect() {
    this.mouse = { x: 0, y: 0 }
    this.targetMouse = { x: 0, y: 0 }
    this.initScene()
    this.createEmbroideryElements()
    this.createFloatingThreads()
    this.animate()
    this.handleResize()
    this.handleMouseMove()
  }

  disconnect() {
    window.removeEventListener('resize', this.onResize)
    window.removeEventListener('mousemove', this.onMouseMove)
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
      60,
      this.element.clientWidth / this.element.clientHeight,
      0.1,
      1000
    )
    this.camera.position.z = 8

    this.renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true,
      powerPreference: "high-performance"
    })
    this.renderer.setSize(this.element.clientWidth, this.element.clientHeight)
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.renderer.domElement.style.position = 'absolute'
    this.renderer.domElement.style.top = '0'
    this.renderer.domElement.style.left = '0'
    this.renderer.domElement.style.pointerEvents = 'none'
    this.element.appendChild(this.renderer.domElement)

    const ambientLight = new THREE.AmbientLight(0xffffff, 0.4)
    this.scene.add(ambientLight)

    const pointLight1 = new THREE.PointLight(0x3b82f6, 2, 20)
    pointLight1.position.set(5, 5, 5)
    this.scene.add(pointLight1)

    const pointLight2 = new THREE.PointLight(0xec4899, 2, 20)
    pointLight2.position.set(-5, -5, 5)
    this.scene.add(pointLight2)

    const pointLight3 = new THREE.PointLight(0x8b5cf6, 1.5, 15)
    pointLight3.position.set(0, 5, -5)
    this.scene.add(pointLight3)
  }

  createEmbroideryElements() {
    this.meshes = []
    this.mainGroup = new THREE.Group()

    const geometries = [
      new THREE.TorusGeometry(1, 0.3, 32, 100),
      new THREE.OctahedronGeometry(1, 2),
      new THREE.IcosahedronGeometry(0.9, 1),
      new THREE.TorusKnotGeometry(0.7, 0.2, 128, 32),
      new THREE.DodecahedronGeometry(0.8, 0),
    ]

    const colors = [0x3b82f6, 0x8b5cf6, 0xec4899, 0x06b6d4, 0xf59e0b]

    geometries.forEach((geometry, index) => {
      const material = new THREE.MeshPhysicalMaterial({
        color: colors[index],
        metalness: 0.3,
        roughness: 0.2,
        transparent: true,
        opacity: 0.85,
        clearcoat: 1,
        clearcoatRoughness: 0.1,
      })

      const mesh = new THREE.Mesh(geometry, material)

      const angle = (index / geometries.length) * Math.PI * 2
      const radius = 4
      mesh.position.x = Math.cos(angle) * radius
      mesh.position.y = Math.sin(angle) * (radius * 0.6)
      mesh.position.z = Math.sin(angle * 2) * 2 - 3

      mesh.userData = {
        originalPosition: mesh.position.clone(),
        rotationSpeed: {
          x: (Math.random() - 0.5) * 0.008,
          y: (Math.random() - 0.5) * 0.008,
          z: (Math.random() - 0.5) * 0.008,
        },
        floatSpeed: Math.random() * 0.4 + 0.3,
        floatOffset: Math.random() * Math.PI * 2,
        floatAmplitude: Math.random() * 0.3 + 0.2,
      }

      this.meshes.push(mesh)
      this.mainGroup.add(mesh)
    })

    this.scene.add(this.mainGroup)

    // Animate scale using GSAP with Three.js Vector3
    this.meshes.forEach((mesh, index) => {
      mesh.scale.set(0, 0, 0)
      gsap.to(mesh.scale, {
        x: 1,
        y: 1,
        z: 1,
        duration: 2,
        delay: index * 0.15,
        ease: "elastic.out(1, 0.5)"
      })
    })
  }

  createFloatingThreads() {
    const threadGeometry = new THREE.BufferGeometry()
    const threadCount = 200
    const positions = new Float32Array(threadCount * 3)
    const colors = new Float32Array(threadCount * 3)
    const sizes = new Float32Array(threadCount)

    const colorPalette = [
      new THREE.Color(0x3b82f6),
      new THREE.Color(0x8b5cf6),
      new THREE.Color(0xec4899),
      new THREE.Color(0x06b6d4),
      new THREE.Color(0xffffff),
    ]

    for (let i = 0; i < threadCount; i++) {
      positions[i * 3] = (Math.random() - 0.5) * 20
      positions[i * 3 + 1] = (Math.random() - 0.5) * 15
      positions[i * 3 + 2] = (Math.random() - 0.5) * 10 - 5

      const color = colorPalette[Math.floor(Math.random() * colorPalette.length)]
      colors[i * 3] = color.r
      colors[i * 3 + 1] = color.g
      colors[i * 3 + 2] = color.b

      sizes[i] = Math.random() * 3 + 1
    }

    threadGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))
    threadGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3))
    threadGeometry.setAttribute('size', new THREE.BufferAttribute(sizes, 1))

    const threadMaterial = new THREE.PointsMaterial({
      size: 0.08,
      vertexColors: true,
      transparent: true,
      opacity: 0.8,
      blending: THREE.AdditiveBlending,
      sizeAttenuation: true,
    })

    this.particles = new THREE.Points(threadGeometry, threadMaterial)
    this.scene.add(this.particles)

    const glowGeometry = new THREE.BufferGeometry()
    const glowCount = 50
    const glowPositions = new Float32Array(glowCount * 3)

    for (let i = 0; i < glowCount; i++) {
      glowPositions[i * 3] = (Math.random() - 0.5) * 16
      glowPositions[i * 3 + 1] = (Math.random() - 0.5) * 12
      glowPositions[i * 3 + 2] = (Math.random() - 0.5) * 8 - 4
    }

    glowGeometry.setAttribute('position', new THREE.BufferAttribute(glowPositions, 3))

    const glowMaterial = new THREE.PointsMaterial({
      size: 0.25,
      color: 0xffffff,
      transparent: true,
      opacity: 0.5,
      blending: THREE.AdditiveBlending,
    })

    this.glowParticles = new THREE.Points(glowGeometry, glowMaterial)
    this.scene.add(this.glowParticles)
  }

  animate() {
    this.animationId = requestAnimationFrame(() => this.animate())

    const time = performance.now() * 0.001

    this.targetMouse.x += (this.mouse.x - this.targetMouse.x) * 0.05
    this.targetMouse.y += (this.mouse.y - this.targetMouse.y) * 0.05

    this.meshes.forEach((mesh) => {
      mesh.rotation.x += mesh.userData.rotationSpeed.x
      mesh.rotation.y += mesh.userData.rotationSpeed.y
      mesh.rotation.z += mesh.userData.rotationSpeed.z

      const floatY = Math.sin(time * mesh.userData.floatSpeed + mesh.userData.floatOffset) * mesh.userData.floatAmplitude
      const floatX = Math.cos(time * mesh.userData.floatSpeed * 0.7 + mesh.userData.floatOffset) * mesh.userData.floatAmplitude * 0.5
      mesh.position.y = mesh.userData.originalPosition.y + floatY
      mesh.position.x = mesh.userData.originalPosition.x + floatX
    })

    this.mainGroup.rotation.y = this.targetMouse.x * 0.1
    this.mainGroup.rotation.x = -this.targetMouse.y * 0.05

    if (this.particles) {
      this.particles.rotation.y += 0.0003
      this.particles.rotation.x += 0.0001

      const positions = this.particles.geometry.attributes.position.array
      for (let i = 0; i < positions.length; i += 3) {
        positions[i + 1] += Math.sin(time + i) * 0.001
      }
      this.particles.geometry.attributes.position.needsUpdate = true
    }

    if (this.glowParticles) {
      this.glowParticles.rotation.y -= 0.0005
      const glowOpacity = 0.3 + Math.sin(time * 2) * 0.2
      this.glowParticles.material.opacity = glowOpacity
    }

    this.renderer.render(this.scene, this.camera)
  }

  handleResize() {
    this.onResize = () => {
      this.camera.aspect = this.element.clientWidth / this.element.clientHeight
      this.camera.updateProjectionMatrix()
      this.renderer.setSize(this.element.clientWidth, this.element.clientHeight)
    }

    window.addEventListener('resize', this.onResize)
  }

  handleMouseMove() {
    this.onMouseMove = (event) => {
      this.mouse.x = (event.clientX / window.innerWidth) * 2 - 1
      this.mouse.y = (event.clientY / window.innerHeight) * 2 - 1
    }

    window.addEventListener('mousemove', this.onMouseMove)
  }
}
