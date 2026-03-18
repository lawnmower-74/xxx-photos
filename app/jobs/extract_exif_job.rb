require 'open3'

class ExtractExifJob < ApplicationJob
  queue_as :default

  # デッドロック対策（リトライ処理）
  retry_on ActiveRecord::Deadlocked, wait: 0.1.seconds, attempts: 3

  def perform(illustration_id)
    illustration = Illustration.find_by(id: illustration_id)
    return unless illustration && illustration.image.attached?

    begin
      illustration.image.open do |file|
        # EXIF情報から「撮影日時」抽出
        output, stderr, status = Open3.capture3(
          'exiftool', '-s3', '-d', '%Y-%m-%d %H:%M:%S', '-DateTimeOriginal', file.path.to_s
        )

        unless status.success?
          error_detail = stderr.presence || output.presence || "exit_status=#{status.exitstatus}"
          raise "「撮影日時」取得コマンド失敗: #{error_detail}"
        end

        # 「撮影日時」が空の場合は終了
        next if output.blank?
        
        # 取得データの整形
        times = output.split("\n").map(&:strip).reject(&:empty?)
        shot_date = Time.zone.parse(times.first) if times.any?

        # 「撮影日時」用カラムを更新
        illustration.update_column(:shot_at, shot_date) if shot_date.present?
      end
      
    rescue ActiveRecord::Deadlocked => e
      Rails.logger.warn "[ExtractExifJob]-デッドロック検知。リトライします (ID: #{illustration_id}): #{e.message}"
      raise e
    rescue => e
      Rails.logger.error "「撮影日時」取得失敗 (ID: #{illustration_id}): #{e.message}"
      raise e
    end
  end
end