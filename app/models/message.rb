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
  def self.domain_by_deferred(params)
    sql = %Q{
      SELECT msg.recipient_domain AS domain, count(msg.id) as volume, round(count(*)::numeric * 100 / (select count(*) FROM messages), 2) as percentage
      FROM messages msg
      WHERE msg.status = 'deferred' AND #{conditions_from_params(params)}
      GROUP BY msg.recipient_domain
      ORDER BY count(msg.id) DESC
      LIMIT :limit OFFSET :offset
    }

    count_sql = %Q{
      SELECT COUNT(*) FROM
      ( 
        SELECT msg.recipient_domain
        FROM messages msg
        WHERE msg.status = 'deferred' AND #{conditions_from_params(params)}
        GROUP BY msg.recipient_domain
      ) tmp
    }

    data = self.find_by_sql([sql, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql(count_sql)
    return data, count
  end

  def self.domain_by_sent(params)
    sql = %Q{
      SELECT msg.recipient_domain AS domain, count(msg.id) as volume, round(count(*)::numeric * 100 / (select count(*) FROM messages), 2) as percentage
      FROM messages msg
      WHERE msg.status = 'sent' AND #{conditions_from_params(params)}
      GROUP BY msg.recipient_domain
      ORDER BY count(msg.id) DESC
      LIMIT :limit OFFSET :offset
    }

    count_sql = %Q{
      SELECT COUNT(*) FROM
      ( 
        SELECT msg.recipient_domain
        FROM messages msg
        WHERE msg.status = 'sent' AND #{conditions_from_params(params)}
        GROUP BY msg.recipient_domain
      ) tmp
    }
    
    data = self.find_by_sql([sql, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql(count_sql)
    return data, count
  end

  def self.domain_by_bounced(params)
    sql = %Q{
      SELECT msg.recipient_domain AS domain, count(msg.id) as volume, round(count(*)::numeric * 100 / (select count(*) FROM messages), 2) as percentage
      FROM messages msg
      WHERE msg.status = 'bounced' AND #{conditions_from_params(params)}
      GROUP BY msg.recipient_domain
      ORDER BY count(msg.id) DESC
      LIMIT :limit OFFSET :offset
    }

    count_sql = %Q{
      SELECT COUNT(*) FROM
      ( 
        SELECT msg.recipient_domain
        FROM messages msg
        WHERE msg.status = 'bounced' AND #{conditions_from_params(params)}
        GROUP BY msg.recipient_domain
      ) tmp
    }

    data = self.find_by_sql([sql, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql(count_sql)
    return data, count
  end

  def self.domain_by_rejected(params)
    sql = %Q{
      SELECT msg.recipient_domain AS domain, count(msg.id) as volume, round(count(*)::numeric * 100 / (select count(*) FROM messages), 2) as percentage
      FROM messages msg
      WHERE msg.status = 'rejected' AND #{conditions_from_params(params)}
      GROUP BY msg.recipient_domain
      ORDER BY count(msg.id) DESC
      LIMIT :limit OFFSET :offset
    }

    count_sql = %Q{
      SELECT COUNT(*) FROM
      ( 
        SELECT msg.recipient_domain
        FROM messages msg
        WHERE msg.status = 'rejected' AND #{conditions_from_params(params)}
        GROUP BY msg.recipient_domain
      ) tmp
    }

    data = self.find_by_sql([sql, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql(count_sql)
    return data, count
  end

  def self.users_by_domain(domain, params = {})
    sql = %Q{
      SELECT recipient,
             SUM(case status when 'rejected' then 1 else 0 end) AS rejected,
             SUM(case status when 'sent' then 1 else 0 end) AS sent,
             SUM(case status when 'deferred' then 1 else 0 end) AS deferred,
             SUM(case status when 'bounced' then 1 else 0 end) AS bounced
      FROM messages 
      WHERE recipient_domain = :domain AND #{conditions_from_params(params)}
      GROUP BY recipient_domain, recipient
      LIMIT :limit OFFSET :offset
    }

    p params
    p sql
    p "------------------"

    count_sql = 'SELECT COUNT(*) FROM (SELECT DISTINCT recipient FROM messages WHERE recipient_domain = :domain) tmp'
    data = self.find_by_sql([sql, domain: domain, limit: params[:length] || DEFAULT_LIMIT, offset: params[:start] || DEFAULT_OFFSET ])
    count = self.count_by_sql([count_sql, domain: domain])
    return data, count
  end

  def self.search(args)
    # extract information from parameters
    _start = args[:start] || 0
    _length = args[:length] || 20
    _search = (args[:search] && args[:search][:value]) ? args[:search][:value] : ""
    _manufacturers = (args[:filter] && args[:filter][:manufacturers]) ? args[:filter][:manufacturers] : nil
    _sort_field = args[:columns][ args[:order]["0"][:column] ][:name]
    _sort_order = args[:order]["0"][:dir]
    _sort_by = "#{_sort_field} #{_sort_order}" unless _sort_field.empty?
    
    # count the total
    total_items = self.where(['part_number ILIKE :search OR manufacturer_name ILIKE :search', { search: "%#{_search}%" }])
    # filter by manufacturers
    total_items = total_items.where('manufacturer_name in (?)', _manufacturers) if _manufacturers
    # Sort
    total_items = total_items.order(_sort_by) if _sort_by

    # get total
    # **** note **** order is important, be careful when moving this line
    total = total_items.count

    # distinct list of manufacturers
    manufacturers = total_items.map{|item| item.manufacturer_name }.uniq

    # extract items for one paticular page
    items = total_items.limit(_length).offset(_start)
    
    return { 
      items: items,
      manufacturers: manufacturers,
      recordsFiltered: total,
      search: _search
    }
  end

  private
  def self.to_count_sql(sql)
    sql.strip.gsub(/SELECT.*(?=FROM)/m, "SELECT COUNT(*) ").gsub(/LIMIT.*/m, "").strip
  end

  def self.conditions_from_params(params)
    # @note FROM/TO are in the date format of yyyy/mm/dd
    
    params = params.symbolize_keys
    conn = self.connection

    if params[:from]
      p params[:from]
      from = DateTime.parse(params[:from])
      p from
      p "truoc va sau"
      if params[:to]
        to = DateTime.parse(params[:to]) + 1.days
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
