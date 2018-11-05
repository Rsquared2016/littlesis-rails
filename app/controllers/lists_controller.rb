# frozen_string_literal: true

class ListsController < ApplicationController
  include TagableController

  ERRORS = ActiveSupport::HashWithIndifferentAccess.new(
    entity_associations_bad_format: {
      errors: [{ title: 'Could not add entities to list: improperly formatted request.' }]
    },
    entity_associations_invalid_reference: {
      errors: [{ title: 'Could not add entities to list: invalid reference.' }]
    }
  )

  SIGNED_IN_ACTIONS = %i[new create admin crop_images update_cache modifications tags].freeze
  EDITABLE_ACTIONS = %i[create update add_entity remove_entity update_entity create_entity_associations].freeze

  # The call to :authenticate_user! on the line below overrides the :authenticate_user! call
  # from TagableController and therefore including :tags in the list is required
  # Because of the potential for confusion, perhaps we should no longer use :authenticate_user!
  # in controller concerns? (ziggy 2017-08-31)
  before_action :authenticate_user!, only: SIGNED_IN_ACTIONS
  before_action :block_restricted_user_access, only: SIGNED_IN_ACTIONS
  before_action -> { current_user.raise_unless_can_edit! }, only: EDITABLE_ACTIONS

  before_action :set_list,
                only: [:show, :edit, :update, :destroy, :search_data, :admin, :crop_images, :members, :update_entity, :remove_entity, :clear_cache, :add_entity, :find_entity, :delete, :interlocks, :companies, :government, :other_orgs, :references, :giving, :funding, :modifications, :new_entity_associations, :create_entity_associations]

  # permissions
  before_action :set_permissions,
                only: [:members, :interlocks, :giving, :funding, :references, :edit, :update, :destroy, :add_entity, :remove_entity, :update_entity, :new_entity_associations, :create_entity_associations]
  before_action -> { check_access(:viewable) }, only: [:members, :interlocks, :giving, :funding, :references]
  before_action -> { check_access(:editable) }, only: [:add_entity, :remove_entity, :update_entity, :new_entity_associations, :create_entity_associations]
  before_action -> { check_access(:configurable) }, only: [:destroy, :edit, :update]

  before_action :set_page, only: [:modifications]

  def self.get_lists(page)
    List
      .select("ls_list.*, COUNT(DISTINCT(ls_list_entity.entity_id)) AS entity_count")
      .joins(:list_entities)
      .where(is_admin: false)
      .group("ls_list.id")
      .order("entity_count DESC")
      .page(page).per(20)
  end

  # GET /lists
  def index
    lists = self.class.get_lists(params[:page])

    if current_user.present?
      @lists = lists.where('ls_list.access <> ? OR ls_list.creator_user_id = ?',
                           Permissions::ACCESS_PRIVATE,
                           current_user.id)
    else
      @lists = lists.public_scope
    end

    if params[:q].present?
      is_admin = (current_user and current_user.has_legacy_permission('admin')) ? [0, 1] : 0
      list_ids = List.search(
        Riddle::Query.escape(params[:q]),
        with: { is_deleted: 0, is_admin: is_admin }
      ).map(&:id)
      @lists = @lists.where(id: list_ids).reorder('')
    end
  end

  # GET /lists/1
  def show
    redirect_to action: 'members'
  end

  # GET /lists/new
  def new
    @list = List.new
  end

  # GET /lists/1/edit
  def edit
  end

  # POST /lists
  def create
    @list = List.new(list_params)
    @list.creator_user_id = current_user.id
    @list.last_user_id = current_user.sf_guard_user_id

    @list.validate_reference(reference_params)

    if @list.valid?
      @list.save!
      @list.add_reference(reference_params)
      redirect_to @list, notice: 'List was successfully created.'
    else
      render action: 'new'
    end
  end

  # PATCH/PUT /lists/1
  def update
    if @list.update(list_params)
      @list.clear_cache(request.host)
      redirect_to members_list_path(@list), notice: 'List was successfully updated.'
    else
      render action: 'edit'
    end
  end

  # DELETE /lists/1
  # def destroy
  #   @list.destroy
  #   redirect_to lists_url, notice: 'List was successfully destroyed.'
  # end

  # GET /lists/:id/associations/entities
  def new_entity_associations; end

  # POST /lists/:id/associations/entities
  # only handles json
  def create_entity_associations

    payload = create_entity_associations_payload
    return render json: ERRORS[:entity_associations_bad_format], status: 400 unless payload

    reference = @list.add_entities(payload['entity_ids']).save_with_reference(payload['reference_attrs'])
    return render json: ERRORS[:entity_associations_invalid_reference], status: 400 unless reference

    render json: Api.as_api_json(@list.list_entities.to_a).merge('included' => Array.wrap(reference.api_data)),
           status: 200
  end

  def destroy
    #check_permission 'admin'

    @list.soft_delete
    redirect_to lists_path, notice: 'List was successfully destroyed.'
  end

  def admin
  end

  def crop_images
    check_permission 'importer'
    entity_ids = @list.entities.joins(:images).where(image: { is_featured: true }).group("entity.id").order("image.updated_at ASC").pluck(:id)
    set_entity_queue(:crop_images, entity_ids, @list.id)
    next_entity_id = next_entity_in_queue(:crop_images)
    image_id = Image.where(entity_id: next_entity_id, is_featured: true).first
    redirect_to crop_image_path(id: image_id)
  end

  def members
    @table = ListDatatable.new(@list)
    @table.generate_data
  end

  def clear_cache
    @list.clear_cache(request.host)
    render json: { status: 'success' }
  end

  def update_entity
    if data = params[:data]
      list_entity = ListEntity.find(data[:list_entity_id])
      list_entity.rank = data[:rank]
      if list_entity.list.custom_field_name.present?
        list_entity.custom_field = (data[:context].present? ? data[:context] : nil)
      end
      list_entity.save
      list_entity.list.clear_cache(request.host)
      table = ListDatatable.new(@list)
      render json: { row: table.list_entity_data(list_entity, data[:interlock_ids], data[:list_interlock_ids]) }
    else
      render json: {}, status: 404
    end
  end

  def remove_entity
    ListEntity.remove_from_list!(params[:list_entity_id].to_i, current_user: current_user)
    redirect_to members_list_path(@list)
  end

  def add_entity
    ListEntity.add_to_list!(list_id: @list.id,
                            entity_id: params[:entity_id],
                            current_user: current_user)
    redirect_to members_list_path(@list)
  end

  def interlocks
    interlocks_query
  end

  def companies
    @companies = interlocks_results(
      category_ids: [Relationship::POSITION_CATEGORY, Relationship::MEMBERSHIP_CATEGORY],
      order: 2,
      degree1_ext: 'Person',
      degree2_type: 'Business'
    )
  end

  def government
    @govt_bodies = interlocks_results(
      category_ids: [Relationship::POSITION_CATEGORY, Relationship::MEMBERSHIP_CATEGORY],
      order: 2,
      degree1_ext: 'Person',
      degree2_type: 'GovernmentBody'
    )
  end

  def other_orgs
    @others = interlocks_results(
      category_ids: [Relationship::POSITION_CATEGORY, Relationship::MEMBERSHIP_CATEGORY],
      order: 2,
      degree1_ext: 'Person',
      exclude_degree2_types: ['Business', 'GovernmentBody']
    )
  end

  def references
  end

  def giving
    @recipients = interlocks_results(
      category_ids: [Relationship::DONATION_CATEGORY],
      order: 2,
      degree1_ext: 'Person',
      sort: :amount
    )
  end

  def funding
    @donors = interlocks_results(
      category_ids: [Relationship::DONATION_CATEGORY],
      order: 1,
      degree1_ext: 'Person',
      sort: :amount
    )
  end

  def modifications
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_list
    @list = List.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def list_params
    params.require(:list).permit(:name, :description, :is_ranked, :is_admin, :is_featured, :is_private, :custom_field_name, :short_description, :access)
  end

  def reference_params
    params.require(:ref).permit(:url, :name)
  end

  def create_entity_associations_payload
    payload = params.require('data').map { |x| x.permit('type', 'id', { 'attributes' => ['url', 'name'] }) }
    {
      'entity_ids'      => payload.select { |x| x['type'] == 'entities' }.map { |x| x['id'] },
      'reference_attrs' => payload.select { |x| x['type'] == 'references' }.map { |x| x['attributes'] }.first
    }
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid
    nil
  end

  def interlocks_query
    # get people in the list
    entity_ids = @list.entities.people.map(&:id)

    # get entities related by position or membership
    select = "e.*, COUNT(DISTINCT r.entity1_id) num, GROUP_CONCAT(DISTINCT r.entity1_id) degree1_ids, GROUP_CONCAT(DISTINCT ed.name) types"
    from = "relationship r LEFT JOIN entity e ON (e.id = r.entity2_id) LEFT JOIN extension_record er ON (er.entity_id = e.id) LEFT JOIN extension_definition ed ON (ed.id = er.definition_id)"
    where = "r.entity1_id IN (#{entity_ids.join(',')}) AND r.category_id IN (#{Relationship::POSITION_CATEGORY}, #{Relationship::MEMBERSHIP_CATEGORY}) AND r.is_deleted = 0"
    sql = "SELECT #{select} FROM #{from} WHERE #{where} GROUP BY r.entity2_id ORDER BY num DESC"
    db = ApplicationRecord.connection
    orgs = db.select_all(sql).to_hash

    # filter entities by type
    @companies = orgs.select { |org| org['types'].split(',').include?('Business') }
    @govt_bodies = orgs.select { |org| org['types'].split(',').include?('GovernmentBody') }
    @others = orgs.select { |org| (org['types'].split(',') & ['Business', 'GovernmentBody']).empty? }
  end

  def interlocks_results(options)
    @page = params.fetch(:page, 1)
    num = params.fetch(:num, 20)
    results = @list     .interlocks(options).page(@page).per(num)
    count = @list.interlocks_count(options)
    Kaminari.paginate_array(results.to_a, total_count: count).page(@page).per(num)
  end

  def set_permissions
    @permissions = current_user ?
                     current_user.permissions.list_permissions(@list) :
                     Permissions.anon_list_permissions(@list)
  end

  def check_access(permission)
    raise Exceptions::PermissionError unless @permissions[permission]
  end

  def after_tags_redirect_url(list)
    edit_list_url(list)
  end

  def check_tagable_access(list)
    unless current_user.permissions.list_permissions(list)[:configurable]
      raise Exceptions::PermissionError
    end
  end
end
