class CreateTables < ActiveRecord::Migration[5.0]
  def change
    create_table :projects do |t|
      t.string :name
      t.integer :user_id
      t.float :progress
      t.string :visibility, default: "public"
      t.timestamps null: false
    end
    create_table :phases do |t|
      t.string :name
      t.integer :project_id
      t.date :deadline
    end
    create_table :tasks do |t|
      t.string :name
      t.string :memo
      t.integer :progress
      t.integer :project_id
      t.integer :phase_id
    end
    create_table :users do |t|
      t.string :mail
      t.string :name
      t.string :password_digest
      t.string :line_id
      t.timestamps null: false
    end
    create_table :user_days do |t|
      t.integer :user_id
      t.integer :day_id
      # 0 -> Sunday
      # 1 -> Monday
      # 2 -> Tuesday
      # 3 -> Wednesday
      # 4 -> Thursday
      # 5 -> Friday
      # 6 -> Saturday
    end
    create_table :user_times do |t|
      t.integer :user_id
      t.integer :time_id
      # 0 -> 06~08
      # 1 -> 08~10
      # 2 -> 10~12
      # 3 -> 12~14
      # 4 -> 14~16
      # 5 -> 16~18
      # 6 -> 18~20
      # 7 -> 20~22
      # 8 -> 22~24
    end
    create_table :groups do |t|
      t.string :name
      t.string :description
    end
    create_table :user_groups do |t|
      t.integer :user_id
      t.integer :group_id
    end
    create_table :user_activities do |t|
      t.integer :user_id
      t.integer :project_id
      t.integer :phase_id
      t.integer :task_id
      t.string :activity
      t.timestamps null: false
    end
    create_table :nonces do |t|
      t.string :nonces
      t.integer :user_id
      t.timestamps null: false
    end
  end
end
