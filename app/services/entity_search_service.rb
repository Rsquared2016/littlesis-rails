# frozen_string_literal: true

class EntitySearchService
  DEFAULT_OPTIONS = {
    with: { is_deleted: false },
    fields: %w[name aliases],
    num: 15,
    page: 1,
    tags: nil,
    exclude_list: nil
  }.freeze

  attr_reader :query, :options, :search_options, :search
  alias_attribute :results, :search

  # Class Methods

  def self.simple_entity_hash(e)
    { id: e.id,
      name: e.name,
      blurb: e.blurb,
      primary_ext: e.primary_ext,
      url: e.url }
  end

  def initialize(query:, **kwargs)
    @query = LsSearch.escape(query)
    @options = DEFAULT_OPTIONS.deep_merge(kwargs)

    @search_options = {
      with: @options[:with],
      per_page: @options[:num].to_i,
      page: @options[:page].to_i,
      select: '*, weight() * (link_count + 1) AS link_weight',
      order: 'link_weight DESC'
    }

    @search_query = "@(#{@options[:fields].join(',')}) #{@query}"

    parse_tags
    parse_exclude_list

    @search = Entity.search @search_query, @search_options
    freeze
  end

  private

  # This instructs sphinx to exlude all entities that are already on provided list.
  def parse_exclude_list
    return if @options[:exclude_list].nil?

    ids_to_exclude = ListEntity.where(list_id: @options[:exclude_list]).pluck(:entity_id)
    @search_options[:without] = { sphinx_internal_id: ids_to_exclude }
  end

  def parse_tags
    return if @options[:tags].nil?

    TypeCheck.check @options[:tags], [String, Array]

    @options[:tags] = @options[:tags].split(',') if @options[:tags].is_a?(String)

    @options[:tags].map! do |tag|
      Tag.get(tag).tap do |t|
        Rails.logger.warn "[EntitySearchService]: unknown tag: #{tag}" if t.nil?
      end
    end

    @options[:tags].compact!
    @options[:tags].map!(&:id)

    if @options[:tags]&.length&.positive?
      @search_options[:with_all] = { tag_ids: @options[:tags] }
    end
  end
end