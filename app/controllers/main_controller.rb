class MainController < ApplicationController
  def index
    args = current_or_default_period
    args.merge!(start: 0, length: 5)

    # for showing on view
    @from = args[:from]
    @to = args[:to]
    
    # retrieving data
    @dommain_by_deferred, count = Message.domain_by('deferred', args)
    @dommain_by_bounced, count = Message.domain_by('bounced', args)
    @dommain_by_sent, count = Message.domain_by('sent', args)
    @dommain_by_rejected, count = Message.domain_by('rejected', args)
  end

  def domains_export
    args = current_or_default_period
    
    Message.domains_export(params[:status], args)
    redirect_to data_files_path
  end

  def domains
    args = current_or_default_period

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

  def all_export
    args = current_or_default_period
    Message.all_export(args)
    redirect_to data_files_path
  end

  def all
    args = current_or_default_period

    # for showing on view
    @from = args[:from]
    @to = args[:to]

    respond_to do |format|
      format.html {}
      format.json {
        data, count = Message.domain_statistics(args)
        render json: { data: data, recordsFiltered: count, recordsTotal: count}
      }
    end
  end

  def users_export
    domain = Base64.decode64(params[:base64_domain])
    args = current_or_default_period
    Message.users_export(domain, args)
    redirect_to data_files_path
  end

  def users
    @domain = Base64.decode64(params[:base64_domain])
    @domain_encoded = params[:base64_domain]
    
    args = current_or_default_period

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

  def details_export
    domain = Base64.decode64(params[:base64_domain])
    args = current_or_default_period
    Message.details_export(domain, args)
    redirect_to data_files_path
  end

  def details
    @domain = Base64.decode64(params[:base64_domain])
    @domain_encoded = params[:base64_domain]
    
    args = current_or_default_period

    # for showing on view
    @from = args[:from]
    @to = args[:to]
    @status = args[:status]

    respond_to do |format|
      format.html {}
      format.json {
        data, count = Message.details_by_domain(@domain, args)
        render json: { data: data, recordsFiltered: count, recordsTotal: count}
      }
    end
  end
  
  private
  def current_or_default_period
    unless session[:args]
      d = Date.today
      session[:args] = {
        from: d.at_beginning_of_month.strftime('%Y/%m/%d'),
        to: d.at_end_of_month.strftime('%Y/%m/%d')
      }
    end
    
    session[:args].merge!(params.permit(:from, :to).symbolize_keys)

    return params.symbolize_keys.merge(session[:args].symbolize_keys)
  end
end
