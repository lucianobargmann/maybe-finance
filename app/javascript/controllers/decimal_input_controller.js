import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="decimal-input"
// Allows comma as decimal separator in number inputs (for pt-BR and other locales)
export default class extends Controller {
  connect() {
    this.element.addEventListener("keydown", this.handleKeyDown.bind(this));
    this.element.addEventListener("input", this.handleInput.bind(this));
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.handleKeyDown.bind(this));
    this.element.removeEventListener("input", this.handleInput.bind(this));
  }

  // Handle comma key press - convert to dot for number input
  handleKeyDown(e) {
    if (e.key === ",") {
      e.preventDefault();
      const input = e.target;
      const start = input.selectionStart;
      const end = input.selectionEnd;
      const value = input.value;

      // Only add dot if there isn't one already
      if (!value.includes(".")) {
        input.value = `${value.substring(0, start)}.${value.substring(end)}`;
        input.setSelectionRange(start + 1, start + 1);
        input.dispatchEvent(new Event("input", { bubbles: true }));
      }
    }
  }

  // Handle paste events - replace comma with dot
  handleInput(e) {
    const input = e.target;
    if (input.value.includes(",")) {
      const start = input.selectionStart;
      input.value = input.value.replace(",", ".");
      input.setSelectionRange(start, start);
    }
  }
}
