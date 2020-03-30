# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: APP_CONFIG['default_from_email']
  layout 'mailer'
end
