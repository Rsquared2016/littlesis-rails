class PagesConstraint
  def initialize
    @pages = YAML
             .load_file(Rails.root.join('config', 'pages.yml'))
             .map { |page| "/#{page}" }
  end

  def matches?(request)
    @pages.include?(request.fullpath)
  end
end
