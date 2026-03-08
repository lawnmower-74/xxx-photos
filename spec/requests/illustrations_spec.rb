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

  # ==========================================================================================
  # アップロードのテスト（create）
  # ==========================================================================================
  describe "POST /illustrations" do
    # ------------------------------------------------
    # リクエスト（テスト）用データの作成
    # ------------------------------------------------
    let(:illustrator_name) { "TestArtist" }
    let(:image_file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/test.png'), 
        'image/png'
      )
    end
    let(:params) do
      { illustration: { illustrator_name: illustrator_name, image: image_file } }
    end
  
    context "アップロード処理をテスト・同時にデッドロック発生時の挙動も確認" do

      it "デッドロック発生しつつもアップロードは成功するケース" do
        # -----------------------------------------------------------------------------------
        # デッドロック発生時の retry 機構が働くのかをテスト（rescue ActiveRecord::Deadlocked）
        # -----------------------------------------------------------------------------------
        call_count = 0
        # find_or_create_by! が実行されたときに代わりに以下が実行される
        allow(Illustrator).to receive(:find_or_create_by!).and_wrap_original do |method, *args|
          call_count += 1
          if call_count <= 2
            # わざとデッドロックを発生させる
            raise ActiveRecord::Deadlocked.new("デッドロック発生")
          else
            method.call(*args) # 3回目は本物のメソッドを呼ぶ
          end
        end
  
        # アップロードリクエスト
        post illustrations_path, params: params
  
        # ----------------------------------------------------------------------
        # 成功ステータス（アップロード成功）が返っているかを確認
        # ----------------------------------------------------------------------
        expect(response).to have_http_status(:created)
        
        # ----------------------------------------------------------------------
        # デッドロックによるリトライが2回行われた（合計3回呼ばれた）ことを確認
        # ----------------------------------------------------------------------
        expect(call_count).to eq(3)
        
        # ----------------------------------------------------------------------
        # DBに保存されていることを確認
        # ----------------------------------------------------------------------
        illustrator = Illustrator.find_by(name: illustrator_name)
        expect(illustrator.illustrations).to be_present
      end
  
      it "デッドロックによりアップロードが失敗するケース" do
        # find_or_create_by! が実行されたときに代わりに以下が実行される（ずっとデッドロックを返す）
        allow(Illustrator).to receive(:find_or_create_by!).and_raise(ActiveRecord::Deadlocked)

        initial_count = Illustration.count
  
        # ----------------------------------------------------------------------
        # 4回目の後にエラーが返されることを確認
        # ----------------------------------------------------------------------
        expect {
          post illustrations_path, params: params
        }.to raise_error(ActiveRecord::Deadlocked)

        # ----------------------------------------------------------------------
        # DBに保存されていないことを確認
        # ----------------------------------------------------------------------
        expect(Illustration.count).to eq(initial_count)

      end
    end
  end
end