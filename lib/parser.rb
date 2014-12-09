class PostfixLogParser
  def initialize(file, options ={})
    $options = options
    load(file)
    test()
  end

  def test
    p @data.map {|k,v|
      check(v)
    }.select{|e| !e[:from].nil? && !e[:to].nil? && !e[:status].empty?}
  end

  def data
    @data
  end

  private
  def check(array)
    # attrs = {type: 'rejected', from: nil, to: nil, send_domain: nil, receive_domain: nil}
    attrs = {}

    attrs[:from] = array.join(" ")[/from=[^\s]+@[^\s]+/]
    attrs[:to] = array.join(" ")[/to=[^\s]+@[^\s]+/]
    attrs[:status] = array.join(" ").scan(/\s(rejected|bounced|sent)\s/)
    return attrs
  end

  def load(file)
    @data = {}
    File.open(file).each_with_index do |line, index|
      id = line[/(?<=\]:\s)[A-Z0-9]+(?=:)/]
      
      if id.nil? 
        # puts line
      end
      
      if id
        @data[id] = [] if data[id].nil?
        @data[id] << line
      end

      # break if index > 100
    end
  end
end

ps = PostfixLogParser.new('/tmp/postfix.log')
ps.test