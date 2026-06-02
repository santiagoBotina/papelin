import { Controller } from "@hotwired/stimulus"

// Shows a violet "unsaved changes" dot next to the section title
// when any form field value differs from its initial snapshot.
// The submit button is always visible regardless of JS state.
export default class extends Controller {
  static targets = ["indicator"]

  connect() {
    this.snapshot = this.takeSnapshot()
    this.refresh()
  }

  // Fires on `change` / `input` for each tracked field
  fieldChanged() {
    this.refresh()
  }

  // After a successful Turbo submission, re-snapshot so the dot disappears
  submitSuccess() {
    this.snapshot = this.takeSnapshot()
    this.refresh()
  }

  // ── private ──

  refresh() {
    if (!this.hasIndicatorTarget) return

    const dirty = this.isDirty()

    this.indicatorTarget.classList.toggle("opacity-0", !dirty)
    this.indicatorTarget.classList.toggle("pointer-events-none", !dirty)
    this.indicatorTarget.classList.toggle("opacity-100", dirty)
    this.indicatorTarget.classList.toggle("pointer-events-auto", dirty)
  }

  isDirty() {
    const current = this.takeSnapshot()
    if (Object.keys(current).length !== Object.keys(this.snapshot).length) return true
    return Object.keys(this.snapshot).some((k) => this.snapshot[k] !== current[k])
  }

  takeSnapshot() {
    const data = new FormData(this.element)
    const map = {}
    for (const [key, val] of data.entries()) {
      if (key === "authenticity_token" || key === "_method" || key === "commit") continue
      map[key] = val
    }
    return map
  }
}
