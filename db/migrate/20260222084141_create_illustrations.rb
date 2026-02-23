class CreateIllustrations < ActiveRecord::Migration[7.1]
  def change
    create_table :illustrations do |t|
      t.references :illustrator, null: false, foreign_key: true
      t.datetime :shot_at

      t.timestamps
    end
  end
end
