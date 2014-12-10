class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string :number
      t.string :sender
      t.string :domain
      t.integer :size

      t.timestamps
    end
  end
end
