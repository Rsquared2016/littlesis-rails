module EntitiesHelper
  def entity_hash_link(entity, name=nil, action=nil)
    name ||= entity['name']
    link_to name, Entity.legacy_url(entity['primary_ext'], entity['id'], name, action)
  end

  def tiny_entity_image(entity)
    content_tag('div', nil, class: "entity_tiny_image", style: "background-image: url('#{image_path(entity.featured_image_url('small'))}');")
  end

  def legacy_user_path(user)
    '/user/' + user.username
  end

  def active_tab?(tab_name, active_tab)
    if active_tab == tab_name
      return 'active'
    else
      return 'inactive'
    end
  end

  # Relationships display

  def get_other_positions_and_memberships_heading(positions_count, other_positions_count, memberships_count)
    if other_positions_count == 0
      return 'Memberships'
    elsif memberships_count == 0
      if other_positions_count == positions_count
        return 'Positions'
      else
        return 'Other Positions'
      end
    elsif other_positions_count == positions_count
      return 'Positions & Memberships'
    else
      return 'Other Positions & Memberships'
    end
  end

  def section_heading(links)
    content_tag(:div, links.heading, class: "subsection") if links.count > 0
  end

  def link_to_all(links)
    content_tag :div, class: 'section_meta' do 
      content_tag(:span, "Showing 1-10 of #{links.count} :: ") + link_to('see all', entity_url(:relationships => links.keyword))
    end if links.count > 10
  end

  def section_order(entity)
    section_order_person = [
      'business_positions',
      'government_positions',
      'in_the_office_positions',
      'other_positions_and_memberships',
      'schools',
      'holdings',
      'services_transactions',
      'family',
      'professional_relationships',
      'friendships',
      'donors',
      'donation_recipients',
      'staff',
      'political_fundraising_committees',
      'miscellaneous'
    ]
    section_order_org = [
      'parents',
      'children',
      'other_positions_and_memberships',
      'staff'
    ]

    entity.person? ? section_order_person : section_order_org
  end

  def extra_links_count(links)
    return '' if links.count <= 1
    "[+#{links.count - 1}]"
  end

  # <Entity> -> html
  def type_select_boxes(entity = @entity)
    number_per_group = entity.org? ? 9 : 5
    checkboxes(entity).each_slice(number_per_group).reduce('') do |x, box_group|
      x + content_tag(:div, box_group.reduce(:+), class: 'col-sm-4')
    end.html_safe
  end

  # <Entity> -> [ content_tag ]
  def checkboxes(entity)
    checked_def_ids = entity.extension_records.map(&:definition_id)
    ExtensionDefinition.send("#{entity.primary_ext.downcase}_types").collect do |ed|
      is_checked = checked_def_ids.include?(ed.id)
      content_tag(:span, class: 'entity-type-checkbox-wrapper') do 
        glyph_checkbox(is_checked, ed.id) + content_tag(:span, " #{ed.display_name}", class: 'entity-type-name') + tag(:br)
      end
    end
  end

  # boolean, [] -> content_tag
  def glyph_checkbox(checked, def_id)
    glyphicon_class = ['glyphicon']
    glyphicon_class.append(if checked then 'glyphicon-check' else 'glyphicon-unchecked' end)
    content_tag(:span, nil, class: glyphicon_class, aria_hidden: 'true', data: { definition_id: def_id })
  end

  # <FormBuilder Thingy> -> [options for select]
  def gender_select_options(person_form)
    person = person_form.instance_variable_get("@object")
    selected = person.gender_id.nil? ? 'nil' : person.gender_id
    options_for_select([['', ''], ['Female', 1], ['Male', 2], ['Other', 3]], selected)
  end

  def profile_image
    image_tag(@entity.featured_image_url, alt: @entity.name, class: 'img-rounded')
  end

  def sidebar_title(title)
    content_tag(:div, class: 'sidebar-title-container thin-grey-bottom-border') do
      content_tag(:span, title, class: 'lead sidebar-title-text')
    end
  end

  def sidebar_reference_count(count)
    content_tag(:span, "Number of references: ") + content_tag(:em, count.to_s)
  end

  # input: Array or <ActiveRecord_relation>
  def sidebar_references(references)
    content_tag(:ul, class: 'list-unstyled') do
      references.collect { |r| sidebar_reference(r) }.reduce(&:+)
    end
  end

  def sidebar_reference(reference)
    link_to(
      content_tag(:li, reference.name.truncate(33)),
      reference.source,
      target: "_blank"
    )
  end

  def sidebar_basic_info(basic_info)
    basic_info.collect do |key, val|
      content_tag(:strong, "#{key}: ") + content_tag(:span, val) + tag(:br)
    end.reduce(:+)
  end

  # To eager load list and list_entities: Entity.includes(list_entities: [:lists])
  def sidebar_lists(list_entities)
    list_entities.collect do |list_entity|
      if show_list(list_entity)
        content_tag(:li, sidebar_list_link(list_entity), class: 'sidebar-list')
      else
        "".html_safe
      end
    end.reduce(:+)
  end

  def sidebar_list_link(list_entity)
    link = link_to list_entity.list.name , list_path(list_entity.list), class: 'link-blue'
    link += content_tag(:samp, "[\##{list_entity.rank}]") if list_entity.list.is_ranked? && list_entity.rank.present?
    link
  end

  def sidebar_similar_entities(similar_entities)
    similar_entities
      .collect { |e| link_to(e.name, e.legacy_url) }
      .collect { |link| content_tag(:li, link) }
      .reduce(&:+)
  end

  private

  # skip deleted lists, private lists (unless current_user has access), and skip lists that are networks
  def show_list(list_entity)
    list = list_entity.list
    return false if list.nil? || list.is_network?
    list.user_can_access?(current_user)
  end
end
