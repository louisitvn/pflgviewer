class CreateDbSchema < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string :number
      t.string :sender
      t.string :sender_domain
      t.string :recipient
      t.string :recipient_domain
      t.string :status
      t.integer :size
      t.datetime :datetime

      t.timestamps
    end
  end
end
