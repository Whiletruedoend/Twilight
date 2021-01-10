class Matrix

  def self.post(token, method, data)
    matrix_url = Rails.configuration.credentials[:matrix][:server]

    uri = URI("#{matrix_url}client/r0/#{method}?access_token=#{token}")
    res = Net::HTTP.post(uri, data.to_json)
    res.body
  end

  # https://matrix.org/docs/spec/client_server/r0.6.1#mxc-uri
  def self.upload(token, filename, content_type, data)
    matrix_url = Rails.configuration.credentials[:matrix][:server]
    full_url = "#{matrix_url}media/r0/upload?access_token=#{token}&filename=#{filename}"

    begin # cyrillic symbols fix
      uri = URI(full_url)
    rescue URI::InvalidURIError
      uri = URI.parse(URI.escape(full_url))
    end

    req = Net::HTTP::Post.new(uri, {'Content-Type' =>content_type})
    https = Net::HTTP.new(uri.host,uri.port)
    https.use_ssl = true
    res = https.request(req, data)
    res.body if res.msg == "OK"
  end

end