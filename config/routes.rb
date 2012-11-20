EspAuth::Engine.routes.draw do
  resources :permissions, :only => [:new, :create, :destroy]

  resources :users, :only => :index do
    resources :permissions, :only => [:new, :create]
  end

  resources :audits, :only => :index

  match '/users/search' => "users#search"

  root :to => 'users#index'
end

Rails.application.routes.draw do
  mount EspAuth::Engine => '/esp-auth'
end rescue NameError

