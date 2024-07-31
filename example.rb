schema do
  create_table :users do |t|
    t.string :name
  end

  create_table :posts do |t|
    t.integer :user_id
    t.string :title
  end

  add_index :posts, :user_id
end

seeds do
  users = create_list(User, count: 10) do
    { name: FFaker::Name.name }
  end
  
  create_list_for_each_record(Post, records: users, count: 100) do |user|
    { user_id: user.id, title: FFaker::CheesyLingo.title }
  end
end

models do
  class User < ActiveRecord::Base
    has_many :posts
  end

  class Post < ActiveRecord::Base
    belongs_to :user
  end
end

example "SQL query" do
  sql = <<-SQL
    SELECT selected_posts.* FROM users JOIN LATERAL (
      SELECT * FROM posts
      WHERE user_id = users.id
      ORDER BY id DESC LIMIT 3
    ) AS selected_posts ON TRUE
  SQL

  result = ActiveRecord::Base.connection.execute(sql)
  puts result.to_a.inspect
end

example "Lateral join with rails with a fixed n" do
  class Post < ActiveRecord::Base
    scope :last_n_per_user, -> {
      sql = <<-SQL
        JOIN LATERAL (
          SELECT * FROM posts
          WHERE user_id = users.id
          ORDER BY id DESC LIMIT 3
        ) AS selected_posts ON TRUE
      SQL

      selected_posts = User
        .select("selected_posts.*")
        .joins(sql)

      from(selected_posts, "posts")
    }
  end

  posts = Post.last_n_per_user.preload(:user)
  pp posts.group_by(&:user).map { |user, posts| [user.name, posts.map(&:id)] }
end

example "Lateral join with rails with a variable n" do
  class Post < ActiveRecord::Base
    scope :last_n_per_user, ->(n) {
      sql = <<-SQL
        JOIN LATERAL (
          SELECT * FROM posts
          WHERE user_id = users.id
          ORDER BY id DESC LIMIT :limit
        ) AS selected_posts ON TRUE
      SQL

      selected_posts = User
        .select("selected_posts.*")
        .joins(User.sanitize_sql([sql, limit: n]))

      from(selected_posts, "posts")
    }
  end

  posts = Post.last_n_per_user(3).preload(:user)
  pp posts.group_by(&:user).map { |user, posts| [user.name, posts.map(&:id)] }
end

example "In a has many association" do
  class User < ActiveRecord::Base
    has_many :posts
    has_many :last_posts, -> { last_n_per_user(3) }, class_name: "Post"
  end

  class Post < ActiveRecord::Base
    scope :last_n_per_user, ->(n) {
      selected_posts_table = Arel::Table.new('selected_posts')

      sql = <<-SQL
        JOIN LATERAL (
          SELECT * FROM posts
          WHERE user_id = users.id
          ORDER BY id DESC LIMIT :limit
        ) AS #{selected_posts_table.name} ON TRUE
      SQL

      selected_posts = User
        .select(User.arel_table["id"].as("user_id"))
        .select(Post.column_names.excluding("user_id").map { |column| selected_posts_table[column] })
        .joins(User.sanitize_sql([sql, limit: n]))

      from(selected_posts, "posts")
    }
  end

  users = User.preload(:last_posts).limit(10)
  pp users.map { |user| [user.name, user.last_posts.map(&:id)] }
end

# Setup
# -----
# -- create_table(:users)
#    -> 0.0264s
# -- create_table(:posts)
#    -> 0.0026s
# -- add_index(:posts, :user_id)
#    -> 0.0011s
# 
# 
# Example: SQL query
# ------------------
# D, [2024-07-31T10:13:37.939882 #12364] DEBUG -- :    (1.0ms)      SELECT selected_posts.* FROM users JOIN LATERAL (
#       SELECT * FROM posts
#       WHERE user_id = users.id
#       ORDER BY id DESC LIMIT 3
#     ) AS selected_posts ON TRUE
# 
# [{"id"=>100, "user_id"=>1, "title"=>"Cheesed Alpine"}, {"id"=>99, "user_id"=>1, "title"=>"Nutty Cows"}, {"id"=>98, "user_id"=>1, "title"=>"Soft Brie"}, {"id"=>200, "user_id"=>2, "title"=>"Grated Cows"}, {"id"=>199, "user_id"=>2, "title"=>"Melting Goats"}, {"id"=>198, "user_id"=>2, "title"=>"Melting Coulommiers"}, {"id"=>300, "user_id"=>3, "title"=>"Grated Brie"}, {"id"=>299, "user_id"=>3, "title"=>"Grated Brie"}, {"id"=>298, "user_id"=>3, "title"=>"Grated Coulommiers"}, {"id"=>400, "user_id"=>4, "title"=>"Cheesed Affineurs"}, {"id"=>399, "user_id"=>4, "title"=>"Dutch Dairy"}, {"id"=>398, "user_id"=>4, "title"=>"Soft Goats"}, {"id"=>500, "user_id"=>5, "title"=>"Cheeky Sheep"}, {"id"=>499, "user_id"=>5, "title"=>"Sharp Cows"}, {"id"=>498, "user_id"=>5, "title"=>"Smokey Goats"}, {"id"=>600, "user_id"=>6, "title"=>"Cheeky Gouda"}, {"id"=>599, "user_id"=>6, "title"=>"Dutch Affineurs"}, {"id"=>598, "user_id"=>6, "title"=>"Melting Alpine"}, {"id"=>700, "user_id"=>7, "title"=>"Cheeky Coulommiers"}, {"id"=>699, "user_id"=>7, "title"=>"Smokey Sheep"}, {"id"=>698, "user_id"=>7, "title"=>"Melting Coulommiers"}, {"id"=>800, "user_id"=>8, "title"=>"Milky Coulommiers"}, {"id"=>799, "user_id"=>8, "title"=>"Grated Goats"}, {"id"=>798, "user_id"=>8, "title"=>"Sharp Goats"}, {"id"=>900, "user_id"=>9, "title"=>"Cheeky Cows"}, {"id"=>899, "user_id"=>9, "title"=>"Dutch Sheep"}, {"id"=>898, "user_id"=>9, "title"=>"Cheeky Brie"}, {"id"=>1000, "user_id"=>10, "title"=>"Dutch Gouda"}, {"id"=>999, "user_id"=>10, "title"=>"Melting Dairy"}, {"id"=>998, "user_id"=>10, "title"=>"Cheeky Sheep"}]
# 
# 
# Example: Lateral join with rails with a fixed n
# -----------------------------------------------
# D, [2024-07-31T10:13:37.942006 #12364] DEBUG -- :   Post Load (0.4ms)  SELECT "posts".* FROM (SELECT selected_posts.* FROM "users" JOIN LATERAL (
#           SELECT * FROM posts
#           WHERE user_id = users.id
#           ORDER BY id DESC LIMIT 3
#         ) AS selected_posts ON TRUE) posts
# D, [2024-07-31T10:13:37.948037 #12364] DEBUG -- :   User Load (0.3ms)  SELECT "users".* FROM "users" WHERE "users"."id" IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)  [["id", 1], ["id", 2], ["id", 3], ["id", 4], ["id", 5], ["id", 6], ["id", 7], ["id", 8], ["id", 9], ["id", 10]]
# [["Leida Doyle", [100, 99, 98]],
#  ["Domitila Rowe", [200, 199, 198]],
#  ["Elsie Swift", [300, 299, 298]],
#  ["Minna Macejkovic", [400, 399, 398]],
#  ["Joannie Friesen", [500, 499, 498]],
#  ["Milagro Greenfelder", [600, 599, 598]],
#  ["Sylvie Harris", [700, 699, 698]],
#  ["Paulina Funk", [800, 799, 798]],
#  ["Anita Towne", [900, 899, 898]],
#  ["Sanjuanita Blick", [1000, 999, 998]]]
# 
# 
# Example: Lateral join with rails with a variable n
# --------------------------------------------------
# D, [2024-07-31T10:13:37.951483 #12364] DEBUG -- :   Post Load (0.6ms)  SELECT "posts".* FROM (SELECT selected_posts.* FROM "users" JOIN LATERAL (
#           SELECT * FROM posts
#           WHERE user_id = users.id
#           ORDER BY id DESC LIMIT 3
#         ) AS selected_posts ON TRUE) posts
# D, [2024-07-31T10:13:37.951946 #12364] DEBUG -- :   User Load (0.2ms)  SELECT "users".* FROM "users" WHERE "users"."id" IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)  [["id", 1], ["id", 2], ["id", 3], ["id", 4], ["id", 5], ["id", 6], ["id", 7], ["id", 8], ["id", 9], ["id", 10]]
# [["Leida Doyle", [100, 99, 98]],
#  ["Domitila Rowe", [200, 199, 198]],
#  ["Elsie Swift", [300, 299, 298]],
#  ["Minna Macejkovic", [400, 399, 398]],
#  ["Joannie Friesen", [500, 499, 498]],
#  ["Milagro Greenfelder", [600, 599, 598]],
#  ["Sylvie Harris", [700, 699, 698]],
#  ["Paulina Funk", [800, 799, 798]],
#  ["Anita Towne", [900, 899, 898]],
#  ["Sanjuanita Blick", [1000, 999, 998]]]
# 
# 
# Example: In a has many association
# ----------------------------------
# D, [2024-07-31T10:13:37.952927 #12364] DEBUG -- :   User Load (0.1ms)  SELECT "users".* FROM "users" LIMIT $1  [["LIMIT", 10]]
# D, [2024-07-31T10:13:37.955446 #12364] DEBUG -- :   Post Load (0.7ms)  SELECT "posts".* FROM (SELECT "users"."id" AS user_id, "selected_posts"."id", "selected_posts"."title" FROM "users" JOIN LATERAL (
#           SELECT * FROM posts
#           WHERE user_id = users.id
#           ORDER BY id DESC LIMIT 3
#         ) AS selected_posts ON TRUE) posts WHERE "posts"."user_id" IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)  [["user_id", 1], ["user_id", 2], ["user_id", 3], ["user_id", 4], ["user_id", 5], ["user_id", 6], ["user_id", 7], ["user_id", 8], ["user_id", 9], ["user_id", 10]]
# [["Leida Doyle", [100, 99, 98]],
#  ["Domitila Rowe", [200, 199, 198]],
#  ["Elsie Swift", [300, 299, 298]],
#  ["Minna Macejkovic", [400, 399, 398]],
#  ["Joannie Friesen", [500, 499, 498]],
#  ["Milagro Greenfelder", [600, 599, 598]],
#  ["Sylvie Harris", [700, 699, 698]],
#  ["Paulina Funk", [800, 799, 798]],
#  ["Anita Towne", [900, 899, 898]],
#  ["Sanjuanita Blick", [1000, 999, 998]]]
