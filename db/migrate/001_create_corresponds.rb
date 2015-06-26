class CreateCorresponds < ActiveRecord::Migration
  def change
    create_table :corresponds do |t|
      t.integer :id_local
      t.integer :id_remote
      t.integer :remote_type
      
    end
  end
end
