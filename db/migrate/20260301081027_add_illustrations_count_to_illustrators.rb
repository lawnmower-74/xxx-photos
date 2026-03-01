class AddIllustrationsCountToIllustrators < ActiveRecord::Migration[7.1]
  def change
    add_column :illustrators, :illustrations_count, :integer, default: 0
  end
end