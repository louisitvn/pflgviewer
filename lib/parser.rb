class PostfixLogParser
  def initialize(file, options ={})
    $options = options
    load(file)
    p test()
  end

  def test
    ketqua = @data.map {|k,v|
      check(v)
    }

    sent = ketqua.select do |i|
      !i[:recipients].select{|e| e[:status] == 'sent'}.empty?
    end
    
    return sent.count
  end

  def data
    @data
  end

  private
  def check(array)
    # attrs = {type: 'rejected', from: nil, to: nil, send_domain: nil, receive_domain: nil}
    attrs = {}

    attrs[:from] = array.join(" ")[/(?<=from=)<{0,1}[a-z0-9][a-z0-9_\.]+@[a-z0-9][a-z0-9_\.\-]+\.[a-z0-9_\.\-]+>{0,1}/i]
    attrs[:domain] = attrs[:from][/(?<=@).*/] if attrs[:from]
    attrs[:recipients] = array.select { |line| 
      line[/(?<=to=)<{0,1}[a-z0-9][a-z0-9_\.]+@[a-z0-9][a-z0-9_\.\-]+\.[a-z0-9_\.\-]+>{0,1}/i] 
    }.map { |line|
      { 
        to: line[/(?<=to=)<{0,1}[a-z0-9][a-z0-9_\.]+@[a-z0-9][a-z0-9_\.\-]+\.[a-z0-9_\.\-]+>{0,1}/i],
        status: line[/(?<=status=)[a-z0-9]+/],
      }
    }.map { |h|
      h.merge(
        domain: h[:to] ? h[:to][/(?<=@).*/] : nil
      )
    }

    if attrs[:recipients].count > 1
      #p attrs
      #puts "---------------"
    end
    
    return attrs
  end

  def load(file)
    @data = {}
    File.open(file).each_with_index do |line, index|
      id = line[/(?<=\]:\s)[A-Z0-9]+(?=:)/]
      next if id == 'NOQUEUE'
      
      if id.nil? 
        # puts line
      end

      if !id.nil? && line.include?('to=') && !line.include?('status=')
        p line
        raise
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
