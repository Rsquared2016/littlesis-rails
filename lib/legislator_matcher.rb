# frozen_string_literal: true

# rubocop:disable Security/Open

require 'uri'
require 'open-uri'

# Processes congressional legistors yaml files and matches
# each legistor with existing LittleSis entities
class LegislatorMatcher
  # CURRENT_YAML = 'https://theunitedstates.io/congress-legislators/legislators-current.yaml'
  # HISTORICAL_YAML = 'https://theunitedstates.io/congress-legislators/legislators-historical.yaml'
  CURRENT_YAML = Rails.root.join('tmp', 'legislators-current.yaml').to_s
  HISTORICAL_YAML = Rails.root.join('tmp', 'legislators-historical.yaml').to_s

  HOUSE_OF_REPS = 12_884
  SENATE = 12_885

  CONGRESS_BOT_USER = 1
  CONGRESS_BOT_SF_USER = 1

  attr_reader :current_reps, :historical_reps, :reps

  # Wrapper around the hash parsed from
  # the theunitedstates.io's yaml file
  class Legislator < SimpleDelegator
    attr_reader :match_type

    def representative?
      types.include? 'rep'
    end

    def senator?
      types.include? 'sen'
    end

    def types
      return @_types if defined?(@_types)
      @_types = fetch('terms').map { |t| t['type'] }.uniq
    end

    def match
      return @_match if defined?(@_match)
      @_match = _match
    end

    def import!
      transaction do
        if match.blank?
          create_new_entity
        else
          match.website = fetch_website
          match.start_date = dig('bio', 'birthday') if dig('bio', 'birthday')
          match.assign_attribute_unless_present :blurb, generate_blurb
          match.person.assign_attribute_unless_present :name_middle, dig('name', 'middle')
          match.person.gender_id = Person.gender_to_id(dig('bio', 'gender'))
          if match.changed?
            match.last_user_id = CONGRESS_BOT_SF_USER
            match.save!
          end

          add_alias if dig('name', 'official_full')

          match.add_extension('ElectedRepresentative')
          match.elected_representative.update!(to_elected_representative_attributes)
        end
      end
    end

    def match_entity_attributes
      LsHash
        .new(website: fetch_website, start_date: dig('bio', 'birthday'))
        .remove_nil_vals
    end

    # Attributes when creating a new entity;

    def to_entity_attributes
      LsHash.new(
        name: generate_name,
        primary_ext: 'Person',
        blurb: generate_blurb,
        website: fetch_website,
        start_date: dig('bio', 'birthday'),
        last_user_id: CONGRESS_BOT_SF_USER
      ).remove_nil_vals
    end

    def to_person_attributes
      LsHash.new(
        name_last: dig('name', 'last'),
        name_first: dig('name', 'first'),
        name_middle: dig('name', 'middle'),
        name_suffix: dig('name', 'suffix'),
        name_nick: dig('name', 'nick'),
        gender_id: Person.gender_to_id(dig('bio', 'gender'))
      ).remove_nil_vals
    end

    def to_elected_representative_attributes
      LsHash.new(
        bioguide_id: dig('id', 'bioguide'),
        govtrack_id: dig('id', 'govtrack'),
        crp_id: dig('id', 'opensecrets'),
        fec_ids: dig('id', 'fec')
      ).remove_nil_vals
    end

    # returns +Entity+ or Nil.
    # sets @match_type to be :name, :id, :none
    def _match
      bioguide_or_govtrack_match = match_by_bioguide_or_govtrack

      if bioguide_or_govtrack_match
        @match_type = :id
        return bioguide_or_govtrack_match
      end

      name_match = match_by_name

      if name_match
        @match_type = :name
      else
        @match_type = :none
      end

      name_match
    end

    def match_by_bioguide_or_govtrack
      entity = match_by_bioguide dig('id', 'bioguide')
      return entity if entity
      match_by_govtrack dig('id', 'govtrack').to_s if dig('id', 'govtrack').present?
    end

    def match_by_name
      potential_matches.automatch&.entity
    end

    def potential_matches
      person = fetch('name')
                 .slice('first', 'middle', 'last', 'suffix')
                 .transform_keys { |k| "name_#{k}" }

      associated = []
      associated << HOUSE_OF_REPS if representative?
      associated << SENATE if senator?

      EntityMatcher.find_matches_for_person(person, associated: associated)
    end

    private

    def transaction
      PaperTrail.whodunnit(CONGRESS_BOT_USER.to_s) do
        ApplicationRecord.transaction do
          yield
        end
      end
    end

    def create_new_entity
      entity = Entity.create!(to_entity_attributes)
      entity.person.update!(to_person_attributes)
      entity.add_extension('ElectedRepresentative', to_elected_representative_attributes)
      entity
    end

    def add_alias
      unless match.also_known_as.map(&:downcase).include? dig('name', 'official_full').downcase
        match.aliases.create!(name: dig('name', 'official_full'),
                              last_user_id: CONGRESS_BOT_SF_USER)
      end
    end

    def fetch_website
      fetch('terms').last.fetch('url', nil)
    end

    def generate_name
      dig('name', 'official_full').presence || "#{fetch('first')} #{fetch('last')}"
    end

    def generate_blurb
      term = fetch('terms').last
      rep_or_sen = term['type'] == 'sen' ? 'Senator' : "Representative"
      state = AddressState.abbreviation_map.fetch(term['state'].upcase)

      "US #{rep_or_sen} from #{state}"
    rescue # rubocop:disable Style/RescueStandardError
      nil
    end

    def match_by_bioguide(bioguide_id)
      ElectedRepresentative.find_by(bioguide_id: bioguide_id)&.entity
    end

    def match_by_govtrack(govtrack_id)
      ElectedRepresentative.find_by(govtrack_id: govtrack_id)&.entity
    end
  end

  def initialize
    open(CURRENT_YAML) { |f| @current_reps = YAML.load_file f }
    open(HISTORICAL_YAML) { |f| @historical_reps = YAML.load_file f }
    # Reps since 1990, returns array of YAML objects
    @reps = (historical_reps_after_1990 | @current_reps).map { |rep| Legislator.new(rep) }
  end

  def match_all
    @reps.each(&:match)
  end

  private

  def historical_reps_after_1990
    historical_reps.select do |r|
      r['terms'].select { |t| t['start'].slice(0, 4) >= '1990' }.present?
    end
  end
end

# rubocop:enable Security/Open
