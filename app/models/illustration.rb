class Illustration < ApplicationRecord
  # 1つの画像は1つのフォルダ（イラストレーター）に属する
  belongs_to :illustrator

  # これによりactive_storage_attachmentsのrecord_idと紐づく
  has_one_attached :image

  # 画像削除時に実行
  before_destroy :clear_illustrator_cover_id

  validates :image, presence: true
  validates :illustrator_id, presence: true

  private
  # 「カバー画像」として指名されていた場合、設定を空（nil）に更新する
  def clear_illustrator_cover_id
    if illustrator.cover_illustration_id == self.id
      illustrator.update_column(:cover_illustration_id, nil)
    end
  end
end