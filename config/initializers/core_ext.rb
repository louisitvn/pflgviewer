class Object
  def clean_email
    if self.is_a? String
      return self.gsub(/[^a-zA-Z0-9\-\_\.@]/, "").downcase
    else
      return self
    end
  end
end