class CreateDbSchema < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string :number
      t.string :sender
      t.string :domain
      t.integer :size

      t.timestamps
    end

    create_table :recipients do |t|
      t.string :number
      t.string :recipient
      t.string :domain
      t.string :status

      t.timestamps
    end
  end
end