module SqlHelper
  SQL_BATCH_SIZE = 10_000
  
  # Delete items that satisfy a hash of conditions
  # For example
  #    Item.bulk_delete({id: [1,2,3,4], name: ['Dummy', 'Suck', 'NULL']})
  # Note: OR condition
  # @author Nghi P.
  def bulk_delete!(conditions)
    raise 'Parameter must be a Hash' unless conditions.is_a?(Array)
    logger.info "About to delete #{conditions.count} items"
    return self.where("id IN (?)", conditions).delete_all
  end

  def insert_by_sql(params)
    current_max_id = nil
    new_max_id = nil

    superclass.transaction do 
      current_max_id = self.maximum(:id)
      self.find_by_sql(params)
      new_max_id = self.maximum(:id)
    end
    
    if current_max_id.nil?
      return self.pluck(:id)
    else
      return *(current_max_id..new_max_id)
    end
  end
  
  def execute_db_update!(objects)
    @last_executed_at = Time.now
    unless objects.is_a? Array
      raise 'The input objects must be an array of ActiveRecord::Base objects or hashes'
    end
    
    return nil if objects.blank?

    puts "Bulk SQL INSERT/UPDATE FOR: #{t=Time.now; self.name} #{objects.size}"

    sql_strs = ["BEGIN"]
    last_index = objects.size - 1
    objects.each_with_index{|obj, index|
      sql_strs << self.to_sql(obj)
      if ( (index + 1) % SQL_BATCH_SIZE == 0) || (index == last_index)
        sql_strs << "COMMIT;"
        self.connection.execute(sql_strs.join(";"))
        sql_strs = ["BEGIN"]
      end
    }

    puts "DONE #{Time.now - t}"
    @last_executed_at
  end

  # object can be a Hash object or a ActiveRecord::Base object
  def to_sql(object, table_name = self.quoted_table_name)
    return object.to_sql if object.is_a? ActiveRecord::Base
    # else object is a hash, build sql string
    if object['id'].blank? && object[:id].blank?
      object.delete(:id)
      object.delete('id')
      to_sql_insert(object, table_name = self.quoted_table_name)
    else
      object['id'] = object[:id] unless object['id']
      object.delete(:id)
      to_sql_update(object, table_name = self.quoted_table_name)
    end
  end

  def to_sql_insert(attrs, table_name = self.quoted_table_name)
    return '' if attrs.blank?
    con = self.connection
    fields = []
    values = []

    attrs.each do |attr, value|
      col =  self.columns_hash[attr.to_s]
      next unless col
      fields << "\"#{attr}\""
      values << con.quote(value, col)
    end

    ['created_at', 'updated_at'].each do |f|
      if self.columns_hash.has_key?(f)
        fields << "\"#{f}\""
        values << con.quote(@last_executed_at, self.columns_hash[f])
      end
    end
    "INSERT INTO #{table_name} (#{fields.join(',')}) VALUES(#{values.join(',')})"
  end

  #Generate SQL Update statement
  def to_sql_update(attrs,  table_name = self.quoted_table_name)
    return '' if attrs['id'].blank?
    id = attrs.delete('id')
    return '' if attrs.blank?

    con = self.connection
    fields = []
    attrs.each do |attr, value|
      col =  self.columns_hash[attr.to_s]
      next unless col
      fields << "\"#{attr}\"=#{con.quote(value, col)}"
    end

    updated_at_col = self.columns_hash['updated_at']
    fields << "\"updated_at\"=#{con.quote(@last_executed_at, updated_at_col)}" if updated_at_col

    key_col = self.columns_hash[self.primary_key]
    key_value = con.quote(id, key_col)

    "UPDATE #{table_name} SET #{fields.join(",")} WHERE #{key_col.name}=#{key_value}"
  end

end
