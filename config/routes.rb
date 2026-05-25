Rails.application.routes.draw do
  namespace :auth do
    post :register, to: "sessions#register"
    post :login, to: "sessions#login"
    get :me, to: "sessions#me"
  end

  resources :markets, only: [:index, :show]
  resources :faucet_requests, only: [:create]
  resource :wallet, only: [:show]

  namespace :admin do
    resources :markets, only: [:create, :update] do
      post :settle, on: :member
      resources :legs, only: [:create], controller: "market_legs"
    end

    resources :faucet_requests, only: [:index] do
      post :approve, on: :member
      post :reject, on: :member
    end
  end
end
