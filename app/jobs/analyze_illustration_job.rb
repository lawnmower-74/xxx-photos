require "open3"

class AnalyzeIllustrationJob < ApplicationJob
  queue_as :analyze_illustrations

  Attempts = 5
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: Attempts

  def perform(illustration_id)
    @illustration = Illustration.find_by(id: illustration_id)
    return unless @illustration&.image&.attached?

    begin
      @illustration.image.open do |file|
        # 「撮影日時」抽出
        extract_exif(file)
        # 「類似判定用データ」生成
        generate_fingerprint(file)
      end
      
      @illustration.update_columns(
        shot_at: @illustration.shot_at, 
        fingerprint: @illustration.fingerprint
      )
      
      # BK-Treeに新しい画像の「類似判定用データ」を追加（再ビルドするのではなく）
      SimilarityApiService.insert_fingerprint(@illustration)
      
      # サムネ生成・保存
      GenerateThumbnailJob.perform_later(illustration_id)

    # デッドロック時
    rescue ActiveRecord::Deadlocked => e
      if executions >= Attempts
        Rails.logger.error "解析データ登録失敗 > #{@illustration.id}: \n#{e.message}"
      else
        Rails.logger.warn "[#{executions}/#{Attempts}] デッドロック発生 > #{@illustration.id}: \n#{e.message}"
      end
      raise

    rescue => e
      Rails.logger.error "解析データ登録失敗 > #{@illustration.id}: \n#{e.message}"
      raise
    end
  end

  private
  # =========================================================
  # EXIF情報から「撮影日時」抽出
  # =========================================================
  def extract_exif(file)
    output, stderr, status = Open3.capture3(
      'exiftool', '-s3', '-d', '%Y-%m-%d %H:%M:%S', '-DateTimeOriginal', file.path.to_s
    )

    if status.success?
      if output.present?
        # 取得データの整形
        times = output.split("\n").map(&:strip).reject(&:empty?)
        shot_date = Time.zone.parse(times.first) if times.any?

        # 値のセット
        @illustration.shot_at = shot_date if shot_date.present?

      else
        # そもそも設定されていない場合はリトライする必要がないためログに出力するのみ
        Rails.logger.warn "「撮影日時」が設定されていません > #{@illustration.id}"
      end

    else
      error_detail = stderr.presence || output.presence || "exit_status=#{status.exitstatus}"
      Rails.logger.error "「撮影日時」抽出失敗 > #{@illustration.id}: \n#{error_detail}"
    end
  end

  # =========================================================
  # 類似検索用「見た目の特徴値」生成
  # =========================================================
  def generate_fingerprint(file)
    begin
      # 画像の「明暗」をピクセルレベルで数値化
      raw_hash = DHashVips::IDHash.fingerprint(file.path.to_s)
      
      # 生成された 256bit を 4分割（画像を4分割してるイメージ）
      chunk1 = (raw_hash >> 192) & 0xFFFFFFFFFFFFFFFF # 画像の「左上」あたりの特徴（192~255bit）
      chunk2 = (raw_hash >> 128) & 0xFFFFFFFFFFFFFFFF # 画像の「右上」あたりの特徴（128~191bit）
      chunk3 = (raw_hash >> 64)  & 0xFFFFFFFFFFFFFFFF # 画像の「左下」あたりの特徴（64~127bit）
      chunk4 = raw_hash          & 0xFFFFFFFFFFFFFFFF # 画像の「右下」あたりの特徴（0~63bit）
      
      # 4分割したものを重ねて1枚のフィルム化
      u64_hash = chunk1 ^ chunk2 ^ chunk3 ^ chunk4
      
      # 922京(境界線)を超えていたら、1844京(一桁上の全パターン数(10進数))を引いてマイナスにする
      final_hash = u64_hash >= (1 << 63) ? u64_hash - (1 << 64) : u64_hash

      # 値のセット
      @illustration.fingerprint = final_hash
      
    rescue => e
      Rails.logger.error "「類似判定用データ」生成失敗 > #{@illustration.id}: \n#{e.message}"
    end
  end
end