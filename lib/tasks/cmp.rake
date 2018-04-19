# frozen_string_literal: true

require Rails.root.join('lib', 'query.rb').to_s
require Rails.root.join('lib', 'cmp.rb').to_s

namespace :cmp do
  namespace :orgs do
    desc 'saves spreadsheet of org matches'
    task save_org_matches: :environment do
      file_path = Rails.root
                    .join('data', "cmp_orgs_matched_#{Time.current.strftime('%F')}.csv").to_s

      blank_match_values = {
        match1_name: nil, match1_id: nil, match1_values: nil,
        match2_name: nil, match2_id: nil, match2_values: nil
      }

      sheet = Cmp::Datsets.orgs.map do |cmp_org|
        attrs = cmp_org.attributes.merge(blank_match_values)

        EntityMatcher
          .find_matches_for_org(cmp_org.fetch(:cmpname))
          .first(2) # take first 2 matches
          .each.with_index do |match, idx|

          attrs["match#{idx + 1}_name".to_sym] = match.entity.name
          attrs["match#{idx + 1}_id".to_sym] = match.entity.id
          attrs["match#{idx + 1}_values".to_sym] = match.values.to_a.join('|')
        end
        attrs[:pre_selected] = Cmp::EntityMatch.matches.dig(cmp_org.cmpid.to_s, 'entity_id')
        attrs
      end
      Query.save_hash_array_to_csv file_path, sheet
      puts "Saved orgs to: #{file_path}"
    end

    desc 'import orgs excel sheet'
    task import: :environment do
      ThinkingSphinx::Callbacks.suspend!
      Cmp.import_orgs
      ThinkingSphinx::Callbacks.resume!
    end
  end

  namespace :people do
    desc 'imports all with matches. save potential matches to csv'
    task import: :environment do
      begin
        ThinkingSphinx::Callbacks.suspend!

        file_path = Rails.root.join('data', 'potential_cmp_matches.csv')
        error_file_path = Rails.root.join('data', 'cmp_import_errors.txt')
        stats = { exists: 0, preselected: 0, automatch: 0, potential: 0, new: 0, error: 0 }

        potential_matches = []
        error_cmp_ids = []

        Cmp::Datasets.people.to_a.map(&:second).each do |cmp_person|
          name = cmp_person.fetch('fullname')
          cmpid = cmp_person.fetch('cmpid')
          cmp_display = "#{name} (#{cmpid})"

          begin
            if CmpEntity.exists?(cmp_id: cmpid)

              ColorPrinter.print_brown "cmp entity already imported: #{cmpid}"
              stats[:exists] += 0

            elsif cmp_person.preselected_match

              ColorPrinter.print_blue "preselected match: #{cmp_display}"
              stats[:preselected] += 1
              cmp_person.import!

            elsif cmp_person.matches.automatchable?

              ColorPrinter.print_green "automatching: #{cmp_display}"
              stats[:automatch] += 1
              cmp_person.import!

            elsif cmp_person.matches.first&.tier_one?

              ColorPrinter.print_red "potential match -- #{cmp_display} -- saving to csv"
              stats[:potential] += 1
              attrs = cmp_person.attributes
              match = cmp_person.matches.first
              attrs[:match_name] = match.entity.name
              attrs[:match_id] = match.entity.id
              attrs[:match_values] = match.values.to_a.join('|')
              potential_matches << attrs

            else

              ColorPrinter.print_cyan "no match for #{cmp_display}. Creating a new entity"
              stats[:new] += 1
              cmp_person.import!

            end

            cmp_person.clear_matches
          rescue => e
            ColorPrinter.print_red "error while importing #{cmpid}"
            puts e
            stats[:error] += 1
            error_cmp_ids << { :cmpid => cmp_person.fetch('cmpid') }
          end
        end # end of each loop

      ensure
        Query.save_hash_array_to_csv file_path, potential_matches
        Query.save_hash_array_to_csv error_file_path, error_cmp_ids
        puts stats
        ThinkingSphinx::Callbacks.resume!
      end
    end

    desc 'saves spreadsheet of people matches'
    task :save_people_matches, [:take] => :environment do |_, args|
      if args[:take].present?
        file_path_root = "cmp_people_matched_#{Time.current.strftime('%F')}_limited.csv"
        take = args[:take].to_i
        puts "saving the first #{take} rows"
      else
        file_path_root = "cmp_people_matched_#{Time.current.strftime('%F')}.csv"
        puts "saving the all rows"
        take = Cmp::Datasets.people.to_a.length
      end

      file_path = Rails.root.join('data', file_path_root)

      blank_match_values = {
        match1_name: nil, match1_id: nil, match1_values: nil,
        match2_name: nil, match2_id: nil, match2_values: nil
      }

      write_limit = 1000
      write_queue = []

      Cmp::Datasets.people.to_a.take(take).map(&:second).each do |cmp_person|
        begin
          attrs = cmp_person.attributes.merge(blank_match_values)

          cmp_person.matches.first(2).each.with_index do |match, idx|
            attrs["match#{idx + 1}_name".to_sym] = match.entity.name
            attrs["match#{idx + 1}_id".to_sym] = match.entity.id
            attrs["match#{idx + 1}_values".to_sym] = match.values.to_a.join('|')
          end
          write_queue << attrs
        rescue => e
          puts '--------------------------------------------------------'
          puts "Error encontered with cmp person: #{cmp_person.cmpid}"
          puts e
          puts '--------------------------------------------------------'
        end

        if write_queue.length >= write_limit
          Query.save_hash_array_to_csv file_path, write_queue, mode: 'ab'
          write_queue.clear
        end
      end

      Query.save_hash_array_to_csv file_path, write_queue, mode: 'ab' unless write_queue.empty?
      puts "Saved people to: #{file_path}"
    end
  end

  namespace :relationships do
    desc 'import cmp relationships'
    task import: :environment do
      ThinkingSphinx::Callbacks.suspend!

      relationship_errors = []

      Cmp::Datasets.relationships.each do |relationship|
        begin
          if relationship.send(:skip_import?)
            ColorPrinter.print_blue "skipping #{relationship.affiliation_id}"
          else
            relationship.import!
            ColorPrinter.print_gray "imported #{relationship.affiliation_id}"
          end
        rescue => e
          ColorPrinter.print_red "error while importing #{relationship.affiliation_id}"
          puts e
          relationship_errors << { :affiliation_id => relationship.affiliation_id }
        end
      end

      unless relationship_errors.empty?
        file_path = Rails.root.join('data', 'cmp_relationship_errors.txt')
        Query.save_hash_array_to_csv file_path, relationship_errors
      end
      ThinkingSphinx::Callbacks.resume!
    end
  end
end
