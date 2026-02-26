class ExtractExifJob < ApplicationJob
  queue_as :default

  def perform(illustration_id)
    @illustration = Illustration.find_by(id: illustration_id)
    return unless @illustration && @illustration.image.attached?

    begin
      @illustration.image.open do |file|
        # EXIF情報から「撮影日時」抽出
        output = `exiftool -s3 -d "%Y-%m-%d %H:%M:%S" -DateTimeOriginal "#{file.path}"`
        times = output.split("\n").map(&:strip).reject(&:empty?)
        
        if times.any?
          shot_date = Time.zone.parse(times.first)
          # 「撮影日時」用カラムを更新
          @illustration.update_column(:shot_at, shot_date)
        end
      end
    rescue => e
      Rails.logger.error "「撮影日時」取得失敗 (ID: #{illustration_id}): #{e.message}"
    end
  end
end