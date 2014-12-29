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
    @dommain_by_deferred, count = Message.domain_by('deferred', args)
    @dommain_by_bounced, count = Message.domain_by('bounced', args)
    @dommain_by_sent, count = Message.domain_by('sent', args)
    @dommain_by_rejected, count = Message.domain_by('rejected', args)
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
    @status = params[:status]

    respond_to do |format|
      format.html {}
      format.json {
        data, count = Message.domain_by(params[:status], args)

        render json: { data: data, recordsFiltered: count, recordsTotal: count}
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
        render json: { data: data, recordsFiltered: count, recordsTotal: count}
      }
    end
  end

  def details
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
        data, count = Message.details_by_domain(@domain, args)
        render json: { data: data, recordsFiltered: count, recordsTotal: count}
      }
    end
  end
end
