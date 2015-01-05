Rails.application.routes.draw do
  resources :data_files
  get 'data_files/:id/download' => 'data_files#download', as: :data_file_download

  get 'main/index'

  resources :messages

  resources :main do
    collection do 
      get 'index'
      get 'all'
      get 'all_export'
      get 'domains_export'
      get 'users_export'
      get 'details_export'
    end
  end

  get 'main/domains/:status' => 'main#domains', as: :domains_by_status # danh sách domain by status
  get 'main/users/:base64_domain' => 'main#users', as: :users_by_domain # danh sách user by domain
  get 'main/details/:base64_domain' => 'main#details', as: :details_by_domain

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'main#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
