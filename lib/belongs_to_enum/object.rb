class Object
  # adds methods to the singleton_class
  def meta_def name, &blk
    singleton_class.instance_eval do
      define_method name, &blk
    end
  end
end
