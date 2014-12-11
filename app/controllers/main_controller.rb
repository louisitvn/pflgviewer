class MainController < ApplicationController
  def index
    respond_to do |format|
      format.html {}
      format.json {
        jdata = {entries: [], filteredRecords: 100}
        1.upto(100) do |i|
          jdata[:entries] << { id: i, name: "R#{i}", size: "#{i * 234 + 382}", domain: "Row #{i}" }
        end
        render json: jdata
      }
    end
  end
end
