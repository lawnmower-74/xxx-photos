require 'net/http'
require 'uri'
require 'json'
require 'timeout'

# ==========================================
# Go APIとの通信を担当するサービスクラス
# ==========================================
class SimilarityApiService
  BASE_URL = "http://similarity_api:8080"

  # ==========================================
  # 類似画像のIDリストを取得
  # ==========================================
  def self.find_similar_ids(illustrator_id, threshold: 5)
    uri = URI.parse("#{BASE_URL}/similarities")

    # パラメータ追加（※しきい値はここで指定）
    uri.query = URI.encode_www_form(
      illustrator_id: illustrator_id,
      threshold: threshold
    )

    # タイムアウト設定（デフォルトだと長いので3秒に設定）
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 3
    http.read_timeout = 3

    request = Net::HTTP::Get.new(uri.request_uri)

    # あらかじめ作成していたBK-Treeをもとに類似判定をリクエスト（IDのリストが戻る）
    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data['similar_ids'] || []
    else
      Rails.logger.error "Go API エラー (similarities): #{response.code} #{response.message}"
      []
    end

  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
    Rails.logger.error "Go API タイムアウト (similarities): #{e.message}"
    []
  rescue => e
    Rails.logger.error "Go API への接続に失敗しました (similarities): #{e.message}"
    []
  end

  # ============================================================
  # BK-Treeの再構築をリクエスト（画像の追加・削除後に呼び出す）
  # ============================================================
  def self.rebuild
    uri = URI.parse("#{BASE_URL}/rebuild")
    
    # タイムアウト設定（デフォルトだと長いので3秒に設定）
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 3
    http.read_timeout = 3

    request = Net::HTTP::Post.new(uri.request_uri)
    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      true
    else
      Rails.logger.error "Go API エラー (rebuild): #{response.code} #{response.message}"
      false
    end

  rescue => e
    Rails.logger.error "Go API への接続に失敗しました (rebuild): #{e.message}"
    false
  end

  # ==========================================================
  # 単一画像の「類似判定用データ」をBK-Treeに追加
  # ==========================================================
  def self.insert_fingerprint(illustration)
    return if illustration.nil? || illustration.fingerprint.blank? || illustration.illustrator_id.blank?

    uri = URI.parse("#{BASE_URL}/insert_fingerprint")

    # タイムアウト設定（デフォルトだと長いので3秒に設定）
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 3
    http.read_timeout = 3

    request = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
    request.body = {
      id: illustration.id,
      illustrator_id: illustration.illustrator_id,
      fingerprint: illustration.fingerprint
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Go API エラー (insert_fingerprint): #{response.code} #{response.message}"
    end
    
  rescue => e
    Rails.logger.error "Go API への接続に失敗しました (insert_fingerprint): #{e.message}"
  end
end
