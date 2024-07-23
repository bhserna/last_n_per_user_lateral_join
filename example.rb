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

  users = User.preload(:last_posts).limit(5)
  pp users.map { |user| [user.name, user.last_posts.map(&:id)] }
end

# Setup
# -----
# -- create_table(:users)
#    -> 0.0262s
# -- create_table(:posts)
#    -> 0.0031s
# -- add_index(:posts, :user_id)
#    -> 0.0016s
# 
# 
# Example: SQL query
# ------------------
# D, [2022-08-16T06:26:29.015001 #14740] DEBUG -- :    (1.1ms)      SELECT selected_posts.* FROM users JOIN LATERAL (
#       SELECT * FROM posts
#       WHERE user_id = users.id
#       ORDER BY id DESC LIMIT 3
#     ) AS selected_posts ON TRUE
# 
# [{"id"=>100, "user_id"=>1, "title"=>"Grated Goats"}, {"id"=>99, "user_id"=>1, "title"=>"Nutty Dairy"}, {"id"=>98, "user_id"=>1, "title"=>"Grated Brie"}, {"id"=>200, "user_id"=>2, "title"=>"Smokey Goats"}, {"id"=>199, "user_id"=>2, "title"=>"Sharp Dairy"}, {"id"=>198, "user_id"=>2, "title"=>"Melting Brie"}, {"id"=>300, "user_id"=>3, "title"=>"Melting Sheep"}, {"id"=>299, "user_id"=>3, "title"=>"Soft Affineurs"}, {"id"=>298, "user_id"=>3, "title"=>"Nutty Coulommiers"}, {"id"=>400, "user_id"=>4, "title"=>"Dutch Gouda"}, {"id"=>399, "user_id"=>4, "title"=>"Smokey Gouda"}, {"id"=>398, "user_id"=>4, "title"=>"Sharp Affineurs"}, {"id"=>500, "user_id"=>5, "title"=>"Soft Dairy"}, {"id"=>499, "user_id"=>5, "title"=>"Fat Coulommiers"}, {"id"=>498, "user_id"=>5, "title"=>"Melting Alpine"}, {"id"=>600, "user_id"=>6, "title"=>"Milky Gouda"}, {"id"=>599, "user_id"=>6, "title"=>"Soft Goats"}, {"id"=>598, "user_id"=>6, "title"=>"Smokey Brie"}, {"id"=>700, "user_id"=>7, "title"=>"Melting Brie"}, {"id"=>699, "user_id"=>7, "title"=>"Soft Goats"}, {"id"=>698, "user_id"=>7, "title"=>"Sharp Goats"}, {"id"=>800, "user_id"=>8, "title"=>"Grated Dairy"}, {"id"=>799, "user_id"=>8, "title"=>"Milky Brie"}, {"id"=>798, "user_id"=>8, "title"=>"Sharp Gouda"}, {"id"=>900, "user_id"=>9, "title"=>"Grated Gouda"}, {"id"=>899, "user_id"=>9, "title"=>"Dutch Goats"}, {"id"=>898, "user_id"=>9, "title"=>"Grated Goats"}, {"id"=>1000, "user_id"=>10, "title"=>"Fat Coulommiers"}, {"id"=>999, "user_id"=>10, "title"=>"Soft Affineurs"}, {"id"=>998, "user_id"=>10, "title"=>"Dutch Alpine"}]
# 
# 
# Example: Lateral join with rails with a fixed n
# -----------------------------------------------
# D, [2022-08-16T06:26:29.018260 #14740] DEBUG -- :   Post Load (0.6ms)  SELECT "posts".* FROM (SELECT selected_posts.* FROM "users" JOIN LATERAL (
#           SELECT * FROM posts
#           WHERE user_id = users.id
#           ORDER BY id DESC LIMIT 3
#         ) AS selected_posts ON TRUE) posts
# D, [2022-08-16T06:26:29.031011 #14740] DEBUG -- :   User Load (0.4ms)  SELECT "users".* FROM "users" WHERE "users"."id" IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)  [["id", 1], ["id", 2], ["id", 3], ["id", 4], ["id", 5], ["id", 6], ["id", 7], ["id", 8], ["id", 9], ["id", 10]]
# [["Buddy Mohr", [100, 99, 98]],
#  ["Renea Abshire", [200, 199, 198]],
#  ["Liliana Funk", [300, 299, 298]],
#  ["Floretta Wiegand", [400, 399, 398]],
#  ["Jerilyn Zulauf", [500, 499, 498]],
#  ["Margaret Schowalter", [600, 599, 598]],
#  ["Rosemary Wilkinson", [700, 699, 698]],
#  ["Brian Emmerich", [800, 799, 798]],
#  ["Mammie Leuschke", [900, 899, 898]],
#  ["Theodora Howe", [1000, 999, 998]]]
# 
# 
# Example: Lateral join with rails with a variable n
# --------------------------------------------------
# D, [2022-08-16T06:26:29.038735 #14740] DEBUG -- :   Post Load (1.2ms)  SELECT "posts".* FROM (SELECT selected_posts.* FROM "users" JOIN LATERAL (
#           SELECT * FROM posts
#           WHERE user_id = users.id
#           ORDER BY id DESC LIMIT 3
#         ) AS selected_posts ON TRUE) posts
# D, [2022-08-16T06:26:29.040289 #14740] DEBUG -- :   User Load (0.4ms)  SELECT "users".* FROM "users" WHERE "users"."id" IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)  [["id", 1], ["id", 2], ["id", 3], ["id", 4], ["id", 5], ["id", 6], ["id", 7], ["id", 8], ["id", 9], ["id", 10]]
# [["Buddy Mohr", [100, 99, 98]],
#  ["Renea Abshire", [200, 199, 198]],
#  ["Liliana Funk", [300, 299, 298]],
#  ["Floretta Wiegand", [400, 399, 398]],
#  ["Jerilyn Zulauf", [500, 499, 498]],
#  ["Margaret Schowalter", [600, 599, 598]],
#  ["Rosemary Wilkinson", [700, 699, 698]],
#  ["Brian Emmerich", [800, 799, 798]],
#  ["Mammie Leuschke", [900, 899, 898]],
#  ["Theodora Howe", [1000, 999, 998]]]
# 
# 
# Example: In a has many association
# ----------------------------------
# D, [2022-08-16T06:26:29.045333 #14740] DEBUG -- :   User Load (0.6ms)  SELECT "users".* FROM "users"
# D, [2022-08-16T06:26:29.051624 #14740] DEBUG -- :   Post Load (0.8ms)  SELECT "posts".* FROM (SELECT selected_posts.* FROM "users" JOIN LATERAL (
#           SELECT * FROM posts
#           WHERE user_id = users.id
#           ORDER BY id DESC LIMIT 3
#         ) AS selected_posts ON TRUE) posts WHERE "posts"."user_id" IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)  [["user_id", 1], ["user_id", 2], ["user_id", 3], ["user_id", 4], ["user_id", 5], ["user_id", 6], ["user_id", 7], ["user_id", 8], ["user_id", 9], ["user_id", 10]]
# [["Buddy Mohr", [100, 99, 98]],
#  ["Renea Abshire", [200, 199, 198]],
#  ["Liliana Funk", [300, 299, 298]],
#  ["Floretta Wiegand", [400, 399, 398]],
#  ["Jerilyn Zulauf", [500, 499, 498]],
#  ["Margaret Schowalter", [600, 599, 598]],
#  ["Rosemary Wilkinson", [700, 699, 698]],
#  ["Brian Emmerich", [800, 799, 798]],
#  ["Mammie Leuschke", [900, 899, 898]],
#  ["Theodora Howe", [1000, 999, 998]]]