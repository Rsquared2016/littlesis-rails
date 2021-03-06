# frozen_string_literal: true

class UserMapsPresenter
  NETWORK_MAP_FIELDS = [
    'network_map_link(id, title)',
    "DATE_FORMAT(updated_at, '%Y-%m-%d')"
  ].map { |x| Arel.sql(x) }.freeze

  def initialize(user)
    TypeCheck.check user, User
    @user = user
  end

  def render
    JSON.dump(network_maps)
  end

  private

  def network_maps
    @user.network_maps.order(updated_at: :desc).all.pluck(*NETWORK_MAP_FIELDS)
  end
end

