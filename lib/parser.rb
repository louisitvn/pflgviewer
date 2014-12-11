class PostfixLogParser
  NOQUEUE = 'NOQUEUE'
  LABELS = [ NOQUEUE ]

  def self.load(file)
    messages = {}
    others = []

    File.open(file).each_with_index do |line, index|
      id = extract_id(line)
      
      # dòng nào không có ID thì ignore
      # For example, just ignore the following
      #   Dec 11 10:52:03 phoenix postfix/smtpd[30134]: disconnect from OURMAILDOMAIN.com
      #   Dec 11 10:52:05 phoenix postfix/smtpd[30134]: connect from OURMAILDOMAIN.com
      #   Dec 11 10:52:05 phoenix postfix/smtpd[30134]: disconnect from OURMAILDOMAIN.com
      next if id.nil?
      
      # nếu entry có dạng: NOQUEUE: reject thì add tạm vào 1 array
      # Sau này sẽ add vào 1 dòng message và 1 dòng recipient (rejected)
      if LABELS.include?(id)
        others << line
      end

      # trường hợp bình thường
      messages[id] ||= []
      messages[id] << line

      # break if index > 100
    end

    # duyệt qua lần 2, add các dòng recipients tương ứng
    messages_insert_queue = []
    recipients_insert_queue = []
    
    messages.each do |number, lines|
      msg = {}

      msg[:sender] = lines.join(" ")[/(?<=from=)<{0,1}[a-z0-9][a-z0-9_\.]+@[a-z0-9][a-z0-9_\.\-]+\.[a-z0-9_\.\-]+>{0,1}/i]
      msg[:domain] = msg[:sender] ? msg[:sender][/(?<=@).*/] : nil
      msg[:number] = number
      messages_insert_queue << msg
      lines.each { |line|
        rcpt = {}
        rcpt[:recipient] = line[/(?<=to=)<{0,1}[a-z0-9][a-z0-9_\.]+@[a-z0-9][a-z0-9_\.\-]+\.[a-z0-9_\.\-]+>{0,1}/i]
        rcpt[:status] = line[/(?<=status=)[a-z0-9]+/]
        rcpt[:domain] = rcpt[:recipient][/(?<=@).*/] if rcpt[:recipient]
        rcpt[:number] = msg[:number]

        if rcpt[:recipient] and rcpt[:status]
          recipients_insert_queue << rcpt
        end
      }
    end
    
    # Others: line with no message ID
    others.each do |line|
      id = extract_id(line)
      if id == NOQUEUE
        # extract from, to, reject
      else
        p line
        raise
      end
    end

    # p messages_insert_queue
    # p recipients_insert_queue

    return [messages_insert_queue, recipients_insert_queue]
  end

  def self.extract_id(line)
    line[/(?<=\]:\s)[A-Z0-9]+(?=:)/]
  end
end

# a,b = PostfixLogParser.load('/tmp/postfix.log')

