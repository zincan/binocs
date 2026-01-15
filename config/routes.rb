# frozen_string_literal: true

Binocs::Engine.routes.draw do
  root to: "requests#index"

  resources :requests, only: [:index, :show, :destroy] do
    collection do
      delete :clear
    end
  end
end
