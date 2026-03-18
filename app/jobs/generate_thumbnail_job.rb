class GenerateThumbnailJob < ApplicationJob
  queue_as :default

  # デッドロック対策（リトライ処理）
  retry_on ActiveRecord::Deadlocked, wait: 0.1.seconds, attempts: 3

  def perform(illustration_id)
    illustration = Illustration.find_by(id: illustration_id)
    return unless illustration && illustration.image.attached?

    begin
      # サムネ生成・保存
      illustration.image.variant(resize_to_limit: [300, 300]).processed

    rescue ActiveRecord::Deadlocked => e
      Rails.logger.warn "[GenerateThumbnailJob]-デッドロック検知。リトライします (ID: #{illustration_id}): #{e.message}"
      # デッドロック発生時には retry_on に報告しリトライを実行させる
      raise e
    rescue => e
      Rails.logger.error "サムネ生成に失敗 (ID: #{illustration_id}): #{e.message}"
    end
  end
end