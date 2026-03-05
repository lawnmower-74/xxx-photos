class GenerateFingerprintJob < ApplicationJob
  queue_as :default

  # デッドロック対策（リトライ処理）
  retry_on ActiveRecord::Deadlocked, wait: 0.1.seconds, attempts: 3

  def perform(illustration_id)
    illustration = Illustration.find_by(id: illustration_id)
    return unless illustration && illustration.image.attached?

    begin
      illustration.image.open do |file|
        # 画像の「明暗」をピクセルレベルで数値化
        raw_hash = DHashVips::IDHash.fingerprint(file.path)
        
        # ※ハッシュの場合（数値でない場合）に備え
        raw_hash = raw_hash[:fingerprint] if raw_hash.is_a?(Hash)

        # 生成された 256bit を 4分割（画像を4分割してるイメージ）
        chunk1 = (raw_hash >> 192) & 0xFFFFFFFFFFFFFFFF # 画像の「左上」あたりの特徴（192~255bit）
        chunk2 = (raw_hash >> 128) & 0xFFFFFFFFFFFFFFFF # 画像の「右上」あたりの特徴（128~191bit）
        chunk3 = (raw_hash >> 64)  & 0xFFFFFFFFFFFFFFFF # 画像の「左下」あたりの特徴（64~127bit）
        chunk4 = raw_hash          & 0xFFFFFFFFFFFFFFFF # 画像の「右下」あたりの特徴（0~63bit）
        
        # 4分割したものを重ねて1枚のフィルム化
        u64_hash = chunk1 ^ chunk2 ^ chunk3 ^ chunk4
        
        # 922京(境界線)を超えていたら、1844京(一桁上の全パターン数(10進数))を引いてマイナスにする
        final_hash = u64_hash >= (1 << 63) ? u64_hash - (1 << 64) : u64_hash

        # 「見た目の特徴値」用カラム更新
        illustration.update_column(:fingerprint, final_hash)
      end
      
    rescue ActiveRecord::Deadlocked => e
      Rails.logger.warn "[GenerateFingerprintJob]-デッドロック検知。リトライします (ID: #{illustration_id}): #{e.message}"
      # デッドロック発生時には retry_on に報告しリトライを実行させる
      raise e
    rescue => e
      Rails.logger.error "画像の特徴値生成に失敗 (ID: #{illustration_id}): #{e.message}"
    end
  end
end