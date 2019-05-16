require Rails.root.join('lib', 'bulk_tagger.rb')

namespace :tags do
  desc 'bulk tag a csv of entities'
  task :entity, [:file] => :environment do |t, args|
    BulkTagger.new(args[:file], :entity).run
  end

  desc 'bulk tag a csv of lists'
  task :list, [:file] => :environment do |t, args|
    BulkTagger.new(args[:file], :list).run
  end
end
