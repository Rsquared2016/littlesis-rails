FactoryBot.define do
  factory :donation, class: Donation do
  end
end

FactoryBot.define do
  factory :position, class: Position do
    is_board { nil }
    is_executive { nil }
    is_employee { nil }
    compensation { nil }
    boss_id { nil }
    # relationship_id nil    
  end
end

FactoryBot.define do
  factory :education, class: Education do
  end
end

FactoryBot.define do
  factory :membership, class: Membership do
  end
end

FactoryBot.define do
  factory :ownership, class: Ownership do
  end
end

FactoryBot.define do
  factory :transaction, class: Transaction do
  end
end
