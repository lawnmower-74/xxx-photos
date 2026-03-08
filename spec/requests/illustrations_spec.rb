require 'rails_helper'

# ===========================================
# 画像一覧：show_by_illustrator のテスト
# ===========================================
RSpec.describe "Illustrations", type: :request do
  describe "GET illustrations/folder/:name" do
    # イラストレーター（フォルダ）の作成
    let!(:illustrator) { Illustrator.create!(name: "TestArtist") }

    # -------------------------------
    # 紐づく画像の作成
    # -------------------------------
    # 類似している2枚（ハミング距離が threshold=5 以下になるように設定）
    let!(:img_similar_a) { 
      illustrator.illustrations.create!(fingerprint: "0", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) 
    }
    let!(:img_similar_b) { 
      illustrator.illustrations.create!(fingerprint: "1", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) 
    }
    
    # 類似していない1枚（9223372036854775807：01111111 11111111 ... (63個の1が並ぶ)）
    let!(:img_different) { 
      illustrator.illustrations.create!(fingerprint: "9223372036854775807", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) 
    }

    it "画像の全件取得・類似画像の抽出をテスト" do
      # 画像一覧へアクセス
      get illustrator_folder_path(name: illustrator.name)
      
      # 正常にページを返せたかの確認
      expect(response).to have_http_status(:success)
      
      # --------------------------------------
      # 画像の全件取得
      # --------------------------------------
      # すべての画像が画像一覧に表示されているかを確認
      expect(response.body).to include("id=\"item-#{img_similar_a.id}\"")
      expect(response.body).to include("id=\"item-#{img_similar_b.id}\"")
      expect(response.body).to include("id=\"item-#{img_different.id}\"")
      
      # --------------------------------------
      # 類似画像の抽出
      # --------------------------------------
      # 類似画像の2枚は類似セクションにも表示されているかを確認
      expect(response.body).to include("id=\"similar-item-#{img_similar_a.id}\"")
      expect(response.body).to include("id=\"similar-item-#{img_similar_b.id}\"")

      # 類似していない画像は類似セクションに表示されていないかを確認
      expect(response.body).not_to include("id=\"similar-item-#{img_different.id}\"")
    end
  end
end