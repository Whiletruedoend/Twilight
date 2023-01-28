socks_proxy = Rails.configuration.credentials[:socks_proxy]
if socks_proxy[:socks_proxy_enabled] || ENV['SOCKS_SERVER']
    require 'socksify'
    TCPSocket.socks_server = socks_proxy[:socks_server] || ENV['SOCKS_SERVER']
    TCPSocket.socks_port = socks_proxy[:socks_port] || ENV['SOCKS_PORT']
    TCPSocket.socks_username = socks_proxy[:socks_username] || ENV['SOCKS_USERNAME']
    TCPSocket.socks_password = socks_proxy[:socks_password] || ENV['SOCKS_PASSWORD']
  end