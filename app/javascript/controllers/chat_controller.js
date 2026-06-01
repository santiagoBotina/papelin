import { Controller } from "@hotwired/stimulus"

// Manages chat UI behavior: auto-scrolling, input clearing, and submit button state.
export default class extends Controller {
  static targets = ["messages", "input", "submit"]

  connect() {
    this.scrollToBottom()
  }

  // Fires automatically when Turbo appends a new message element
  messagesTargetConnected() {
    this.scrollToBottom()
  }

  clearAndFocus() {
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }

  disableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
  }

  enableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
    }
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }
}
