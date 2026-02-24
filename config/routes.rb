Rails.application.routes.draw do
  # イラストレーター（フォルダ）ごとの表示用ルート
  get 'illustrations/folder/:name', to: 'illustrations#show_by_illustrator', as: :illustrator_folder

  resources :illustrations do
    collection do
      delete :bulk_destroy # /illustrations/bulk_destroy
    end
  end

  # アプリのトップページを「フォルダ一覧（index）」に設定
  root "illustrations#index"

  # デフォルト設定
  get "up" => "rails/health#show", as: :rails_health_check
end