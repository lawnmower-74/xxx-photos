class GenerateThumbnailJob < ApplicationJob
  queue_as :generate_thumbnails

  Attempts = 3
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: Attempts

  def perform(illustration_id)
    illustration = Illustration.find_by(id: illustration_id)
    return unless illustration&.image&.attached?

    begin
      # サムネ生成・保存
      illustration.image.variant(resize_to_limit: [300, 300]).processed

    # デッドロック時にのみリトライ
    rescue ActiveRecord::Deadlocked => e
      if executions >= Attempts
        Rails.logger.error "サムネ生成失敗 > #{illustration_id}: \n#{e.message}"
      else
        Rails.logger.warn "[#{executions}/#{Attempts}] デッドロック発生 > #{illustration_id}: \n#{e.message}"
      end
      raise

    rescue => e
      Rails.logger.error "サムネ生成失敗 > #{illustration_id}: \n#{e.message}"
      raise
    end
  end
end