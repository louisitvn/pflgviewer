require 'sql_helper'
require 'csv'

class Message < ActiveRecord::Base
  extend SqlHelper

  DEFAULT_LIMIT = 20
  DEFAULT_OFFSET = 0
  
  def self.load(file)
    messages = PostfixLogParser.load(File.join(Rails.root, 'mail.log'))
    Message.execute_db_update!(messages)
  end

  def self.users_export(domain, args)
    filename = "Domain-Users-Summary-#{Time.now.to_i}.csv"
    filepath = File.join(Rails.root, 'tmp', filename)
    datafile = DataFile.create(name: filename, description: "Domain Users Statistics (#{domain})", status: DataFile::IN_PROGRESS, path: filepath)
    self.delay.users_export_delayed(datafile, domain, args)
  end

  def self.users_export_delayed(datafile, domain, args)
    CSV.open(datafile.path, 'w') do |csv|
      headers = [
        'Recipient', 'Sent', 'Deliverred', 'Bounced', 'Success Rage', 'Sent (last 30 days)', 'Deliverred (last 30 days)', 'Bounced (last 30 days)', 'Success Rage (last 30 days)'
      ]

      csv << headers

      each_page(20, :users_by_domain, *[domain, args]) { |data|
        data.each do |item|
          csv << [
            item.recipient, item.sent, item.delivered, item.bounced, item.success_rate, item.sent_30, item.delivered_30, item.bounced_30, item.success_rate_30
          ]
        end
      }
    end

    datafile.update_attributes(status: DataFile::DONE)
  end

  def self.details_export(domain, args)
    filename = "Domain-Users-Details-#{Time.now.to_i}.csv"
    filepath = File.join(Rails.root, 'tmp', filename)
    datafile = DataFile.create(name: filename, description: "Domain User Details (#{domain})", status: DataFile::IN_PROGRESS, path: filepath)
    self.delay.details_export_delayed(datafile, domain, args)
  end
  
  def self.details_export_delayed(datafile, domain, args)
    CSV.open(datafile.path, 'w') do |csv|
      headers = [
        'Recipient', 'Recipient Server', 'Time', 'Status Code', 'Server Response', 'Delivery Status'
      ]

      csv << headers

      each_page(20, :details_by_domain, *[domain, args]) { |data|
        data.each do |item|
          csv << [
            item.recipient, item.relay, item.datetime, item.status_code, item.status_message, item.status
          ]
        end
      }
    end

    datafile.update_attributes(status: DataFile::DONE)
  end

  def self.all_export(args)
    filename = "Domains-Statistics-#{Time.now.to_i}.csv"
    filepath = File.join(Rails.root, 'tmp', filename)
    datafile = DataFile.create(name: filename, description: 'Domain Statistics', status: DataFile::IN_PROGRESS, path: filepath)
    self.delay.all_export_delayed(datafile, args)
  end

  def self.all_export_delayed(datafile, args)
    CSV.open(datafile.path, 'w') do |csv|
      headers = [ 'Domain', 'Delivered', 'Deferred', 'Bounced', 'Rejected', 'Expired', 'Domain', 'Delivered (last 30 days)', 'Deferred (last 30 days)', 'Bounced (last 30 days)', 'Rejected (last 30 days)', 'Expired (last 30 days)' ]
      csv << headers

      each_page(20, :domain_statistics, args) { |data|
        data.each do |item|
          csv << [
            item.recipient_domain, 
            "#{item.sent}(#{item.sent_count})", "#{item.deferred}(#{item.deferred_count})", "#{item.bounced}(#{item.bounced_count})", "#{item.rejected}(#{item.rejected_count})", "#{item.expired}(#{item.expired_count})",
            "#{item.sent_30}(#{item.sent_count_30})", "#{item.deferred_30}(#{item.deferred_count_30})", "#{item.bounced_30}(#{item.bounced_count_30})", "#{item.rejected_30}(#{item.rejected_count_30})", "#{item.expired_30}(#{item.expired_count_30})",
          ]
        end
      }
    end

    datafile.update_attributes(status: DataFile::DONE)
  end

  def self.domains_export(status, args)
    filename = "Domains-By-#{status.capitalize}-#{Time.now.to_i}.csv"
    filepath = File.join(Rails.root, 'tmp', filename)
    datafile = DataFile.create(name: filename, description: "Domains by #{status.upcase}", status: DataFile::IN_PROGRESS, path: filepath)
    self.delay.domains_export_delayed(datafile, status, args)
  end

  def self.domains_export_delayed(datafile, status, args)
    CSV.open(datafile.path, 'w') do |csv|
      headers = [   'Domain', '%', 'Volume', '% Change'  ]
      csv << headers

      each_page(20, :domain_by, *[status, args]) { |data|
        data.each do |item|
          csv << [
            item.domain, item.percentage, item.volume, item.change
          ]
        end
      }
    end

    datafile.update_attributes(status: DataFile::DONE)
  end

  # why bother joining messages table, the recipients alone is not enough?
  def self.domain_by(status, params)
    last_30_days_end = (DateTime.parse(params[:to]) - 1.days)
    last_30_days_start = last_30_days_end - 30.days
    
    # @todo Khi count phải bỏ mấy thằng null!!!!!!!!!

    sql = %Q{
      SELECT t1.*, coalesce(t2.volume_30, 0) AS volume_30, coalesce(t2.percentage_30, 0) AS percentage_30, (percentage - percentage_30) AS change FROM
      (
        SELECT msg.recipient_domain AS domain, sum(CASE COALESCE(status, '') WHEN :status THEN 1 ELSE 0 END) as volume, round(sum(CASE COALESCE(status, '') WHEN :status THEN 1 ELSE 0 END)::numeric * 100 / count(*), 2) as percentage
        FROM messages msg
        WHERE msg.recipient_domain IS NOT NULL AND status IS NOT NULL AND #{conditions_from_params(params)}
        GROUP BY msg.recipient_domain
      ) t1
      LEFT JOIN
      (
        SELECT msg.recipient_domain AS domain_30, sum(CASE COALESCE(status, '') WHEN :status THEN 1 ELSE 0 END) as volume_30, round(sum(CASE COALESCE(status, '') WHEN :status THEN 1 ELSE 0 END)::numeric * 100 / count(*), 2) as percentage_30
        FROM messages msg
        WHERE msg.recipient_domain IS NOT NULL AND status IS NOT NULL AND #{conditions_from_params(from: last_30_days_start, to: last_30_days_end)}
        GROUP BY msg.recipient_domain
      ) t2
      ON t1.domain = t2.domain_30
      #{sorts_by_params(params)}
      LIMIT :limit OFFSET :offset
    }

    count_sql = %Q{
      SELECT COUNT(*) FROM
      ( 
        SELECT msg.recipient_domain
        FROM messages msg
        WHERE msg.recipient_domain IS NOT NULL AND status IS NOT NULL AND #{conditions_from_params(params)}
        GROUP BY msg.recipient_domain
      ) tmp
    }

    data = self.find_by_sql([sql, status: status, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql([count_sql, status: status])
    return data, count
  end

  def self.domain_statistics(params = {})
    last_30_days_end = (DateTime.parse(params[:to]) - 1.days)
    last_30_days_start = last_30_days_end - 30.days

    sql = %Q{
      SELECT t1.*,
              coalesce(sent_count_30, 0) AS sent_count_30,
              coalesce(rejected_count_30, 0) AS rejected_count_30,
              coalesce(bounced_count_30, 0) AS bounced_count_30,
              coalesce(deferred_count_30, 0) AS deferred_count_30,
              coalesce(expired_count_30, 0) AS expired_count_30,
              coalesce(sent_30, 0) AS sent_30,
              coalesce(rejected_30, 0) AS rejected_30,
              coalesce(bounced_30, 0) AS bounced_30,
              coalesce(deferred_30, 0) AS deferred_30,
              coalesce(expired_30, 0) AS expired_30
      FROM
      (
        SELECT recipient_domain,
               SUM(case status when 'sent' then 1 else 0 end) AS sent_count,
               SUM(case status when 'rejected' then 1 else 0 end) AS rejected_count,
               SUM(case status when 'bounced' then 1 else 0 end) AS bounced_count,
               SUM(case status when 'deferred' then 1 else 0 end) AS deferred_count,
               SUM(case status when 'expired' then 1 else 0 end) AS expired_count,
               round(SUM(case status when 'sent' then 1 else 0 end)::numeric *100/count(*), 2) AS sent,
               round(SUM(case status when 'rejected' then 1 else 0 end)::numeric *100/count(*), 2) AS rejected,
               round(SUM(case status when 'bounced' then 1 else 0 end)::numeric *100/count(*), 2) AS bounced,
               round(SUM(case status when 'deferred' then 1 else 0 end)::numeric *100/count(*), 2) AS deferred,
               round(SUM(case status when 'expired' then 1 else 0 end)::numeric *100/count(*), 2) AS expired
        FROM messages 
        WHERE recipient_domain IS NOT NULL AND status IS NOT NULL AND #{conditions_from_params(params)}
        GROUP BY recipient_domain
      ) t1 
      
      LEFT JOIN 
      (
        SELECT recipient_domain AS recipient_domain_30,
               SUM(case status when 'sent' then 1 else 0 end) AS sent_count_30,
               SUM(case status when 'rejected' then 1 else 0 end) AS rejected_count_30,
               SUM(case status when 'bounced' then 1 else 0 end) AS bounced_count_30,
               SUM(case status when 'deferred' then 1 else 0 end) AS deferred_count_30,
               SUM(case status when 'expired' then 1 else 0 end) AS expired_count_30,
               round(SUM(case status when 'sent' then 1 else 0 end)::numeric *100/count(*), 2) AS sent_30,
               round(SUM(case status when 'rejected' then 1 else 0 end)::numeric *100/count(*), 2) AS rejected_30,
               round(SUM(case status when 'bounced' then 1 else 0 end)::numeric *100/count(*), 2) AS bounced_30,
               round(SUM(case status when 'deferred' then 1 else 0 end)::numeric *100/count(*), 2) AS deferred_30,
               round(SUM(case status when 'expired' then 1 else 0 end)::numeric *100/count(*), 2) AS expired_30
        FROM messages 
        WHERE recipient_domain IS NOT NULL AND status IS NOT NULL AND #{conditions_from_params(from: last_30_days_start, to: last_30_days_end)}
        GROUP BY recipient_domain
      ) t2 
      
      ON t1.recipient_domain = t2.recipient_domain_30
      #{sorts_by_params(params)}
      LIMIT :limit OFFSET :offset
    }

    count_sql = 'SELECT COUNT(*) FROM (SELECT DISTINCT recipient_domain FROM messages) tmp'
    data = self.find_by_sql([sql, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql([count_sql])
    return data, count
  end

  def self.users_by_domain(domain, params = {})
    last_30_days_end = (DateTime.parse(params[:to]) - 1.days)
    last_30_days_start = last_30_days_end - 30.days

    sql = %Q{
      SELECT t1.*,
              coalesce(sent_30, 0) AS sent_30,
              coalesce(delivered_30, 0) AS delivered_30,
              coalesce(rejected_30, 0) AS rejected_30,
              coalesce(bounced_30, 0) AS bounced_30,
              coalesce(success_rate_30, 0) AS success_rate_30
      FROM
      (
        SELECT recipient,
               SUM(case coalesce(status, '') when '' then 0 else 1 end) sent,
               SUM(case status when 'sent' then 1 else 0 end) AS delivered,
               SUM(case status when 'rejected' then 1 else 0 end) AS rejected,
               SUM(case status when 'bounced' then 1 else 0 end) AS bounced,
               round(SUM(case status when 'sent' then 1 else 0 end)::numeric * 100 / count(*), 2) AS success_rate
        FROM messages 
        WHERE recipient_domain = :domain AND #{conditions_from_params(params)}
        GROUP BY recipient
      ) t1 
      
      LEFT JOIN 
      
      (
        SELECT recipient AS recipient_30,
               SUM(case coalesce(status, '') when '' then 0 else 1 end) sent_30,
               SUM(case status when 'sent' then 1 else 0 end) AS delivered_30,
               SUM(case status when 'rejected' then 1 else 0 end) AS rejected_30,
               SUM(case status when 'bounced' then 1 else 0 end) AS bounced_30,
               round(SUM(case status when 'sent' then 1 else 0 end)::numeric * 100 / count(*), 2) AS success_rate_30
        FROM messages 
        WHERE recipient_domain = :domain AND #{conditions_from_params(from: last_30_days_start, to: last_30_days_end)}
        GROUP BY recipient
      ) t2 
      
      ON t1.recipient = t2.recipient_30
      #{sorts_by_params(params)}
      LIMIT :limit OFFSET :offset
    }

    count_sql = "SELECT COUNT(*) FROM (SELECT DISTINCT recipient FROM messages WHERE recipient_domain = :domain AND #{conditions_from_params(params)}) tmp"
    data = self.find_by_sql([sql, domain: domain, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql([count_sql, domain: domain])
    return data, count
  end

  
  def self.details_by_domain(domain, params = {})
    sql = %Q{
      SELECT * 
      FROM messages
      WHERE 
        status IS NOT NULL AND
        recipient_domain = :domain AND
        #{conditions_from_params(params)}
      #{sorts_by_params(params)}
      LIMIT :limit OFFSET :offset
    }

    count_sql = "SELECT COUNT(*) FROM messages WHERE status IS NOT NULL AND recipient_domain = :domain AND #{conditions_from_params(params)}"

    data = self.find_by_sql([sql, domain: domain, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql([count_sql, domain: domain])
    return data, count
  end

  def recipient_server
    self.status_message[/(?<=host )[a-zA-Z0-9\-_\.]+/] || 
    self.status_message[/(?<=Hostname=)[a-zA-Z0-9\-_\.]+/] || 
    self.status_message[/(?<=relay=)[a-zA-Z0-9\-_\.]+/]
  end

  private
  def self.to_count_sql(sql)
    sql.strip.gsub(/SELECT.*(?=FROM)/m, "SELECT COUNT(*) ").gsub(/LIMIT.*/m, "").strip
  end

  def self.sorts_by_params(params)
    begin
      sort_by = params[:columns][ params[:order]["0"]['column'] ]['name'] 
      sort_order = params[:order]["0"]['dir']
    rescue Exception => ex
      
    end

    if sort_by and sort_order
      "ORDER BY #{sort_by} #{sort_order}" 
    elsif params[:default_order]
      "ORDER BY #{params[:default_order]}"
    else
      ""
    end
  end

  def self.conditions_from_params(params)
    # @note FROM/TO are in the date format of yyyy/mm/dd
    p params
    
    params = params.symbolize_keys
    conn = self.connection

    conditions = []
    
    # PERIOD CONDITIONS
    if params[:from]
      from = params[:from].is_a?(String) ? DateTime.parse(params[:from]) : params[:from]
      if params[:to]
        to = params[:to].is_a?(String) ? DateTime.parse(params[:to]) + 1.days : params[:to]
        conditions << "datetime >= #{conn.quote(from)} AND datetime < #{conn.quote(to)}"
      else
        conditions << "datetime >= #{conn.quote(from)}"
      end
    end

    # COLUMN SEARCH CONDITIONS
    if params[:columns]
      conditions << params[:columns].select{|k,v| !v['search']['value'].blank? }.map{|k,v| "#{v['name']} = #{conn.quote(v['search']['value'])}" }.join(' AND ')
    end

    return conditions.reject(&:blank?).uniq.join(" AND ")
  end

  def self.each_page(size, method, *args)
    _args = args
    _args.last.merge!(start: 0, length: 0)

    # just send a fake request to compute the total page
    data, count = self.send(method, *_args)

    # iterate through pages
    (0..count-1).to_a.each_slice(size){ |a|
      p "Scraping page", a
      start = a.first
      length = size
      _args.last.merge!(start: start, length: length)
      
      
      data, count = self.send(method, *_args )
      yield data
    }
    
  end
end
