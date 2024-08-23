# frozen_string_literal: true

class Platform::DeleteMatrixComments
  prepend SimpleCommand

  attr_accessor :comms

  def initialize(comms)
    @comms = comms
  end

  def call
    @comms.each do |comm|
      matrix_token = comm.channel.token
      server = comm.channel.options['server']
      begin
        # Matrix onlylink is a Hash, but attachments is an Array.
        if comm.has_attachments? && comm.identifier.is_a?(Hash)
          comm.identifier.each do |att|
            method = "rooms/#{att['room_id']}/redact/#{att['event_id']}"
            data = { reason: "Delete comment ##{comm.id}" }
            Matrix.post(server, matrix_token, method, data)
          end
        else
          method = "rooms/#{comm.identifier['room_id']}/redact/#{comm.identifier['event_id']}"
          data = { reason: "Delete comment ##{comm.id}" }
          Matrix.post(server, matrix_token, method, data)
        end
      rescue StandardError
        Rails.logger.error("Failed to delete matrix comments at #{Time.now.utc.iso8601}".red)
      end
    end
  end
end
