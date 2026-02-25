class Illustrator < ApplicationRecord
  # 1つのフォルダ（イラストレーター）は複数の画像を保持する
  has_many :illustrations, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end