require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # サムネ生成エンジンの指定
    config.active_storage.variant_processor = :vips

    # Active Storage の 各Job に 専用キュー をラベリング
    config.active_storage.queues.analysis = :active_storage_analysis  # 画像アップロード時に実行されるJob
    config.active_storage.queues.purge    = :active_storage_purge     # 画像削除時に実行されるJob

    # Active Job の実行は Sidekiq が担当
    config.active_job.queue_adapter = :sidekiq
  end
end
