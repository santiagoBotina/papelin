import { Controller } from "@hotwired/stimulus"

// Manages chat UI: auto-scroll, input clearing, submit state, Cmd/Ctrl+Enter shortcut.
export default class extends Controller {
  static targets = ["messages", "input", "submit"]

  connect() {
    this.scrollToBottom()
  }

  // Fires when Turbo appends a new message element into the messages target
  messagesTargetConnected() {
    this.scrollToBottom()
  }

  // Cmd+Enter (Mac) or Ctrl+Enter (Win/Linux) submits the form
  keydown(event) {
    const isMac     = navigator.platform.toUpperCase().includes("MAC")
    const modifier  = isMac ? event.metaKey : event.ctrlKey
    if (modifier && event.key === "Enter") {
      event.preventDefault()
      const content = this.hasInputTarget ? this.inputTarget.value.trim() : ""
      if (content.length === 0) return          // don't submit blank
      this.element.closest("form")?.requestSubmit()
    }
  }

  disableSubmit() {
    // ⚠ Do NOT touch inputTarget here — Turbo reads form data AFTER the submit event fires.
    // Clearing the textarea before Turbo serialises it sends an empty payload.
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.value = "Enviando…"
    }
  }

  enableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.value = "Enviar"
    }
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }
}
