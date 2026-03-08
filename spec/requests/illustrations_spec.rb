require 'rails_helper'

RSpec.describe "画像一覧に関するテスト", type: :request do
  # ==========================================================================================
  # 一覧表示のテスト（show_by_illustrator・calculate_similar_illustrations）
  # ==========================================================================================
  describe "GET illustrations/folder/:name" do
    # ------------------------------------------------
    # テスト用データの作成（DBに登録）
    # ------------------------------------------------
    # イラストレーター
    let!(:illustrator) { Illustrator.create!(name: "TestArtist") }

    # 画像
    ## 類似の2枚
    let!(:img_similar_a) { 
      illustrator.illustrations.create!(fingerprint: "0", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) 
    }
    let!(:img_similar_b) { 
      illustrator.illustrations.create!(fingerprint: "1", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) 
    }
    ## 類似していない1枚
    let!(:img_different) { 
      illustrator.illustrations.create!(fingerprint: "9223372036854775807", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) 
    }

    it "画像の全件取得・類似画像の抽出をテスト" do
      # 画像一覧へアクセス
      get illustrator_folder_path(name: illustrator.name)
      
      # 正常にページを返せたかの確認
      expect(response).to have_http_status(:success)
      
      # --------------------------------------------------------------------------------------------
      # 画像の全件取得・一覧への表示が出来ているかを確認（show_by_illustrator）
      # --------------------------------------------------------------------------------------------
      expect(response.body).to include("id=\"item-#{img_similar_a.id}\"")
      expect(response.body).to include("id=\"item-#{img_similar_b.id}\"")
      expect(response.body).to include("id=\"item-#{img_different.id}\"")
      
      # --------------------------------------------------------------------------------------------
      # 類似画像の抽出・類似セクションへの表示が出来ているかを確認（calculate_similar_illustrations）
      # --------------------------------------------------------------------------------------------
      # 類似の2枚は抽出され、類似セクションに表示されているかを確認
      expect(response.body).to include("id=\"similar-item-#{img_similar_a.id}\"")
      expect(response.body).to include("id=\"similar-item-#{img_similar_b.id}\"")
      # 類似していない画像は類似セクションに表示されていないかを確認
      expect(response.body).not_to include("id=\"similar-item-#{img_different.id}\"")
    end
  end

  # ==========================================================================================
  # 一括削除のテスト（bulk_destroy・calculate_similar_illustrations）
  # ==========================================================================================
  describe "DELETE /illustrations/bulk_destroy" do
    # ------------------------------------------------
    # テスト用データの作成（DBに登録）
    # ------------------------------------------------
    # イラストレーター
    ## 画像が削除されるイラストレーター
    let!(:illustrator) { Illustrator.create!(name: "TestArtist") }
    ## 削除されないイラストレーター
    let!(:other_illustrator) { Illustrator.create!(name: "OtherArtist") }

    # 画像
    ## 削除する2枚（類似画像）
    let!(:img_to_delete_a) { illustrator.illustrations.create!(fingerprint: "0", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) }
    let!(:img_to_delete_b) { illustrator.illustrations.create!(fingerprint: "1", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) }
    ## 削除せずに残す1枚
    let!(:img_stay) { illustrator.illustrations.create!(fingerprint: "500", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) }
    ## 削除対象ではないイラストレーターの画像
    let!(:img_other) { other_illustrator.illustrations.create!(fingerprint: "0", image: fixture_file_upload('spec/fixtures/test.png', 'image/png')) }
  
    it "選択した画像の削除・それによる類似セクションの表示切替をテスト" do
      # 削除実行
      params = { 
        ids: [img_to_delete_a.id, img_to_delete_b.id], 
        illustrator_name: illustrator.name 
      }
      delete bulk_destroy_illustrations_path, params: params, as: :json

      json_response = JSON.parse(response.body)

      # -----------------------------------------------------------------------------------------------
      # 指定したものだけが消えているかDBを確認（bulk_destroy）
      # -----------------------------------------------------------------------------------------------
      expect(Illustration.exists?(img_to_delete_a.id)).to be_falsey
      expect(Illustration.exists?(img_to_delete_b.id)).to be_falsey
      # 選択していないものは無事か
      expect(Illustration.exists?(img_stay.id)).to be_truthy
      # 他イラストレーターのものは無事か
      expect(Illustration.exists?(img_other.id)).to be_truthy

      # -----------------------------------------------------------------------------------------------
      # 類似画像がなくなったため類似セクションは非表示になったかを確認（calculate_similar_illustrations）
      # -----------------------------------------------------------------------------------------------
      expect(json_response["html"]).not_to include("similar-section-wrapper")
    end
  end
end