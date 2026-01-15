class BillMatcherJob < ApplicationJob
  queue_as :medium_priority

  def perform(family)
    family.auto_match_bills!
  end
end
