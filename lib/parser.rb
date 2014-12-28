require 'date'

class PostfixLogParser
  NOQUEUE = 'NOQUEUE'

  def self.load(file)
    messages = []

    File.readlines(file).each_with_index do |line, index|
      number = extract_id(line)

      msg = {}
      
      # dòng nào không có ID thì ignore
      # For example, just ignore the following
      #   Dec 11 10:52:03 phoenix postfix/smtpd[30134]: disconnect from OURMAILDOMAIN.com
      #   Dec 11 10:52:05 phoenix postfix/smtpd[30134]: connect from OURMAILDOMAIN.com
      #   Dec 11 10:52:05 phoenix postfix/smtpd[30134]: disconnect from OURMAILDOMAIN.com
      next if number.nil?
      
      # nếu entry có dạng: NOQUEUE: reject thì add tạm vào 1 array
      # Sau này sẽ add vào 1 dòng message và 1 dòng recipient (rejected)
      msg[:number] = number
      msg[:sender] = extract_email(line, 'from')
      msg[:sender_domain] = msg[:sender] ? msg[:sender][/(?<=@).*/] : nil
      msg[:recipient] = extract_email(line, 'to')
      msg[:recipient_domain] = msg[:recipient][/(?<=@).*/] if msg[:recipient]
      msg[:datetime] = DateTime.parse(line[0..14])

      if number == NOQUEUE
        msg[:status] = 'rejected'
      else
        msg[:status] = line[/(?<=status=)[a-z0-9]+/]
      end
      
      messages << msg
    end
    
    return messages
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

# a,b = PostfixLogParser.load('/home/nghi/mail.log')

