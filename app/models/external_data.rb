# frozen_string_literal: true

class ExternalData < ApplicationRecord
  DATASETS = { reserved: 0,
               iapd_advisors: 1,
               iapd_schedule_a: 2,
               nycc: 3 }.freeze

  DESCRIPTIONS = {
    iapd_advisors: 'Investor Advisor corporations registered with the SEC',
    iapd_schedule_a: 'Owners and board members of investor advisors',
    nycc: 'New York City Council Members'
  }.with_indifferent_access.freeze

  DATASET_NAMES = DATASETS.keys.without(:reserved).map(&:to_s).freeze
  DATASETS_INVERTED = DATASETS.invert.freeze

  Stats = Struct.new(:name, :description, :total, :matched, :unmatched, keyword_init: true) do
    def percent_matched
      ((matched / total.to_f) * 100).round(1)
    end

    def url
      Rails.application.routes.url_helpers
        .external_entities_path(dataset: name, matched: 'unmatched')
    end
  end

  enum dataset: DATASETS

  serialize :data, JSON

  has_one :external_entity, required: false, dependent: :destroy

  def merge_data(d)
    if data.nil?
      self.data = d
    elsif data.is_a? Hash
      self.data = data.merge(d)
    else
      raise Exceptions::LittleSisError, 'Incorrectly serialized data attribute'
    end
    self
  end

  def self.dataset_count
    connection.exec_query(<<~SQL).map { |h| h.merge!('dataset' => DATASETS_INVERTED[h['dataset']]) }
      SELECT dataset, COUNT(*) as count
      FROM external_data
      GROUP BY dataset
    SQL
  end

  def self.dataset?(x)
    DATASET_NAMES.include? x.to_s.downcase
  end

  # This is the backend for the external data overview table
  # input: Datatables::Params
  def self.datatables_query(params)
    relation = if params.search_requested?
                 dataset_search(params)
               else
                 public_send(params.dataset)
               end

    if %i[matched unmatched].include? params.matched
      relation = relation.public_send(params.matched)
    end

    Datatables::Response.new(draw: params.draw).tap do |response|
      response.recordsTotal = records_total(params.dataset)
      response.recordsFiltered = relation.count
      response.data = relation.to_datatables_array(params)
    end
  end

  # +params+ should be a Datatables::Params (or have two attributes/methods: search_value, dataset)
  def self.dataset_search(params)
    query = "%#{params.search_value}%"

    case params.dataset
    when 'nycc'
      nycc
        .where("JSON_VALUE(data, '$.FullName') like ?", query)
        .order(params.order_hash)
    when 'iapd_advisors'
      iapd_advisors
        .where("JSON_SEARCH(data, 'one', ?, null, '$.names') iS NOT NULL", query)
        .order(params.order_hash)
    when 'iapd_schedule_a'
      iapd_schedule_a
        .where("JSON_SEARCH(data, 'one', ?, null, '$.records[*].name') IS NOT NULL", query)
        .order(params.order_hash)
    else
      raise NotImplementedError
    end
  end

  def self.to_datatables_array(params)
    preload(:external_entity)
      .offset(params.start)
      .limit(params.length)
      .to_a.map do |external_data|
      {
        id: external_data.id,
        external_entity_id: external_data.external_entity&.id,
        matched: external_data.external_entity&.matched?,
        data: external_data.data
      }
    end
  end

  def self.matched
    joins(:external_entity).where('external_entities.entity_id IS NOT NULL')
  end

  def self.unmatched
    joins(:external_entity).where('external_entities.entity_id IS NULL')
  end

  def self.stats(dataset)
    verify_dataset!(dataset)

    Stats.new(name: dataset,
              description: DESCRIPTIONS[dataset],
              total: records_total(dataset),
              matched: public_send(dataset).matched.count,
              unmatched: public_send(dataset).unmatched.count)
  end

  private_class_method def self.records_total(dataset)
    class_eval "#{dataset}.count"
  end

  private_class_method def self.verify_dataset!(x)
    unless dataset?(x)
      raise Exceptions::LittleSisError # , "Invalid Dataset: #{x}"
    end
  end
end
