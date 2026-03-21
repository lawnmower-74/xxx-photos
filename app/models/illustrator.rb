class Illustrator < ApplicationRecord
  # 1つのフォルダ（イラストレーター）は複数の画像を保持する
  has_many :illustrations, dependent: :destroy

  # 特定の1枚を「カバー画像」として指名するリレーション
  belongs_to :cover_illustration, class_name: "Illustration", optional: true

  # 最新画像だけを取得するためのリレーション（全件ロードによるメモリ圧迫を回避）
  has_one :latest_illustration, -> { order(created_at: :desc) }, class_name: 'Illustration'

  validates :name, presence: true, uniqueness: true


  # =====================================================
  # イラストレーター（フォルダ）検索／なければ新規作成
  # =====================================================
  def self.find_or_create_illustrator_safely!(name)
    Illustrator.find_or_create_by!(name: name)
  
  # ※作成のタイミングがかち合って422エラー発生することへの対策
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    Illustrator.find_by!(name: name)
  end
end