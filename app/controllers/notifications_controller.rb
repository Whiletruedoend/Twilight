class NotificationsController < ApplicationController
  before_action :authenticate_user!

  # Not used. For now.
  #def index
  #  @notifications = current_user.notifications
    #@notifications.update(viewed: true)
  #end

  def view
    authorize! current_notification, to: :view?

    current_notification.update(viewed: true) if current_notification.present?
    
    ref_url = request.referrer
    redirect_to ref_url
  end
end
