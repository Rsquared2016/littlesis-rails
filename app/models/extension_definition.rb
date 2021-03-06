# frozen_string_literal: true

class ExtensionDefinition < ApplicationRecord
  include SingularTable

  has_many :extension_records,
           foreign_key: 'definition_id',
           inverse_of: :extension_definition,
           dependent: :nullify

  has_many :entities,
           through: :extension_records,
           inverse_of: :extension_definitions

  PERSON_ID = 1
  ORG_ID = 2

  def self.not_tier_one
    where.not(tier: 1)
  end

  def self.matches_parent_id_or_nil(parent_id)
    arel_table[:parent_id].eq(parent_id).or(arel_table[:parent_id].eq(nil))
  end

  def self.person_types
    not_tier_one
      .where(matches_parent_id_or_nil(PERSON_ID))
      .order(name: :asc)
  end

  def self.org_types
    not_tier_one
      .where(matches_parent_id_or_nil(ORG_ID))
      .order(name: :asc)
  end

  def self.org_types_tier2
    where(matches_parent_id_or_nil(ORG_ID))
      .where(tier: 2)
      .order(name: :asc)
  end

  def self.org_types_tier3
    where(matches_parent_id_or_nil(ORG_ID))
      .where(tier: 3)
      .order(name: :asc)
  end

  def self.definition_ids_with_fields
    where(has_fields: true).map(&:id)
  end

  # Returns a memozined hash map from definition id to display name
  def self.display_names
    @display_names_lookup ||= all.inject({}) do |acc, ed|
      acc.tap { |hash| hash.store(ed.id, ed.display_name) }
    end
  end
end
