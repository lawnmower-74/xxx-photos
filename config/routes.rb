Rails.application.routes.draw do
  # イラストレーター（フォルダ）ごとの表示用ルート
  get 'illustrations/folder/:name', to: 'illustrations#show_by_illustrator', as: :illustrator_folder

  # 基本のリソース（index, create, show, destroyなど）
  resources :illustrations

  # アプリのトップページを「フォルダ一覧（index）」に設定
  root "illustrations#index"

  # デフォルト設定
  get "up" => "rails/health#show", as: :rails_health_check
end