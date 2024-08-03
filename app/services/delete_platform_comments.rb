# frozen_string_literal: true

class DeletePlatformComments
  prepend SimpleCommand

  attr_accessor :comments

  def initialize(comments)
    @comments = comments
  end

  def call
    comments.group_by(&:platform).each do |pl, comms|
      if pl.present? && pl.title == "telegram"
        delete_comments("telegram", comms)
      elsif pl.present? && pl.title == "matrix"
        delete_comments("matrix", comms)
      end
    end
  end

  def delete_comments(platform_title, comms)
    Thread.new do
      execution_context = Rails.application.executor.run!
      if platform_title == "telegram"
        Platform::DeleteTelegramComments.call(comms)
      elsif platform_title == "matrix"
        Platform::DeleteMatrixComments.call(comms)
      end
    ensure
      execution_context&.complete!
    end
  end
end
