class DataFile < ActiveRecord::Base
  IN_PROGRESS = 'in-progress'
  DONE        = 'done'

  before_destroy :delete_file

  def downloadable?
    self.status == DONE
  end

  private
  def delete_file
    File.delete(self.path) if File.exists?(self.path)
  end
end
