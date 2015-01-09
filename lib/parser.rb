#!/bin/env ruby
require 'date'
require 'time'
require 'optparse'
require 'rubygems'
require 'active_record'
require 'mechanize'
require 'rails'

$options = {}
parser = OptionParser.new("", 24) do |opts|
  opts.banner = "Postfix Log Parser\n\n"

  opts.on("-p", "--path PATH", "Path to the directory containing the log files (/var/log/ for example)") do |v|
    $options[:path] = v
  end

  opts.on("-n", "--name FILENAME", "Primary file name (mail.log for example)") do |v|
    $options[:name] = v
  end

  opts.on("-l", "--log LOG", "") do |v|
    $options[:log] = v
  end

  opts.on("--block-size SIZE", "") do |v|
    $options[:block_size] = v
  end

  opts.on_tail('-h', '--help', 'Displays this help') do
		puts opts
    exit
	end
end


# Input Validation
parser.parse!

if $options[:path].nil?
  puts "\nPlease specify path: -p\n\n"
  exit
end

if !File.exists?($options[:path])
  puts "Path #{$options[:path]} does not exist"
end

if $options[:name].nil?
  puts "\nPlease specify file name: -n\n\n"
  exit
end

$options[:log] ||= '/tmp/pflgparser.log'

$logger = Logger.new($options[:log])

$options[:block_size] ||= 10000
$options[:block_size] = $options[:block_size].to_i

raise "DATABASE_URL not set" unless ENV['DATABASE_URL']

# Establish connections
ActiveRecord::Base.establish_connection(
  ENV['DATABASE_URL']
)

module SqlHelper
  SQL_BATCH_SIZE = $options[:block_size]
  
  def execute_db_update!(objects)
    @last_executed_at = Time.now
    unless objects.is_a? Array
      raise 'The input objects must be an array of ActiveRecord::Base objects or hashes'
    end
    
    return nil if objects.blank?

    $logger.info "#{objects.size} message(s) loaded"
    t = Time.now
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

    $logger.info "execution time: #{Time.now - t}"
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

class Message < ActiveRecord::Base
  extend SqlHelper
end

class PostfixLogParser
  NOQUEUE = 'NOQUEUE'

  def self.run
    $logger.info('-------------------------------------------')
    $logger.info('START')
    lasttime = Message.maximum(:datetime)
    $logger.info("Loading entries from #{lasttime}")

    # Check for every log file mail.log.1, mail.log.2, etc... until there is an entry that is 
    (1..100).to_a.map{|e| ".#{e}"}.insert(0, "").each do |i|
      fullpath = File.join($options[:path], $options[:name] + i.to_s)
      break unless File.exists?(fullpath)

      $logger.info "Scanning #{fullpath}"

      load(fullpath, lasttime)
    end
    $logger.info('DONE')
    $logger.info('-------------------------------------------')
  end

  def self.load(fullpath, lasttime = nil)
    messages = []
    currtime = Time.now
        
    file = File.open(fullpath, 'r')
    while !file.eof?
      line = file.readline
      
      begin
        datetime = Time.parse(line[0..14] + " UTC")
      rescue Exception => ex
        next
      end

      next unless datetime

      # case: previous year!
      if datetime - currtime > 2592000 # 60 * 60 * 24 * 30 ~> 30 days
        datetime = datetime - 1.years
      end

      # stop at this file if any line of the file is already imported
      if lasttime and datetime <= lasttime
        next
      end

      msg = {}
      number = extract_id(line)
      
      # dòng nào không có ID thì ignore
      # For example, just ignore the following
      #   Dec 11 10:52:03 phoenix postfix/smtpd[30134]: disconnect from OURMAILDOMAIN.com
      #   Dec 11 10:52:05 phoenix postfix/smtpd[30134]: connect from OURMAILDOMAIN.com
      #   Dec 11 10:52:05 phoenix postfix/smtpd[30134]: disconnect from OURMAILDOMAIN.com
      next if number.nil?
      
      # nếu entry có dạng: NOQUEUE: reject thì add tạm vào 1 array
      # Sau này sẽ add vào 1 dòng message và 1 dòng recipient (rejected)
      msg[:number] = number
      msg[:size] = line[/(?<=size=)[0-9]+/]
      msg[:sender] = extract_email(line, 'from')
      msg[:sender_domain] = msg[:sender] ? msg[:sender][/(?<=@).*/] : nil
      msg[:recipient] = extract_email(line, 'to')
      msg[:recipient_domain] = msg[:recipient][/(?<=@).*/] if msg[:recipient]
      msg[:datetime] = datetime
      msg[:status_code] = line[/(?<=[\( ])[0-9]{3}(?= )/]
      msg[:relay] = line[/(?<=relay=)[a-zA-Z0-9\-_\.]+/]

      if number == NOQUEUE
        msg[:status] = 'rejected'
        msg[:status_message] = line[/Relay access denied/]
      else
        msg[:status] = line[/(?<=status=)[a-z0-9]+/]
        msg[:status_message] = line[/(?<=\().*(?=\))/]
      end
      
      messages << msg
    end
    
    Message.execute_db_update!(messages)
  end
  
  # helper
  def self.extract_id(line)
    line[/(?<=\]:\s)[A-Z0-9]+(?=:)/]
  end

  def self.extract_email(line, type)
    raise "type must be either 'from' or 'to'" unless ['from', 'to'].include?(type)

    email = line[/(?<=to=)<{0,1}[a-z0-9][a-z0-9_\.]+@[a-z0-9][a-z0-9_\.\-]+\.[a-z0-9_\.\-]+>{0,1}/i] if type == 'to'
    email = line[/(?<=from=)<{0,1}[a-z0-9][a-z0-9_\.]+@[a-z0-9][a-z0-9_\.\-]+\.[a-z0-9_\.\-]+>{0,1}/i] if type == 'from'

    return email.gsub(/[^a-zA-Z0-9\-\_\.@]/, "").downcase if email
  end
end

PostfixLogParser.run