class Illustrator < ApplicationRecord
  # 1人の作者はたくさんのイラストを持つ
  has_many :illustrations, dependent: :destroy
  validates :name, presence: true, uniqueness: true
end