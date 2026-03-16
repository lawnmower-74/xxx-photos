require 'rails_helper'

RSpec.describe "対象: illustrations_controller", type: :request do

  describe "アップロード: POST /illustrations" do
    # =====================================================================================================
    # テスト事項：
    # 複数枚の画像データをアップロード
    # 1. illustratorsテーブルに該当レコード保存されたか
    # 2. illustrationsテーブルに該当レコード保存されたか
    # 3. 非同期処理も実行され、該当カラムに値は登録されたか（illustrationsテーブル > shot_at・fingerprint）
    # 4. active storage関連のテーブルに該当データは保存されたか（attachments, blobs）
    # =====================================================================================================

    # 開始前にテスト対象のデータを一通り削除
    before(:all) do
      Illustration.delete_all
      Illustrator.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
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
      # アップロード件数
      upload_count = 10

      # ActiveJob(Exif抽出, Fingerprint生成)を即時実行
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
         .and change(ActiveStorage::Blob, :count).by(upload_count)
      end

      # --- 最終的な状態の検証 ---

      # 1. テストにより登録されたイラストレーター(フォルダ)数が 1 かどうかをテスト
      expect(Illustrator.where(name: illustrator_name).count).to eq 1
      
      # 2. そのイラストレーターに紐づく 画像数 が アップロード件数 と一致するかどうかをテスト
      illustrator = Illustrator.find_by(name: illustrator_name)
      expect(illustrator.illustrations.count).to eq upload_count

      # 3. 非同期処理（Job）の結果が反映されているか（画像のすべてに shot_at, fingerprint が存在するか）をテスト
      expect(illustrator.illustrations.all? { |i| i.shot_at.present? }).to be true
      expect(illustrator.illustrations.all? { |i| i.fingerprint.present? }).to be true

      # 4. 画像件数 と attachments件数、画像件数 と blobs件数 が一致するかをテスト
      attachments = ActiveStorage::Attachment.where(
        record_type: "Illustration",
        record_id:   illustrator.illustrations.ids
      )
      blob_ids = attachments.pluck(:blob_id)

      expect(attachments.count).to eq upload_count
      expect(ActiveStorage::Blob.where(id: blob_ids).count).to eq upload_count
    end
  end
end