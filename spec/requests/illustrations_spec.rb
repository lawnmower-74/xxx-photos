require 'rails_helper'

RSpec.describe "対象: illustrations_controller", type: :request do

  describe "アップロード: POST /illustrations" do
    # =====================================================================================================
    # テスト事項：
    #   複数枚の画像データをアップロード
    #     1. フォルダは登録されたか: illustrators
    #     2. 画像は登録されたか: illustrations
    #     3. 非同期処理も実行され、画像の付随情報も登録されたか: illustrations > shot_at・fingerprint
    #     4. 画像データそのものも登録されたか: attachments, blobs
    #     5. 画像のリサイズも実行され、サムネとして登録されたか: variant_records
    # =====================================================================================================

    # 開始前にテスト対象のデータを一通り削除
    before(:all) do
      ActiveStorage::VariantRecord.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Illustration.delete_all
      Illustrator.delete_all
    end

    # 非同期ジョブをその場で実行させる設定
    include ActiveJob::TestHelper

    # テスト用データ作成
    let(:illustrator_name) { "TestIllustrator" }
    def uploaded_image
      Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/test.png'), 
        'image/png'
      )
    end
  
    it "複数の画像をアップロード → 必要なデータがすべて登録されているかを確認" do
      # サムネ生成履歴をDB（variant_records）に残すための設定
      expect(ActiveStorage.track_variants).to be(true)

      # アップロード数
      upload_count = 10

      # ActiveJob(Exif抽出, Fingerprint生成, サムネ生成)を即時実行
      perform_enqueued_jobs do
        expect {
          upload_count.times do
            post illustrations_path, params: {
              illustration: {
                illustrator_name: illustrator_name,
                image: uploaded_image
              }
            }
            expect(response).to have_http_status(:created)
          end
        }.to change(Illustration, :count).by(upload_count)
         .and change(ActiveStorage::Blob, :count).by(upload_count * 2) # ※ オリジナル + サムネ のため2倍
      end

      # --- 最終的な状態の検証 ---

      # 1. テストによって登録されたイラストレーター(フォルダ)数が 1 かどうか、またその name がアップしたものと一致しているかをテスト
      expect(Illustrator.count).to eq 1
      illustrator = Illustrator.first
      expect(illustrator.name).to eq illustrator_name
      
      # 2. そのイラストレーターに紐づく 画像数 が アップロード数 と一致するかどうかをテスト
      illustrator = Illustrator.find_by(name: illustrator_name)
      expect(illustrator.illustrations.count).to eq upload_count

      # 3. 非同期処理（Job）の結果が反映されているか（画像のすべてに shot_at, fingerprint が存在するか）をテスト
      expect(illustrator.illustrations.all? { |i| i.shot_at.present? }).to be true
      expect(illustrator.illustrations.all? { |i| i.fingerprint.present? }).to be true

      # 4. アップロード数 と オリジナル画像数（attachments数、blobs数）が一致するかをテスト
      attachments = ActiveStorage::Attachment.where(
        record_type: "Illustration",
        record_id:   illustrator.illustrations.ids
      )
      blob_ids = attachments.pluck(:blob_id)

      expect(attachments.count).to eq upload_count
      expect(ActiveStorage::Blob.where(id: blob_ids).count).to eq upload_count

      # 5. アップロード数 と サムネイル数（variant_records数）が一致するかをテスト
      expect(ActiveStorage::VariantRecord.where(blob_id: blob_ids).count).to eq upload_count
    end
  end
end