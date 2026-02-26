Rails.application.routes.draw do

  # トップページ：フォルダ一覧
  root "illustrations#index"

  # ===================================
  # ファルダ一覧　関連
  # ===================================
  delete '/folders/:name', to: 'illustrators#destroy', as: :delete_illustrator_folder


  # ===================================
  # フォルダ内　関連
  # ===================================
  # 画像一覧表示
  get 'illustrations/folder/:name', to: 'illustrations#show_by_illustrator', as: :illustrator_folder

  resources :illustrations do
    collection do
      # 画像の選択削除
      delete :bulk_destroy
    end
  end

  # デフォルト設定
  get "up" => "rails/health#show", as: :rails_health_check
end