# frozen_string_literal: true

class Platform::UpdateMatrixComments
  prepend SimpleCommand

  attr_accessor :comms, :user, :text

  def initialize(comms, user, text)
    @comms = comms
    @user = user
    @text = text
  end

  def call
    print("NOT IMPLEMENTED YET!")
  end
end
# Not used