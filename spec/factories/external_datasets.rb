require Rails.root.join('spec', 'support', 'entity_spec_helpers.rb').to_s

FactoryBot.define do
  factory :external_dataset do
    name { 'iapd' }
    primary_ext { :person }
    row_data do
      { name:  EntitySpecHelpers::ATD_CHARACTERS.sample,
        title: Faker::Job.title }
    end
    dataset_key { Faker::Number.unique.number }
  end
end
