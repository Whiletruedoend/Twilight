Rails.application.routes.draw do

  devise_for :user, path: ''

  resources :posts
  resources :users
  #delete '/sign_out', to: 'user_sessions#destroy', as: :sign_out
  #get '/sign_in', to: 'user_sessions#new', as: :sign_in

  get '/settings', to: 'pages#settings', as: :settings

  get '/sign_up', to: 'users#new', as: :sign_up

  # get '/new_article', to: 'posts#new', as: :new_article

  root to: 'pages#main'
  #root 'index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end