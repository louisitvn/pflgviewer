require 'sql_helper'
require 'parser'

class Message < ActiveRecord::Base
  extend SqlHelper
  has_many :recipients, :primary_key => :number, :foreign_key => :number

  def self.load(file)
    messages, recipients = PostfixLogParser.load('/tmp/postfix.log')
    Message.execute_db_update!(messages)
    Recipient.execute_db_update!(recipients)
  end

  # why bother joining messages table, the recipients alone is not enough?
  def self.domain_by_deferred(params)
    sql = %Q{
      SELECT rcpt.domain, count(rcpt.id) as volume, round(count(*)::numeric * 100 / (select count(*) from recipients), 2) as percentage
      FROM recipients rcpt
      WHERE rcpt.status = 'deferred' AND #{conditions_from_params(params)}
      GROUP BY rcpt.domain
      ORDER BY count(rcpt.id) DESC
      LIMIT :limit OFFSET :offset
    }

    a =  self.find_by_sql([sql, limit: params[:limit], offset: params[:offset] ])
    p a.count, "COOOOOOOOOOOOOOOOOOOO"
    return a
  end

  def self.domain_by_sent(params)
    sql = %Q{
      SELECT rcpt.domain, count(rcpt.id) as volume, round(count(*)::numeric * 100 / (select count(*) from recipients), 2) as percentage
      FROM recipients rcpt
      WHERE rcpt.status = 'sent' AND #{conditions_from_params(params)}
      GROUP BY rcpt.domain
      ORDER BY count(rcpt.id) DESC
      LIMIT :limit OFFSET :offset
    }
    return self.find_by_sql([sql, limit: params[:limit], offset: params[:offset] ])
  end

  def self.domain_by_bounced(params)
    sql = %Q{
      SELECT rcpt.domain, count(rcpt.id) as volume, round(count(*)::numeric * 100 / (select count(*) from recipients), 2) as percentage
      FROM recipients rcpt
      WHERE rcpt.status = 'bounced' AND #{conditions_from_params(params)}
      GROUP BY rcpt.domain
      ORDER BY count(rcpt.id) DESC
      LIMIT :limit OFFSET :offset
    }

    return self.find_by_sql([sql, limit: params[:limit], offset: params[:offset] ])
  end

  def self.domain_by_rejected(params)
    sql = %Q{
      SELECT rcpt.domain, count(rcpt.id) as volume, round(count(*)::numeric * 100 / (select count(*) from recipients), 2) as percentage
      FROM recipients rcpt
      WHERE rcpt.status = 'rejected' AND #{conditions_from_params(params)}
      GROUP BY rcpt.domain
      ORDER BY count(rcpt.id) DESC
      LIMIT :limit OFFSET :offset
    }

    return self.find_by_sql([sql, limit: params[:limit], offset: params[:offset] ])
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
    

    p _manufacturers, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

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
  def self.conditions_from_params(params)
    # @note FROM/TO are in the date format of yyyy/mm/dd
    
    params = params.symbolize_keys
    conn = self.connection

    if params[:from]
      from = DateTime.parse(params[:from])
      
      if params[:to]
        to = DateTime.parse(params[:to]) + 1.days
        conditions = "datetime >= #{conn.quote(from)} AND datetime < #{conn.quote(to)}"
      else
        conditions = "datetime >= #{conn.quote(from)}"
      end
    else
      conditions = []
    end
    p "CONDITIONS***********", conditions
    return conditions
  end
end
