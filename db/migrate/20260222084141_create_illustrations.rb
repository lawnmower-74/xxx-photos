class CreateIllustrations < ActiveRecord::Migration[7.1]
  def change
    create_table :illustrations do |t|
      t.string :illustrator_name
      t.datetime :shot_at

      t.timestamps
    end
  end
end
