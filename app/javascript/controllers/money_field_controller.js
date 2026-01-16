import { Controller } from "@hotwired/stimulus";
import { CurrenciesService } from "services/currencies_service";

// Connects to data-controller="money-field"
// when currency select change, update the input value with the correct placeholder and step
export default class extends Controller {
  static targets = ["amount", "currency", "symbol"];

  connect() {
    // Add event listener for comma-to-dot conversion
    if (this.hasAmountTarget) {
      this.amountTarget.addEventListener("keydown", this.handleKeyDown.bind(this));
      this.amountTarget.addEventListener("input", this.handleInput.bind(this));
    }
  }

  disconnect() {
    if (this.hasAmountTarget) {
      this.amountTarget.removeEventListener("keydown", this.handleKeyDown.bind(this));
      this.amountTarget.removeEventListener("input", this.handleInput.bind(this));
    }
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

  handleCurrencyChange(e) {
    const selectedCurrency = e.target.value;
    this.updateAmount(selectedCurrency);
  }

  updateAmount(currency) {
    new CurrenciesService().get(currency).then((currency) => {
      this.amountTarget.step = currency.step;

      if (Number.isFinite(this.amountTarget.value)) {
        this.amountTarget.value = Number.parseFloat(
          this.amountTarget.value,
        ).toFixed(currency.default_precision);
      }

      this.symbolTarget.innerText = currency.symbol;
    });
  }
}
