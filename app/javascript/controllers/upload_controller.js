import { Controller } from "@hotwired/stimulus"

// Manages drag-and-drop file upload: highlight on dragover, file preview on drop/select.
export default class extends Controller {
  static targets = ["dropzone", "fileInput", "filename", "preview"]

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-blue-500", "bg-blue-50")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")

    const file = event.dataTransfer.files[0]
    if (!file) return

    // Use DataTransfer API to assign the file to the hidden input
    const dt = new DataTransfer()
    dt.items.add(file)
    this.fileInputTarget.files = dt.files

    // Trigger change event so Rails validates the file
    this.fileInputTarget.dispatchEvent(new Event("change", { bubbles: true }))

    this.showPreview(file)
  }

  fileSelected() {
    const file = this.fileInputTarget.files[0]
    if (file) this.showPreview(file)
  }

  showPreview(file) {
    this.filenameTarget.textContent = file.name
    this.previewTarget.classList.remove("hidden")
  }
}
