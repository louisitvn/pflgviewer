class MainController < ApplicationController
  def index
    respond_to do |format|
      format.html {
        # for showing to view
        @from = params[:from]
        @to = params[:to]
        
        # retrieving data
        @dommain_by_deferred = Message.domain_by_deferred(params)
        @dommain_by_bounced = Message.domain_by_bounced(params)
        @dommain_by_sent = Message.domain_by_sent(params)
        @dommain_by_rejected = Message.domain_by_rejected(params)

      }
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
