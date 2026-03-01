class Illustrator < ApplicationRecord
  # 1つのフォルダ（イラストレーター）は複数の画像を保持する
  has_many :illustrations, dependent: :destroy

  # 特定の1枚を「カバー画像」として指名するリレーション
  belongs_to :cover_illustration, class_name: "Illustration", optional: true

  # 最新画像だけを取得するためのリレーション（全件ロードによるメモリ圧迫を回避）
  has_one :latest_illustration, -> { order(created_at: :desc) }, class_name: 'Illustration'

  validates :name, presence: true, uniqueness: true
end