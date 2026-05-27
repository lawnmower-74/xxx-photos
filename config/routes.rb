require 'sidekiq/web'

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
      # 非同期Job（撮影日時抽出・類似判定用データ生成）の完了チェック
      post :check_jobs_status
    end
  end

  # デフォルト設定
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq管理画面
  mount Sidekiq::Web => '/sidekiq'
end