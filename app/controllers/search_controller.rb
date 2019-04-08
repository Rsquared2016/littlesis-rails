# frozen_string_literal: true

class SearchController < ApplicationController
  before_action :authenticate_user!, except: [:basic]
  before_action :set_page, only: [:basic]
  before_action :set_initial_search_values, only: [:basic]

  def basic
    query = params[:q]
    user_is_admin = current_user&.admin?

    if query.present?
      service = SearchService.new(query, page: @page, admin: user_is_admin)
      @entities = service.entities

      # On the first page we show results for all categories. Only entities is paginated.
      if @page == 1 
        @lists = service.lists
        @maps = service.maps
        @tags = service.tags if user_is_admin
      end
    end

    @no_results = (@lists.count + @entities.count + @maps.count + @tags.count).zero?

    respond_to do |format|
      format.html { render 'basic' }

      format.json do
        entities = @entities.map { |e| e.to_hash(image_url: true) }
        render json: { entities: entities }
      end
    end
  end

  # /search/entity
  # require param: q
  # optional params:
  #  - ext : "org" or "person"
  #  - num : Int
  #  - tags | String|Array (if string, can be comma seperated'
  #  - return_type : String
  def entity_search
    return head :bad_request if params[:q].blank?

    search_results = EntitySearchService
                       .new(query: params[:q], **entity_search_options)
                       .search

    if params[:return_type]&.downcase == 'simple'
      search_results.map! { |e| EntitySearchService.simple_entity_hash(e) }
    else
      search_results.map! { |e| e.to_hash(image_url: true) }
    end

    render json: search_results
  end

  private

  def entity_search_options
    {}.tap do |options|
      options[:with] = { primary_ext: params[:ext].capitalize } if params[:ext]
      options[:num] = params[:num].to_i if params[:num]
      options[:tags] = params[:tags] if params[:tags]
    end
  end

  def set_initial_search_values
    @entities = []
    @groups = []
    @lists = []
    @maps = []
    @tags = []
  end

  def set_page
    @page = params.fetch(:page, 1).to_i
  end
end
