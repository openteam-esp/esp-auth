class Manage::ApplicationController < ApplicationController
  esp_load_and_authorize_resource
  skip_load_and_authorize_resource :only => :index

  def index
  end
end
