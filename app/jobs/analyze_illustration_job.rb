require "open3"

class AnalyzeIllustrationJob < ApplicationJob
  queue_as :default

  # リトライ対象の絞り込み
  class ProcessingError < StandardError; end

  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 5
  retry_on ProcessingError, wait: 5.seconds, attempts: 5


  def perform(illustration_id)
    @illustration = Illustration.find_by(id: illustration_id)
    return unless @illustration&.image&.attached?

    begin
      @illustration.image.open do |file|
        # 「撮影日時」抽出
        extract_exif(file)
        # 類似検索用指紋 生成
        generate_fingerprint(file)
      end
      
      # 上記保存（shot_at, fingerprint）
      @illustration.save!

      # サムネ生成・保存
      generate_thumbnail

     
      # 測定のため臨時追加 ================================================================================================
      done_exif = Illustration.where.not(shot_at: nil).count
      done_fingerprint = Illustration.where.not(fingerprint: nil).count
      total_illustrations = Illustration.count
      done_thumbnails = ActiveStorage::VariantRecord.count

      if done_exif == total_illustrations && done_fingerprint == total_illustrations && done_thumbnails == total_illustrations
        total_latency = Time.current - @illustration.created_at

        Rails.logger.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        Rails.logger.info "【全バッチ完了】"
        Rails.logger.info "完了数: #{total_illustrations} / #{total_illustrations} 枚"
        Rails.logger.info "最後の一枚がアップされてから全Jopが完了するまでのタイムログ : #{total_latency.round(2)} 秒"
        Rails.logger.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      end
      # =======================================================================================================================


    # デッドロック時
    rescue ActiveRecord::Deadlocked => e
      if executions >= 5
        Rails.logger.error "画像解析 失敗（原因: デッドロック） > #{@illustration.id}: \n#{e.message}"
      else
        Rails.logger.warn "[#{executions}/5] デッドロック発生 (ID: #{@illustration.id}): \n#{e.message}"
      end
      raise
      
    # 各処理失敗時
    rescue ProcessingError => e
      if executions >= 5
        Rails.logger.error "画像解析 失敗（原因: 非同期処理） > #{@illustration.id}: \n#{e.message}"
      else
        Rails.logger.warn "[#{executions}/5] 処理一時失敗 (ID: #{@illustration.id}): \n#{e.message}"
      end
      raise

    rescue => e
      Rails.logger.error "画像解析 失敗 > #{@illustration.id}: \n#{e.message}"
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
      # ※外部OSで実行したコマンドの失敗は rescue で拾えないため記述
      error_detail = stderr.presence || output.presence || "exit_status=#{status.exitstatus}"
      raise ProcessingError, "「撮影日時」抽出失敗: #{error_detail}"
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
      raise ProcessingError, "fingerprint生成失敗: #{e.message}"
    end
  end

  # =========================================================
  # サムネ生成・保存
  # =========================================================
  def generate_thumbnail
    @illustration.image.variant(resize_to_limit: [300, 300]).processed

    rescue => e
      raise ProcessingError, "サムネ生成失敗: #{e.message}"
  end
end