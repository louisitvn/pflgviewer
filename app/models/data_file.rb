class DataFile < ActiveRecord::Base
  IN_PROGRESS = 'in-progress'
  DONE        = 'done'

  def downloadable?
    self.status == DONE
  end
end
