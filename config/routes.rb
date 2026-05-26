Rails.application.routes.draw do
  root "web/markets#index"

  get "/signin", to: "web/sessions#new"
  post "/signin", to: "web/sessions#create"
  delete "/signout", to: "web/sessions#destroy"

  namespace :web do
    resources :markets, only: [:index, :show]

    resources :betslips, only: [] do
      collection do
        post :quotes
        post :execute
      end
    end
    resources :betslip_executions, only: [:show], path: "betslips/executions"

    resources :positions, only: [:index] do
      collection do
        post :cashout_quotes
        post :cashout_execute
      end
    end
  end

  namespace :backoffice do
    root to: "dashboard#index"
    resources :permissions, only: [:index, :update]
    resources :grants, only: [:index, :create]
    resources :templates, only: [:index, :create, :edit, :update, :destroy] do
      post :create_market, on: :member
    end
    resources :markets, only: [:index, :show, :create] do
      post :open, on: :member
      post :settle, on: :member
    end
    resources :faucet_requests, only: [:index] do
      post :approve, on: :member
      post :reject,  on: :member
    end
  end

  namespace :sse do
    resources :markets, only: [] do
      get :show, on: :member
    end
    resources :settlements, only: [] do
      get :show, on: :member
    end
  end

  namespace :auth do
    post :register, to: "sessions#register"
    post :login, to: "sessions#login"
    get :me, to: "sessions#me"
  end

  resources :markets, only: [:index, :show]
  resources :markets, only: [] do
    resources :bets, only: [:create]
  end
  resources :faucet_requests, only: [:create]
  resource :wallet, only: [:show]

  namespace :admin do
    resources :bets, only: [] do
      post :void, on: :member
    end

    resources :markets, only: [:create, :update] do
      post :settle, on: :member
      get :risk, on: :member
      resources :legs, only: [:create], controller: "market_legs"
    end

    resources :faucet_requests, only: [:index] do
      post :approve, on: :member
      post :reject, on: :member
    end
  end
end
