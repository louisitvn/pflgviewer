json.array!(@data_files) do |data_file|
  json.extract! data_file, :id, :name, :description, :status
  json.url data_file_url(data_file, format: :json)
end
