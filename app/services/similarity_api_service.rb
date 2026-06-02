require 'net/http'
require 'uri'
require 'json'

# ==========================================
# Go APIとの通信を担当するサービスクラス
# ==========================================
class SimilarityApiService
  BASE_URL = "http://similarity_api:8080"

  # ==========================================
  # 類似画像のIDリストを取得
  # ==========================================
  def self.find_similar_ids(illustrator_id, threshold: 5)
    uri = URI.parse("#{BASE_URL}/similarities?illustrator_id=#{illustrator_id}&threshold=#{threshold}")
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data['similar_ids'] || []
    else
      Rails.logger.error "Go API エラー (similarities): #{response.code} #{response.message}"
      []
    end
  rescue => e
    Rails.logger.error "Go API への接続に失敗しました (similarities): #{e.message}"
    []
  end

  # ==========================================
  # BK-Treeの再構築をリクエスト
  # 画像の追加・削除後に呼び出す
  # ==========================================
  def self.rebuild
    uri = URI.parse("#{BASE_URL}/rebuild")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Go API エラー (rebuild): #{response.code} #{response.message}"
    end
  rescue => e
    Rails.logger.error "Go API への接続に失敗しました (rebuild): #{e.message}"
  end

  # ==========================================================
  # 単一画像の「類似判定用データ」をBK-Treeに追加
  # ==========================================================
  def self.insert_fingerprint(illustration)
    return if illustration.nil? || illustration.fingerprint.blank? || illustration.illustrator_id.blank?

    uri = URI.parse("#{BASE_URL}/insert_fingerprint")
    http = Net::HTTP.new(uri.host, uri.port)
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
