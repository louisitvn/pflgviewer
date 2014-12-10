class MainController < ApplicationController
  def index
    respond_to do |format|
      format.html {}
      format.json {
        render json: { 
          entries: [
            {
              id: 1,
              name: 'aaaaa',
              size: '1343k',
              domain: 'domain'
            },{
              id: 2,
              name: 'bbb',
              size: '108k',
              domain: 'domain'
            }
          ]
        } 
      }
    end
  end
end
