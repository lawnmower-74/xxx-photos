Rails.application.routes.draw do
  # フォルダ内アクセス（画像一覧表示）
  get 'illustrations/folder/:name', to: 'illustrations#show_by_illustrator', as: :illustrator_folder

  resources :illustrations do
    collection do
      # 画像の選択削除
      delete :bulk_destroy
    end
  end

  # トップページ：フォルダ一覧
  root "illustrations#index"

  # デフォルト設定
  get "up" => "rails/health#show", as: :rails_health_check
end