Rails.application.routes.draw do

  # トップページ：フォルダ一覧
  root "illustrations#index"

  # ===================================
  # ファルダ一覧
  # ===================================
  # フォルダ削除
  delete 'folders/:name', 
       to: 'illustrators#destroy', 
       as: :delete_illustrator_folder, 
       constraints: { name: /[^\/]+/ }

  # ===================================
  # フォルダ内
  # ===================================
  # 画像一覧表示
  get 'illustrations/folder/:name', 
    to: 'illustrations#show_by_illustrator', 
    as: :illustrator_folder, 
    constraints: { name: /[^\/]+/ }

  # アルバムカバー更新
  patch '/folders/:name/set_cover', 
      to: 'illustrators#set_cover', 
      as: :set_cover_folder,
      constraints: { name: /[^\/]+/ }
  
  resources :illustrations do
    collection do
      # 画像の一括削除
      delete :bulk_destroy
    end
  end

  # デフォルト設定
  get "up" => "rails/health#show", as: :rails_health_check
end