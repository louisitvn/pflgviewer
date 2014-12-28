class MainController < ApplicationController
  def index
    # Default: show data of this month, limit 5 entries
    d = Date.today

    args = {
      from: d.at_beginning_of_month.strftime('%Y/%m/%d'),
      to: d.at_end_of_month.strftime('%Y/%m/%d'),
      length: 5,
      start: 0
    }
    
    # the default values to be overwritten by user custom values
    args.merge!(params.symbolize_keys)

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
    d = Date.today

    args = {
      from: d.at_beginning_of_month.strftime('%Y/%m/%d'),
      to: d.at_end_of_month.strftime('%Y/%m/%d')
    }

    # the default values to be overwritten by user custom values
    args.merge!(params.symbolize_keys)

    # for showing on view
    @from = args[:from]
    @to = args[:to]

    # show danh sách domain by status
    @status = params[:status]

    respond_to do |format|
      format.html {}
      format.json {
        if @status == 'rejected'
          data, count = Message.domain_by_rejected(args)
        elsif @status == 'deferred'
          data, count = Message.domain_by_deferred(args)
        elsif @status == 'sent'
          data, count = Message.domain_by_sent(args)
        elsif @status == 'bounced'
          data, count = Message.domain_by_bounced(args)
        end

        render json: { data: data.as_json(only: [:domain, :percentage, :volume]), recordsFiltered: count, recordsTotal: count}
      }
    end
  end

  def users
    @domain = Base64.decode64(params[:base64_domain])
    @domain_encoded = params[:base64_domain]
    
    d = Date.today

    args = {
      from: d.at_beginning_of_month.strftime('%Y/%m/%d'),
      to: d.at_end_of_month.strftime('%Y/%m/%d')
    }

    # the default values to be overwritten by user custom values
    args.merge!(params.symbolize_keys)

    # for showing on view
    @from = args[:from]
    @to = args[:to]

    respond_to do |format|
      format.html {}
      format.json {
        data, count = Message.users_by_domain(@domain, args)
        render json: { data: data.as_json(only: [:recipient, :rejected, :deferred, :sent, :bounced]), recordsFiltered: count, recordsTotal: count}
      }
    end
  end

  def user
    
  end
end
