class Illustration < ApplicationRecord
  # 1つの画像は1つのフォルダ（イラストレーター）に属する
  belongs_to :illustrator

  # これによりactive_storage_attachmentsのrecord_idと紐づく
  has_one_attached :image

  validates :image, presence: true
  validates :illustrator_id, presence: true
end