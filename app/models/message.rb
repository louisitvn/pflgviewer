require 'sql_helper'
require 'parser'

class Message < ActiveRecord::Base
  extend SqlHelper
  has_many :recipients, :primary_key => :number, :foreign_key => :number

  DEFAULT_LIMIT = 20
  DEFAULT_OFFSET = 0
  
  def self.load(file)
    messages = PostfixLogParser.load(File.join(Rails.root, 'mail.log'))
    Message.execute_db_update!(messages)
  end

  # why bother joining messages table, the recipients alone is not enough?
  def self.domain_by(status, params)
    last_30_days_end = (DateTime.parse(params[:to]) - 1.days)
    last_30_days_start = last_30_days_end - 30.days
    
    # @todo Khi count phải bỏ mấy thằng null!!!!!!!!!

    sql = %Q{
      SELECT t1.*, t2.*, (percentage-percentage_30) AS change FROM
      (
        SELECT msg.recipient_domain AS domain, count(msg.id) as volume, round(count(*)::numeric * 100 / (select count(*) FROM messages), 2) as percentage
        FROM messages msg
        WHERE msg.status = :status AND #{conditions_from_params(params)} 
          AND msg.recipient_domain IS NOT NULL
        GROUP BY msg.recipient_domain
        LIMIT :limit OFFSET :offset
      ) t1
      LEFT JOIN
      (
        SELECT msg.recipient_domain AS domain, count(msg.id) as volume_30, round(count(*)::numeric * 100 / (select count(*) FROM messages), 2) as percentage_30
        FROM messages msg
        WHERE msg.status = :status AND #{conditions_from_params(from: last_30_days_start, to: last_30_days_end)}
          AND msg.recipient_domain IS NOT NULL
        GROUP BY msg.recipient_domain
        LIMIT :limit OFFSET :offset
      ) t2
      ON t1.domain = t2.domain
      #{sorts_by_params(params.merge(default_order: 'volume DESC'))}
    }

    count_sql = %Q{
      SELECT COUNT(*) FROM
      ( 
        SELECT msg.recipient_domain
        FROM messages msg
        WHERE msg.status = :status AND #{conditions_from_params(params)}
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
      SELECT * FROM
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
        LIMIT :limit OFFSET :offset
      ) t1 
      
      LEFT JOIN 
      (
        SELECT recipient_domain,
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
        LIMIT :limit OFFSET :offset
      ) t2 
      
      ON t1.recipient_domain = t2.recipient_domain
      #{sorts_by_params(params)}
    }

    count_sql = 'SELECT COUNT(*) FROM (SELECT DISTINCT recipient_domain FROM messages) tmp'
    data = self.find_by_sql([sql, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql([count_sql])
    return data, count
  end

  def self.users_by_domain(domain, params = {})
    p params, "AAAAAAAAAAAA"
    
    last_30_days_end = (DateTime.parse(params[:to]) - 1.days)
    last_30_days_start = last_30_days_end - 30.days

    sql = %Q{
      SELECT * FROM
      (
        SELECT recipient,
               COUNT(*) sent,
               SUM(case status when 'sent' then 1 else 0 end) AS delivered,
               SUM(case status when 'rejected' then 1 else 0 end) AS rejected,
               SUM(case status when 'bounced' then 1 else 0 end) AS bounced,
               round(SUM(case status when 'sent' then 1 else 0 end)::numeric * 100 / count(*), 2) AS success_rate
        FROM messages 
        WHERE recipient_domain = :domain AND #{conditions_from_params(params)}
        GROUP BY recipient
        LIMIT :limit OFFSET :offset
      ) t1 
      
      LEFT JOIN 
      
      (
        SELECT recipient,
               COUNT(*) sent_30,
               SUM(case status when 'sent' then 1 else 0 end) AS delivered_30,
               SUM(case status when 'rejected' then 1 else 0 end) AS rejected_30,
               SUM(case status when 'bounced' then 1 else 0 end) AS bounced_30,
               round(SUM(case status when 'sent' then 1 else 0 end)::numeric * 100 / count(*), 2) AS success_rate_30
        FROM messages 
        WHERE recipient_domain = :domain AND #{conditions_from_params(from: last_30_days_start, to: last_30_days_end)}
        GROUP BY recipient
        LIMIT :limit OFFSET :offset
      ) t2 
      
      ON t1.recipient = t2.recipient
      #{sorts_by_params(params)}
    }

    count_sql = 'SELECT COUNT(*) FROM (SELECT DISTINCT recipient FROM messages WHERE recipient_domain = :domain) tmp'
    data = self.find_by_sql([sql, domain: domain, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql([count_sql, domain: domain])
    return data, count
  end

  def self.details_by_domain(domain, params = {})
    sql = %Q{
      SELECT * FROM (
        SELECT DISTINCT ON(recipient) * 
        FROM messages
        WHERE recipient_domain = :domain AND #{conditions_from_params(params)}
        LIMIT :limit OFFSET :offset
      ) tmp
      #{sorts_by_params(params)}
    }



    count_sql = 'SELECT COUNT(DISTINCT recipient) FROM messages WHERE recipient_domain = :domain'
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

    p params, "SORRRRRRRRRRRRRRRRRRRRRRRRRR"
    p sort_by

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

    if params[:from]
      from = params[:from].is_a?(String) ? DateTime.parse(params[:from]) : params[:from]
      if params[:to]
        to = params[:to].is_a?(String) ? DateTime.parse(params[:to]) + 1.days : params[:to]
        conditions = "datetime >= #{conn.quote(from)} AND datetime < #{conn.quote(to)}"
      else
        conditions = "datetime >= #{conn.quote(from)}"
      end
    else
      conditions = "TRUE"
    end
    p "CONDITIONS***********", conditions
    return conditions
  end
end
