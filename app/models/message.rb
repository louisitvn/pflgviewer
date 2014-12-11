require 'sql_helper.rb'

class Message < ActiveRecord::Base
  extend SqlHelper

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
end
