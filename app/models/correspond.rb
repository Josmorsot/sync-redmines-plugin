class Correspond < ActiveRecord::Base
  unloadable
  attr_accessible :id_local 
  attr_accessible :id_remote
  attr_accessible :remote_type 
end
