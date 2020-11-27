Rails.application.routes.draw do
  captcha_route
  devise_for :user, path: '', controllers: {sessions: 'users/sessions', registrations:'users/registrations'}

  resources :posts
  resources :users
  #delete '/sign_out', to: 'user_sessions#destroy', as: :sign_out
  #get '/sign_in', to: 'user_sessions#new', as: :sign_in

  get '/settings', to: 'pages#settings', as: :settings

  get '/sign_up', to: 'users#new', as: :sign_up
  get '/sign_in', to: 'sessions#new', as: :sign_in
  get '/rss', to: 'posts#rss', format: 'rss'

  post '/posts/new', to: 'posts#new'

  root to: 'pages#main'
  #root 'index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end