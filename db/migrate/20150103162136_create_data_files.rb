class CreateDataFiles < ActiveRecord::Migration
  def change
    create_table :data_files do |t|
      t.string :name
      t.string :path
      t.text :description
      t.string :status

      t.timestamps
    end
  end
end
