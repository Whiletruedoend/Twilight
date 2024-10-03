# frozen_string_literal: true

class UploadsController < ApplicationController
  protect_from_forgery except: :index
  before_action :authenticate_user!

  include ActionView::Helpers::NumberHelper

  def index
    authorize! current_user, to: :view_file_uploads?
  end

  def create
    authorize! current_user, to: :file_upload?

    path = ''
    upload_file(path)
    return render template: "posts/new"
  end

  def show
    upload = Upload.find_with_slug(params[:id])
    return if !upload.present?
    authorize! current_upload

    path = upload.path

    absolute_path = helpers.check_path_exist(path)
    
    if File.directory?(absolute_path)
      helpers.populate_directory(absolute_path, "#{path}/")
      render :index
    elsif File.file?(absolute_path)
      if File.size(absolute_path) > 1_000_000 || params[:download]
        send_file absolute_path
      else
        @file = File.read(absolute_path)
        render :file, formats: :html
      end
    end
  end

  def destroy
    authorize! current_upload

    absolute_path = helpers.check_path_exist(params[:path])
    if File.directory?(absolute_path)
      FileUtils.rm_rf(absolute_path)
    else
      FileUtils.rm(absolute_path)
    end
    head 204
    super
  end

  def upload_file(path)
    absolute_path = helpers.check_path_exist(path)
    raise ActionController::ForbiddenError unless File.directory?(absolute_path)
    input_file = params[:upload][:file]
    if input_file
      filename = input_file.original_filename#.html_safe
      Upload.create!(path: filename, user: current_user)
      File.open(Rails.root.join(absolute_path, input_file.original_filename), 'wb') do |file|
        file.write(input_file.read)
      end
    end
  end

  def rename
    authorize! current_upload
    
    absolute_path = helpers.check_path_exist(params[:path])
    new_path = helpers.safe_expand_path(params[:new_name])
    if File.exist?(new_path)
      head 403
    else
    parent = new_path.split('/')[0..-2].join('/')
      FileUtils.mkdir_p(parent)
      FileUtils.mv(absolute_path, new_path)
      head 204
    end
  end

  #def upload_index
  #  upload_file('')
  #  upload_path = Rails.configuration.credentials[:upload_path]
  #  helpers.populate_directory(upload_path, '')
  #  render :index
  #end
end