# frozen_string_literal: true

class Matrix
  def self.get(server, token, method, _data)
    uri = URI("#{server}client/r0/#{method}?access_token=#{token}")
    begin
      JSON.parse(Net::HTTP.get(uri))
    rescue SocketError
      { errcode: 'NOT_FOUND', error: 'Server not found!' }
    rescue JSON::ParserError
      { errcode: 'JSON_PARSE_ERROR', error: 'Json response unrecognized!' }
    end
  end

  def self.post(server, token, method, data)
    uri = URI("#{server}client/r0/#{method}?access_token=#{token}")
    res = Net::HTTP.post(uri, data.to_json)
    res.body
  end

  # https://matrix.org/docs/spec/client_server/r0.6.1#mxc-uri
  def self.upload(server, token, filename, content_type, data)
    full_url = "#{server}media/r0/upload?access_token=#{token}&filename=#{filename}"

    # cyrillic symbols fix
    begin
      uri = URI(full_url)
    rescue URI::InvalidURIError
      uri = URI.parse(Addressable::URI.escape(full_url))
    end

    req = Net::HTTP::Post.new(uri, { 'Content-Type' => content_type })
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    res = https.request(req, data)
    res.body if res.msg == 'OK'
  end

  def self.download(server, token, file_server, file_id, _data)
    full_url = "#{server}media/r0/download/#{file_server}/#{file_id}?access_token=#{token}"

    # cyrillic symbols fix
    begin
      file = URI.parse(full_url).open
    rescue URI::InvalidURIError
      file = URI.parse(Addressable::URI.escape(full_url))
    end

    file
  end
end
