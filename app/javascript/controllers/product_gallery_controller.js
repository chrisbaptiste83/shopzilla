import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mainImage", "thumbnail"]

  select(event) {
    const thumbnail = event.currentTarget
    const fullSrc = thumbnail.dataset.productGalleryFullSrc

    if (this.hasMainImageTarget && fullSrc) {
      this.mainImageTarget.src = fullSrc
    }

    this.thumbnailTargets.forEach((element) => element.removeAttribute("aria-current"))
    thumbnail.setAttribute("aria-current", "true")
  }
}
