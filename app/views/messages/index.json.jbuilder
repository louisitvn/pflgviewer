json.array!(@messages) do |message|
  json.extract! message, :id, :number, :sender, :domain, :size
  json.url message_url(message, format: :json)
end
