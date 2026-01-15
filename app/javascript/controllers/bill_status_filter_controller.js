import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "item", "emptyMessage"];
  static values = { selected: { type: String, default: "all" } };

  connect() {
    this.filter();
  }

  select(event) {
    const status = event.currentTarget.dataset.status;
    this.selectedValue = status;
    this.filter();
  }

  filter() {
    // Update tab active states
    this.tabTargets.forEach((tab) => {
      const isActive = tab.dataset.status === this.selectedValue;
      tab.classList.toggle("bg-container", isActive);
      tab.classList.toggle("text-primary", isActive);
      tab.classList.toggle("shadow-xs", isActive);
      tab.classList.toggle("text-secondary", !isActive);
    });

    // Filter items
    let visibleCount = 0;
    this.itemTargets.forEach((item) => {
      const itemStatus = item.dataset.billStatus;
      const shouldShow =
        this.selectedValue === "all" || itemStatus === this.selectedValue;
      item.classList.toggle("hidden", !shouldShow);
      if (shouldShow) visibleCount++;
    });

    // Show/hide empty message
    if (this.hasEmptyMessageTarget) {
      this.emptyMessageTarget.classList.toggle("hidden", visibleCount > 0);
    }
  }
}
