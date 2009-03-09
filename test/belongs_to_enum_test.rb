require 'test_helper'

class BelongsToEnumTest < ActiveSupport::TestCase
  load_schema

  #-----------------------------------------------

  class User < ActiveRecord::Base
    belongs_to_enum :status,
    { 1 => :new,
      2 => {:name => :in_progress, :title => 'Continuing'},
      3 => {:name => :completed, :position => 300},
      4 => {:name => :cancelled, :title => 'Ended', :position => 5}
    }
    validates_inclusion_of_enum :status_id
  end

  test "Schema has loaded correctly" do
    assert_equal [], User.all
  end

  test "User.default_status is nil if there is no default status" do
    assert_nil User.default_status
  end

  test "User.statuses should return an array of statuses sorted by position" do
    assert_equal 4, User.statuses.size
    assert_equal Array, User.statuses.class

    statuses = User.statuses
    1.upto(3) do |i|
      assert statuses[i].position >= statuses[i-1].position
    end
  end

  test "User.status(name/id) should return the status" do
    status = User.status(1)
    assert_equal 1, status.id
    assert_equal :new, status.name

    status = User.status(:cancelled)
    assert_equal :cancelled, status.name
  end

  test "User.status(key) should raise an error if the key is not an integer or symbol" do
    assert_raise RuntimeError do
      status = User.status('New')
    end
  end

  test "belongs_to_enum should raise an runtime error if a value in the hash is not a symbol or a hash" do
    assert_raise RuntimeError do
      User.belongs_to_enum :status, {1 => 100}
    end
  end

  test "belongs_to_enum should base the position from the id if it is not provided" do
    status = User.status(1)
    assert_equal 1, status.position
  end

  test "belongs_to_enum should base the display name from the name if it is not provided" do
    status = User.status(:completed)
    assert_equal 'Completed', status.title
  end

  test "belongs_to_enum should set the position it is provided" do
    status = User.status(:completed)
    assert_equal 300, status.position
  end

  test "belongs_to_enum should set the display name if it is provided" do
    status = User.status(:cancelled)
    assert_equal 'Ended', status.title
  end

  test "I can set the status by EnumField object or by name" do
    user = User.new(:status => User.status(:new))
    assert_equal :new, user.status.name

    user.status = :completed
    assert_equal :completed, user.status.name

    user.status = nil
    assert_nil user.status
    assert_nil user.status_id
  end

  test "user should not be valid if I set the status to a status that is not in the belongs_to_enum list" do
    user = User.new(:status_id => 5)
    assert ! user.valid?
    assert_equal 1, user.errors.size
    assert_match 'is not valid', user.errors.full_messages[0]
  end

  test "I can check if user.<status.name>? is true" do
    user = User.new(:status => :completed)
    assert user.completed?
    assert ! user.new?
  end

  test "The methods added by belongs_to_enum should work fine if user.status_id is nil" do
    user = User.new
    assert_nil user.status_id
    assert_nil user.status
    assert ! user.new?
  end

  #-----------------------------------------------

  class Comment < ActiveRecord::Base
    belongs_to_enum :status,
    { 1 => :new,
      2 => {:name => :in_progress, :title => 'Continuing'},
      3 => {:name => :completed, :position => 300, :default => true},
      4 => {:name => :cancelled, :title => 'Ended', :position => 5, :default => true}
    }

    validates_inclusion_of_enum :status_id, :in => [3, :cancelled], :message => "must be completed or ended", :allow_blank => true
  end

  # Note: there are two defaults in comment. 
  test "I can get the Comment.default_status" do
    assert Comment.status(:cancelled).default?
    assert_equal Comment.status(:cancelled), Comment.default_status
  end

  test "I can change the validates_inclusion_of options in belongs_to_enum" do
    comment = Comment.new(:status => :cancelled)
    assert comment.valid?

    comment = Comment.new(:status_id => '')
    assert comment.valid?
    
    comment = Comment.new(:status => :new)
    assert ! comment.valid?
    assert_equal 1, comment.errors.size
    assert_match 'must be completed or ended', comment.errors.full_messages[0]
  end

  #-----------------------------------------------

  class Status < ActiveRecord::Base
    has_many :posts

    def inspect
      inspect_attributes :id, :name, :title, :position, :default?
    end

    def inspect_attributes(*attributes)
      "#{self.class.name.demodulize}(" + attributes.collect{|a| "#{a}: #{self.send(a).inspect}"}.join(', ') + ")"
    end
  end

  Status.create :name => 'new'
  Status.create :name => 'in_progress', :title => 'Continuing'
  Status.create :name => 'completed', :position => 300, :default => true
  Status.create :name => 'cancelled', :title => 'Ended', :position => 5

  class Post < ActiveRecord::Base
    belongs_to_enum :status, Status.all
    validates_inclusion_of_enum :status_id, { :in => [:completed, :cancelled], :message => "must be completed or ended", :allow_blank => true}
  end

  test "I can use both belongs_to and belongs_to_enum without exploding" do
    assert_equal 4, Post.statuses.size
    assert_kind_of Status, Post.statuses[0]
    
    assert_equal :in_progress, Post.status(:in_progress).name
    assert_equal 300, Post.default_status.position

    post = Post.new

    post.status = :in_progress
    assert_kind_of Status, post.status
    assert ! post.new?
    assert post.in_progress?

    assert ! post.valid?
    assert_equal 1, post.errors.size
    assert_match 'must be completed or ended', post.errors.full_messages[0]
  end
end