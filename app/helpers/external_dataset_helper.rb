# frozen_string_literal: true

module ExternalDatasetHelper
  def external_dataset_iapd_subtitle(flow)
    dataset_name = flow.gsub('owners', 'executives')

    content_tag(:h2, class: 'mt-1') do 
      content_tag(:b, 'Dataset: ') + content_tag(:span, "IAPD #{dataset_name}")
    end
  end
end
