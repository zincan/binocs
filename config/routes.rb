# frozen_string_literal: true

Binocs::Engine.routes.draw do
  root to: "requests#index"

  resources :requests, only: [:index, :show, :destroy] do
    member do
      get :lifecycle
      get :raw
    end
    collection do
      delete :clear
      get :sequence
      get :heatmap
      get :analytics
    end
  end
end
