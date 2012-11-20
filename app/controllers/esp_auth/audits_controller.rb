class EspAuth::AuditsController < ApplicationController
  inherit_resources
  sso_authenticate_and_authorize

  before_filter :authorize_manage_audits!

  defaults :resource_class => Audited::Adapters::ActiveRecord::Audit

  has_scope :page, :default => 1

  layout 'esp_auth/application'

  protected

  def authorize_manage_audits!
    authorize!(:manage, :audits)
  end

  def end_of_association_chain
    apply_scopes(resource_class.unscoped.order('id desc')).per(20)
  end
end
