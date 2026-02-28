class AddCoverIllustrationIdToIllustrators < ActiveRecord::Migration[7.1]
  def change
    add_column :illustrators, :cover_illustration_id, :integer
  end
end
