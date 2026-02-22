class Illustration < ApplicationRecord
    # 1つのイラスト投稿に対して、複数の画像を紐付けられるようにする
    has_one_attached :image
  
    validates :illustrator_name, presence: true
    validates :image, presence: true
  end