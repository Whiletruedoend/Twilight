# frozen_string_literal: true

Rails.application.routes.draw do
  captcha_route
  devise_for :user, path: '', controllers: { sessions: 'users/sessions', registrations: 'users/registrations' }

  get 'posts/import', to: 'posts#import', as: :import_post
  post 'posts/import', to: 'posts#import'
  resources :posts, except: [:destroy], param: :uuid

  resources :users, except: [:edit]
  post '/edit', to: 'users#edit', as: :edit_user

  # delete '/sign_out', to: 'user_sessions#destroy', as: :sign_out
  # get '/sign_in', to: 'user_sessions#new', as: :sign_in

  get '/settings', to: 'pages#settings', as: :settings

  get '/sign_up', to: 'users#new', as: :sign_up
  get '/sign_in', to: 'sessions#new', as: :sign_in
  get '/feed', to: 'posts#feed', as: :feed
  get '/rss', to: 'posts#rss', as: :rss, format: 'rss'

  post '/posts/new', to: 'posts#new'
  get 'posts/delete/:uuid', to: 'posts#destroy', as: :post_path
  get 'posts/export/:uuid', to: 'posts#export', as: :export_post_path
  get 'posts/raw/:uuid', to: 'posts#raw', as: :raw_post_path

  resources :channels, except: %i[index show destroy]
  get 'channels/delete/:id', to: 'channels#destroy', as: :channel_path

  put '/comments', to: 'comments#create', as: :create_comments_path
  resources :comments, only: %i[create edit update]
  post '/comments/new/(:parent_id)', to: 'comments#new', as: :new_comment
  get 'comments/delete/:id', to: 'comments#destroy', as: :comment_path

  resources :invite_codes, only: [:create]
  resources :tags, only: %i[create update]
  resources :categories, only: %i[create update]
  
  #resources :notifications, only: [ :index ]
  put '/notifications/view/:id', to: 'notifications#view', as: :view_notification

  get '/stats/full_users_list', to: 'pages#full_users_list', as: :full_users_list
  get '/manage/full_invite_codes_list', to: 'pages#full_invite_codes_list', as: :full_invite_codes_list

  case Rails.configuration.credentials[:root_page]
    when 1
      root to: 'posts#index'
    when 2
      root to: 'posts#feed'
    else
      root to: 'pages#main'
  end

  # telegram_webhook TelegramController
  # root 'index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
