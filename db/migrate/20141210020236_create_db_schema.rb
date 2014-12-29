class CreateDbSchema < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string :number
      t.integer :size
      t.string :relay
      t.string :sender
      t.string :sender_domain
      t.string :recipient
      t.string :recipient_domain
      t.string :status
      t.text :status_message
      t.string :status_code
      t.datetime :datetime

      t.timestamps
    end
  end
end
