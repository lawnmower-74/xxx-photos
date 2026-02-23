class Illustration < ApplicationRecord
  # 1つのイラストは1人の作者に属する
  belongs_to :illustrator
  has_one_attached :image
end