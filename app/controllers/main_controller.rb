class MainController < ApplicationController
  def index
    # Default: show data of this month, limit 5 entries
    d = Date.today

    args = {
      from: d.at_beginning_of_month.strftime('%Y/%m/%d'),
      to: d.at_end_of_month.strftime('%Y/%m/%d'),
      limit: 5,
      offset: 0
    }
    
    # the default values to be overwritten by user custom values
    p 'AAAAAAAAAAAAA', args
    args.merge!(params.symbolize_keys)

    p params
    p args
    p "END"

    # for showing on view
    @from = args[:from]
    @to = args[:to]
    
    # retrieving data
    @dommain_by_deferred, count = Message.domain_by_deferred(args)
    @dommain_by_bounced, count = Message.domain_by_bounced(args)
    @dommain_by_sent, count = Message.domain_by_sent(args)
    @dommain_by_rejected, count = Message.domain_by_rejected(args)
  end

  def domains
    # show danh sách domain by status
    @status = params[:status]

    respond_to do |format|
      format.html {}
      format.json {
        if @status == 'rejected'
          data, count = Message.domain_by_rejected(params)
        elsif @status == 'deferred'
          data, count = Message.domain_by_deferred(params)
        elsif @status == 'sent'
          data, count = Message.domain_by_sent(params)
        elsif @status == 'bounced'
          data, count = Message.domain_by_bounced(params)
        end

        render json: { data: data.as_json(only: [:domain, :percentage, :volume]), recordsFiltered: count, recordsTotal: count}
      }
    end
  end

  def users
    @domain = Base64.decode64(params[:base64_domain])
    @domain_encoded = params[:base64_domain]
    respond_to do |format|
      format.html {}
      format.json {
        data, count = Message.users_by_domain(@domain)
        render json: { data: data.as_json(only: [:recipient, :rejected, :deferred, :sent, :bounced]), recordsFiltered: count, recordsTotal: count}
      }
    end
  end

  def user
    
  end
end
