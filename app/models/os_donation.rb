# frozen_string_literal: true

class OsDonation < ApplicationRecord
  has_paper_trail :on => [:update, :destroy] # don't track create events
  validates :fec_cycle_id, uniqueness: true

  has_one :os_match

  def create_fec_cycle_id
    if cycle.present? && fectransid.present?
      self.fec_cycle_id = "#{cycle}_#{fectransid}"
    end
  end

  def reference_name
    "FEC Filing #{microfilm}"
  end

  def reference_url
    if microfilm.nil?
      'http://www.fec.gov/finance/disclosure/advindsea.shtml'
    else
      "http://docquery.fec.gov/cgi-bin/fecimg/?#{microfilm}"
    end
  end

  alias reference_source reference_url


  def self.distinct_recipids
    execute_sql(
      "SELECT DISTINCT recipid FROM os_donations WHERE recipid LIKE 'N%'"
    ).map(&:first)
  end
end
