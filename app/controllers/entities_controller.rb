# frozen_string_literal: true

class EntitiesController < ApplicationController
  include TagableController
  include ReferenceableController

  ERRORS = ActiveSupport::HashWithIndifferentAccess.new(
    create_bulk: {
      errors: [{ 'title' => 'Could not create new entities: request formatted improperly' }]
    }
  )

  TABS = %w[interlocks political giving datatable].freeze

  before_action :authenticate_user!, except: [:show, :datatable, :political, :contributions, :references, :interlocks, :giving]
  before_action :block_restricted_user_access, only: [:new, :create, :update]
  before_action :set_entity, except: [:new, :create, :search_by_name, :search_field_names, :show, :create_bulk]
  before_action :set_entity_for_profile_page, only: [:show]
  before_action :importers_only, only: [:match_donation, :match_donations, :review_donations, :match_ny_donations, :review_ny_donations]
  before_action -> { check_permission('contributor') }, only: [:create]
  before_action :check_delete_permission, only: [:destroy]

  ## Profile Page Tabs:
  # (consider moving these all to #show route)
  def show
    @active_tab = :relationships
  end

  def interlocks
    @active_tab = :interlocks
    render 'show'
  end

  def giving
    @active_tab = :giving
    render 'show'
  end

  def political
  end

  # THE DATA 'tab'
  def datatable
  end

  def create_bulk
    # only responds to JSON, not possible to create extensions in POSTS to this endpoint
    entity_attrs = create_bulk_payload.map { |x| merge_last_user(x) }
    block_unless_bulker(entity_attrs, Entity::BULK_LIMIT) # see application_controller
    entities = Entity.create!(entity_attrs)
    render json: Api.as_api_json(entities), status: :created
  rescue ActionController::ParameterMissing, NoMethodError, ActiveRecord::RecordInvalid
    render json: ERRORS[:create_bulk], status: 400
  end

  def new
    @entity = Entity.new(name: params[:name]) if params[:name].present?
  end

  def create
    @entity = Entity.new(new_entity_params)

    if @entity.save # successfully created entity
      params[:types].each { |type| @entity.add_extension(type) } if params[:types].present?

      if add_relationship_page?
        render json: {
                 status: 'OK',
                 entity: {
                   id: @entity.id,
                   name: @entity.name,
                   description: @entity.blurb,
                   url: @entity.legacy_url,
                   primary_type: @entity.primary_ext
                 }
               }
      else
        redirect_to @entity.legacy_url("edit")
      end

    else # encounted error

      if add_relationship_page?
        render json: { status: 'ERROR', errors: @entity.errors.messages }
      else
        render action: 'new'
      end
      
    end
  end

  def edit
    set_entity_references
  end

  def update
    # assign new attributes to the entity
    @entity.assign_attributes(prepare_params(update_entity_params))
    # if those attributes are valid
    # update the entity extension records  and save the reference
    if @entity.valid?
      @entity.update_extension_records(extension_def_ids)
      @entity.add_reference(reference_params) if need_to_create_new_reference
      # Add_reference will make the entity invalid if the reference is invalid
      if @entity.valid?
        @entity.save!
        return render json: { status: 'OK' } if api_request?
        return redirect_to entity_path(@entity)
      end
    end
    set_entity_references
    render :edit
  end

  def destroy
    @entity.soft_delete
    redirect_to home_dashboard_path, notice: "#{@entity.name} has been successfully deleted"
  end

  def add_relationship
    @relationship = Relationship.new
    @reference = Reference.new
  end

  def references
    @page = params[:page].present? ? params[:page] : 1
  end

  # ------------------------------ #
  # Open Secrets Donation Matching #
  # ------------------------------ #

  def match_donations
  end

  def review_donations
  end

  def match_donation
    params[:payload].each do |donation_id|
      match = OsMatch.find_or_create_by(os_donation_id: donation_id, donor_id: params[:id])
      match.update(matched_by: current_user.id)
    end
    @entity.update(last_user_id: current_user.sf_guard_user.id)
    render json: { status: 'ok' }
  end

  def unmatch_donation
    check_permission 'importer'
    params[:payload].each do |os_match_id|
      OsMatch.find(os_match_id).destroy
    end
    @entity.update(last_user_id: current_user.sf_guard_user.id)
    render json: { status: 'ok' }
  end

  # ------------------------------ #
  # Open Secrets Contributions     #
  # ------------------------------ #

  def contributions
    expires_in(5.minutes, public: true)
    render json: @entity.contribution_info
  end

  def potential_contributions
    render json: @entity.potential_contributions
  end

  # ------------------------------ #
  # NYS Donation Matching          #
  # ------------------------------ #

  def match_ny_donations
  end

  def review_ny_donations
  end

  def fields
    @fields = JSON.dump(Field.all.map { |f| { value: f.name, tokens: f.display_name.split(/\s+/) } });
  end

  def update_fields
    if params[:names].nil? and params[:values].nil?
      fields = {}
    else
      fields = Hash[params[:names].zip(params[:values])]
    end
    @entity.update_fields(fields)
    Field.delete_unused
    redirect_to fields_entity_path(@entity)
  end

  def search_by_name
    data = []
    q = params[:q]
    num = params.fetch(:num, 10)
    fields = params[:desc] ? 'name,aliases,blurb' : 'name,aliases'
    entities = Entity.search(
      "@(#{fields}) #{q}", 
      per_page: num, 
      match_mode: :extended, 
      with: { is_deleted: false },
      select: "*, weight() * (link_count + 1) AS link_weight",
      order: "link_weight DESC"
    )
    data = entities.collect { |e| { value: e.name, name: e.name, id: e.id, blurb: e.blurb, url: datatable_entity_path(e), primary_ext: e.primary_ext } }

    if list_id = params[:exclude_list]
      entity_ids = ListEntity.where(list_id: list_id).pluck(:entity_id)
      data.delete_if { |e| entity_ids.include?(e[:id]) }
    end

    if params[:with_ids]
      dups = entities.group_by(&:name).select { |name, ary| ary.count > 1 }.keys
      data.map! do |hash|
        if dups.include?(hash[:name])
          info = hash[:blurb].present? ? hash[:blurb] : hash[:id].to_s
          hash[:value] = hash[:name] + " (#{info})"
        end
        hash
      end      
    end

    render json: data
  end

  def search_field_names
    q = params[:q]
    num = params.fetch(:num, 10)
    fields = Field.search(q, per_page: num, match_mode: :extended)
    render json: fields.map { |f| f.name }.sort
  end

  ##
  # Articles
  #

  def articles
  end

  def find_articles
    check_permission 'importer'
    @q = (params[:q] or @entity.name)
    page = (params[:page] or 1).to_i
    @articles = @entity.articles
    selected_urls = @articles.map(&:url)
    engine = GoogleSearch.new(Lilsis::Application.config.google_custom_search_engine_id)
    @results = engine.search(@q, page).to_a + engine.search(@q, page + 1).to_a
    @results.select! { |r| !selected_urls.include?(r['link']) }
  end

  def import_articles
    check_permission 'importer'
    selected_ids = params.keys.map(&:to_s).select { |k| k.match(/^selected-/) }.map { |k| k.split('-').last }.map(&:to_i)
    selected_ids.each do |i|
      snippet = CGI.unescapeHTML(params[:snippet][i])
      published_at = nil

      if date = snippet.match(/^\w{3}\s+\d+,\s+\d{4}/)
        published_at = date[0]
        snippet.gsub!(/^\w{3}\s+\d+,\s+\d{4}\s+\.\.\.\s+/, '')
      end

      @entity.add_article({
        title: CGI.unescapeHTML(params[:title][i]),
        url: CGI.unescapeHTML(params[:url][i]),
        snippet: snippet,
        published_at: published_at,
        created_by_user_id: current_user.id
      }, featured = true)
    end

    # permanently remove entity from queue
    if selected_ids.count == 0
      skip_queue_entity(:find_articles, @entity.id)
    end

    @queue_count = entity_queue_count(:find_articles)
    if @queue_count > 0
      if params[:submit_stay]
        redirect_to find_articles_entity_path(@entity.id)
      else
        redirect_to find_articles_entity_path(next_entity_in_queue(:find_articles))
      end
    else
      redirect_to articles_entity_path(@entity)
    end
  end

  def remove_article
    ae = ArticleEntity.find_by(entity_id: @entity.id, article_id: params[:article_id])
    ae.destroy
    redirect_to articles_entity_path(@entity)
  end

  def new_article
    @article = Article.new
  end

  def create_article
    @article = Article.new(article_params)
    @article.created_by_user_id = current_user.id
    @article.article_entities.build(entity_id: @entity.id, is_featured: true)

    if @article.save
      redirect_to articles_entity_path(@entity), notice: 'Article was successfully created.'
    else
      render action: 'new_article'
    end
  end

  ##
  # images
  #

  def images
    check_permission 'contributor'
  end

  def feature_image
    image = Image.find(params[:image_id])
    image.feature
    redirect_to images_entity_path(@entity)
  end

  def remove_image
    image = Image.find(params[:image_id])
    image.destroy
    redirect_to images_entity_path(@entity)
  end

  def new_image
    @image = Image.new
    @image.entity = @entity
  end

  def upload_image
    if uploaded = image_params[:file]
      filename = Image.random_filename(File.extname(uploaded.original_filename))
      src_path = Rails.root.join('tmp', filename).to_s
      File.open(src_path, 'wb') do |file|
        file.write(uploaded.read)
      end
    else
      src_path = image_params[:url]
    end

    @image = Image.new_from_url(src_path)
    if @image
      @image.entity = @entity
      @image.is_free = cast_to_boolean(image_params[:is_free])
      @image.title = image_params[:title]
      @image.caption = image_params[:caption]
    end

    if @image && @image.save
      @image.feature if cast_to_boolean(image_params[:is_featured])
      redirect_to images_entity_path(@entity), notice: 'Image was successfully created.'
    else
      @image = Image.new(url: src_path, title: image_params[:title], caption: image_params[:caption])
      render action: 'new_image', notice: 'Failed to add the image :('
    end
  end

  private

  def set_entity_for_profile_page
    set_entity(:profile_scope)
  end

  def set_entity_references
    @references = @entity.references.order('updated_at desc').limit(10)
  end

  def article_params
    params.require(:article).permit(
      :title, :url, :snippet, :published_at
    )
  end

  def image_params
    params.require(:image).permit(
      :file, :title, :caption, :url, :is_free, :is_featured
    )
  end

  def update_entity_params
    params.require(:entity).permit(
      :name, :blurb, :summary, :website, :start_date, :end_date, :is_current,
      person_attributes: [:name_first, :name_middle, :name_last, :name_prefix, :name_suffix, :name_nick, :birthplace, :gender_id, :id ],
      public_company_attributes: [:ticker, :id],
      school_attributes: [:is_private, :id]
    )
  end

  # output: [Int] or nil
  def extension_def_ids
    if params.require(:entity).key?(:extension_def_ids)
      return params.require(:entity).fetch(:extension_def_ids).split(',').map(&:to_i)
    end
  end

  def new_entity_params
    LsHash.new(params.require(:entity).permit(:name, :blurb, :primary_ext).to_h)
      .with_last_user(current_user)
      .nilify_blank_vals
  end

  def create_bulk_payload
    params.require('data')
      .map { |r| r.permit('attributes' => %w[name blurb primary_ext])['attributes'] }
  end

  def add_relationship_page?
    params[:add_relationship_page].present?
  end

  def importers_only
    check_permission 'importer'
  end

  def check_delete_permission
    unless current_user.permissions.entity_permissions(@entity).fetch(:deleteable)
      raise Exceptions::PermissionError
    end
  end
end
