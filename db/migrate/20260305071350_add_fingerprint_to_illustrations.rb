class AddFingerprintToIllustrations < ActiveRecord::Migration[7.1]
  def change
    add_column :illustrations, :fingerprint, :bigint

    add_index :illustrations, :fingerprint
  end
end
