class CreateIllustrators < ActiveRecord::Migration[7.1]
  def change
    create_table :illustrators do |t|
      t.string :name

      t.timestamps
    end
    add_index :illustrators, :name, unique: true
  end
end
