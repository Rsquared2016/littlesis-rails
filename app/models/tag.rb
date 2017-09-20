class Tag < ActiveRecord::Base
  TAGABLE_PAGINATION_LIMIT = 20

  has_many :taggings

  # create associations for all tagable classes
  # ie: tag#entities, tag#lists, tag#relationships, etc...
  Tagable.classes.each do |klass|
    has_many klass.category_sym, through: :taggings, source: :tagable, source_type: klass
  end

  validates :name, uniqueness: true, presence: true
  validates :description, presence: true

  # CLASS METHODS

  # (set, set) -> hash
  def self.parse_update_actions(client_ids, server_ids)
    {
      ignore: client_ids & server_ids,
      add: client_ids - server_ids,
      remove: server_ids - client_ids
    }
  end

  # String -> [Tag]
  def self.search_by_names(phrase)
    Tag.lookup.keys
      .select { |tag_name| phrase.downcase.include?(tag_name) }
      .map { |tag_name| lookup[tag_name] }
  end

  # String -> Tag | Nil
  # Search through tags find tag by name
  def self.search_by_name(query)
    lookup[query.downcase]
  end

  def self.lookup
    @lookup ||= Tag.all.reduce({}) do |acc, tag|
      acc.tap { |h| h.store(tag.name.downcase.tr('-', ' '), tag) }
    end
  end

  # INSTANCE METHODS

  def restricted?
    restricted
  end

  def tagables_for_homepage(tagable_category, page = 1)
    tagable_category == Entity.category_str ?
      entities_for_homepage(page) :
      default_tagables_for_homepage(tagable_category, page)
  end

  private

  def default_tagables_for_homepage(tagable_category, page = 1)
    public_send(tagable_category.to_sym)
      .order(updated_at: :desc)
      .page(page)
      .per(TAGABLE_PAGINATION_LIMIT)
  end

  def entities_for_homepage(page = 1)
    %w[Person Org].reduce({}) do |acc, type|
      acc.merge(type => paginate(page, *sort_and_count_entities(type, page)))
    end
  end

  def paginate(page, records, count)
    Kaminari
      .paginate_array(records, total_count: count)
      .page(page)
      .per(TAGABLE_PAGINATION_LIMIT)
  end

  def sort_and_count_entities(entity_type, page = 1)
    # return tuple of:
    # (1) all entities of type `entity_type` tagged `self`,
    #     sorted by # relationships to other entities also tagged `self`
    # (2) count of all entities of type `entity_type` tagged `self`
    [
      entities_by_relationship_count(entity_type, page),
      total_count(entity_type)
    ]
  end

  # Self -> [EntityActiveRecord, Int]
  def entities_by_relationship_count(entity_type, page = 1)
    # guard against SQL injection
    raise ArgumentError unless %w[Person Org].include?(entity_type)
    page = page.to_i

    entity_counts_sql = <<-SQL
      SELECT tagged_entity_links.tagable_id,

              # only count record in doubly-joined table if both entities in a link have correct tag
              SUM( case when tagged_entity_links.entity1_id is null then 0
       	         	when taggings.id is null then 0
	                else 1 end ) as num_related

       # join all of a tag's entities all of each entity's links
       FROM (
	    SELECT taggings.tagable_id, link.*
	    FROM taggings
	    LEFT JOIN link ON link.entity1_id = taggings.tagable_id
	    WHERE taggings.tag_id = #{id} AND taggings.tagable_class = 'Entity'
       ) AS tagged_entity_links

       # join to find out if linked-to entities are also tagged with our tag
       LEFT JOIN taggings
            ON tagged_entity_links.entity2_id = taggings.tagable_id
     	       AND taggings.tag_id = #{id}
	       AND taggings.tagable_class = 'Entity'

       # cull record set to unique list of tagged entities with relationship counts
       GROUP BY tagged_entity_links.tagable_id

       # sort
       ORDER BY num_related desc
    SQL

    sql = <<-SQL
       SELECT *
       FROM (#{entity_counts_sql}) AS entity_counts
       # recover entity fields
       INNER JOIN entity ON entity_counts.tagable_id = entity.id
       # filter by entity subtype
       WHERE entity.primary_ext = '#{entity_type}'
       # paginate
       LIMIT #{TAGABLE_PAGINATION_LIMIT}
       OFFSET #{(page - 1) * TAGABLE_PAGINATION_LIMIT}
      SQL

    Entity.find_by_sql(sql)
  end

  def total_count(entity_type)
    entities.where(primary_ext: entity_type).count
  end
end
