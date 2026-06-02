# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: 'users/sessions' }

  get 'up' => 'rails/health#show', as: :rails_health_check
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  root 'conversations#index'
  get 'dashboard' => 'conversations#index', as: :authenticated_root

  resources :conversations, only: %i[index show create destroy] do
    resources :messages, only: [:create]
  end

  resources :documents, only: %i[index show new create destroy]

  resources :certificate_requests, only: %i[index show new create]

  namespace :admin do
    root 'dashboard#show'
    resources :documents, only: %i[index show edit update destroy] do
      member do
        post :reingest
      end
    end
    resources :users, only: %i[index show new create edit update destroy]
    resources :certificate_requests, only: %i[index show update]
    resources :certificate_types,    only: %i[index new create edit update destroy]
  end
end
