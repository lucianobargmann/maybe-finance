import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="transaction-type-tabs"
export default class extends Controller {
  static targets = ["expenseTab", "incomeTab", "natureField", "categorySelect"];
  static values = {
    expenseCategories: Array,
    incomeCategories: Array,
    categoryPrompt: String
  };

  selectExpense() {
    this.activateTab("expense");
    this.updateNatureField("outflow");
    this.updateCategories(this.expenseCategoriesValue);
  }

  selectIncome() {
    this.activateTab("income");
    this.updateNatureField("inflow");
    this.updateCategories(this.incomeCategoriesValue);
  }

  activateTab(type) {
    const activeClass = "bg-container text-primary shadow-sm";
    const inactiveClass = "hover:bg-container text-subdued hover:text-primary hover:shadow-sm";

    if (type === "expense") {
      this.expenseTabTarget.className = this.buildTabClass(activeClass);
      this.incomeTabTarget.className = this.buildTabClass(inactiveClass);
    } else {
      this.expenseTabTarget.className = this.buildTabClass(inactiveClass);
      this.incomeTabTarget.className = this.buildTabClass(activeClass);
    }
  }

  buildTabClass(stateClass) {
    return `flex px-4 py-1 rounded-lg items-center space-x-2 justify-center text-sm ${stateClass}`;
  }

  updateNatureField(value) {
    if (this.hasNatureFieldTarget) {
      this.natureFieldTarget.value = value;
    }
  }

  updateCategories(categories) {
    if (!this.hasCategorySelectTarget) return;

    const select = this.categorySelectTarget;
    const currentValue = select.value;

    // Clear existing options except the prompt
    select.innerHTML = "";

    // Add prompt option
    if (this.categoryPromptValue) {
      const promptOption = document.createElement("option");
      promptOption.value = "";
      promptOption.textContent = this.categoryPromptValue;
      select.appendChild(promptOption);
    }

    // Add category options
    categories.forEach(([name, id]) => {
      const option = document.createElement("option");
      option.value = id;
      option.textContent = name;
      select.appendChild(option);
    });

    // Try to preserve current selection if it exists in new list
    const valueExists = categories.some(([_, id]) => String(id) === String(currentValue));
    if (valueExists) {
      select.value = currentValue;
    }
  }
}
