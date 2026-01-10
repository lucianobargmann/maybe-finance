class Category < ApplicationRecord
  has_many :transactions, dependent: :nullify, class_name: "Transaction"
  has_many :import_mappings, as: :mappable, dependent: :destroy, class_name: "Import::Mapping"

  belongs_to :family

  has_many :budget_categories, dependent: :destroy
  has_many :subcategories, class_name: "Category", foreign_key: :parent_id, dependent: :nullify
  belongs_to :parent, class_name: "Category", optional: true

  validates :name, :color, :lucide_icon, :family, presence: true
  validates :name, uniqueness: { scope: :family_id }

  validate :category_level_limit
  validate :nested_category_matches_parent_classification

  before_save :inherit_color_from_parent

  scope :alphabetically, -> { order(:name) }
  scope :roots, -> { where(parent_id: nil) }
  scope :incomes, -> { where(classification: "income") }
  scope :expenses, -> { where(classification: "expense") }

  COLORS = %w[#e99537 #4da568 #6471eb #db5a54 #df4e92 #c44fe9 #eb5429 #61c9ea #805dee #6ad28a]

  UNCATEGORIZED_COLOR = "#737373"
  TRANSFER_COLOR = "#444CE7"
  PAYMENT_COLOR = "#db5a54"
  TRADE_COLOR = "#e99537"

  class Group
    attr_reader :category, :subcategories

    delegate :name, :color, to: :category

    def self.for(categories)
      categories.select { |category| category.parent_id.nil? }.map do |category|
        new(category, category.subcategories)
      end
    end

    def initialize(category, subcategories = nil)
      @category = category
      @subcategories = subcategories || []
    end
  end

  class << self
    def icon_codes
      %w[bus circle-dollar-sign ambulance apple award baby battery lightbulb bed-single beer bluetooth book briefcase building credit-card camera utensils cooking-pot cookie dices drama dog drill drum dumbbell gamepad-2 graduation-cap house hand-helping ice-cream-cone phone piggy-bank pill pizza printer puzzle ribbon shopping-cart shield-plus ticket trees]
    end

    def bootstrap!
      # Create top-level categories (6 Jars + Income)
      default_categories.each do |name, color, icon, classification|
        find_or_create_by!(name: name) do |category|
          category.color = color
          category.classification = classification
          category.lucide_icon = icon
        end
      end

      # Create subcategories under each jar
      default_subcategories.each do |parent_name, subcats|
        parent = find_by(name: parent_name)
        next unless parent

        subcats.each do |subcat_name, subcat_icon|
          find_or_create_by!(name: subcat_name, parent_id: parent.id) do |category|
            category.color = parent.color
            category.classification = parent.classification
            category.lucide_icon = subcat_icon
          end
        end
      end
    end

    def uncategorized
      new(
        name: I18n.t("categories.default_categories.uncategorized"),
        color: UNCATEGORIZED_COLOR,
        lucide_icon: "circle-dashed"
      )
    end

    private
      def default_categories
        [
          # Income category
          [ I18n.t("categories.default_categories.income"), "#e99537", "circle-dollar-sign", "income" ],

          # 6 Jars - Top level expense categories
          [ I18n.t("categories.default_categories.necessities"), "#3b82f6", "home", "expense" ],
          [ I18n.t("categories.default_categories.financial_freedom"), "#22c55e", "trending-up", "expense" ],
          [ I18n.t("categories.default_categories.education"), "#eab308", "graduation-cap", "expense" ],
          [ I18n.t("categories.default_categories.long_term_savings"), "#a855f7", "piggy-bank", "expense" ],
          [ I18n.t("categories.default_categories.play"), "#ec4899", "gamepad-2", "expense" ],
          [ I18n.t("categories.default_categories.give"), "#f97316", "hand-helping", "expense" ]
        ]
      end

      def default_subcategories
        {
          I18n.t("categories.default_categories.necessities") => [
            [ I18n.t("categories.default_categories.rent_and_utilities"), "lightbulb" ],
            [ I18n.t("categories.default_categories.food_and_drink"), "utensils" ],
            [ I18n.t("categories.default_categories.transportation"), "bus" ],
            [ I18n.t("categories.default_categories.healthcare"), "pill" ],
            [ I18n.t("categories.default_categories.personal_care"), "heart" ],
            [ I18n.t("categories.default_categories.loan_payments"), "credit-card" ],
            [ I18n.t("categories.default_categories.fees"), "receipt" ],
            [ I18n.t("categories.default_categories.services"), "briefcase" ]
          ],
          I18n.t("categories.default_categories.financial_freedom") => [
            [ I18n.t("categories.default_categories.investments"), "trending-up" ]
          ],
          I18n.t("categories.default_categories.education") => [
            [ I18n.t("categories.default_categories.courses"), "book" ],
            [ I18n.t("categories.default_categories.books"), "book-open" ]
          ],
          I18n.t("categories.default_categories.long_term_savings") => [
            [ I18n.t("categories.default_categories.emergency_fund"), "shield-plus" ],
            [ I18n.t("categories.default_categories.travel"), "plane" ],
            [ I18n.t("categories.default_categories.home_improvement"), "house" ]
          ],
          I18n.t("categories.default_categories.play") => [
            [ I18n.t("categories.default_categories.entertainment"), "drama" ],
            [ I18n.t("categories.default_categories.shopping"), "shopping-cart" ],
            [ I18n.t("categories.default_categories.dining_out"), "utensils" ]
          ],
          I18n.t("categories.default_categories.give") => [
            [ I18n.t("categories.default_categories.gifts_and_donations"), "gift" ],
            [ I18n.t("categories.default_categories.charity"), "heart" ]
          ]
        }
      end
  end

  def inherit_color_from_parent
    if subcategory?
      self.color = parent.color
    end
  end

  def replace_and_destroy!(replacement)
    transaction do
      transactions.update_all category_id: replacement&.id
      destroy!
    end
  end

  def parent?
    subcategories.any?
  end

  def subcategory?
    parent.present?
  end

  private
    def category_level_limit
      if (subcategory? && parent.subcategory?) || (parent? && subcategory?)
        errors.add(:parent, "can't have more than 2 levels of subcategories")
      end
    end

    def nested_category_matches_parent_classification
      if subcategory? && parent.classification != classification
        errors.add(:parent, "must have the same classification as its parent")
      end
    end

    def monetizable_currency
      family.currency
    end
end
