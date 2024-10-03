# frozen_string_literal: true

class UploadsController < ApplicationController
  protect_from_forgery except: :index
  before_action :authenticate_user!, except: %i[show]

  include ActionView::Helpers::NumberHelper

  def index
    authorize! current_user, to: :view_file_uploads?
  end

  def create
    authorize! current_user, to: :file_upload?

    if params.dig("upload", "file").nil?
      return render template: "uploads/file_explorer", locals: { current_url: "#{current_user.id}" }
    end

    path = "#{current_user.id}/"
    upload_file(path)
    return render template: "uploads/file_explorer", locals: { current_url: "#{current_user.id}" }
  end

  def show
    authorize! current_upload
    return if !current_upload.present?

    path = "#{current_upload.user_id}/#{current_upload.path}"
    absolute_path = helpers.check_path_exist(path)

    if File.directory?(absolute_path)
      helpers.populate_directory(absolute_path)
      render :index
    elsif File.file?(absolute_path)
      extname = File.extname(absolute_path)[1..-1]
      mime_type = Mime::Type.lookup_by_extension(extname)
      content_type = mime_type.to_s unless mime_type.nil?
      content_type = File.extname(absolute_path)[1..-1].to_s unless content_type.present?

      render :file => absolute_path, :content_type => content_type
    end
  end

  def destroy
    authorize! current_upload
    return if !current_upload.present?

    path = "#{current_upload.user_id}/#{current_upload.path}"

    absolute_path = helpers.check_path_exist(path)
    if File.directory?(absolute_path)
      FileUtils.rm_rf(absolute_path)
    else
      FileUtils.rm(absolute_path)
    end
    current_upload.destroy!

    return render template: "uploads/file_explorer", locals: { current_url: "#{current_user.id}" }
  end

  def upload_file(path)
    absolute_path = helpers.check_path_exist(path)
    raise ActionController::ForbiddenError unless File.directory?(absolute_path)
    input_file = params[:upload][:file]
    if input_file
      filename = input_file.original_filename#.html_safe
      upload = Upload.find_by(path: filename)
      Upload.create!(path: filename, user: current_user) unless upload.present?
      File.open(Rails.root.join(absolute_path, input_file.original_filename), 'wb') do |file|
        file.write(input_file.read)
      end
    end
  end

  def rename
    authorize! current_upload

    if params.dig("new_name").nil? # double put (ruby+js), don't touch this (only for fix (:)
      return render template: "uploads/file_explorer", locals: { current_url: "#{current_user.id}" }
    end

    path = "#{current_upload.user_id}/#{current_upload.path}"
    npath = "#{current_upload.user_id}/#{params[:new_name]}"
    
    absolute_path = helpers.check_path_exist(path)
    new_path = helpers.safe_expand_path(npath)
    if File.exist?(new_path)
      head 403
    else
    parent = new_path.split('/')[0..-2].join('/')
      FileUtils.mkdir_p(parent)
      FileUtils.mv(absolute_path, new_path)
      head 204
    end
    current_upload.update!(path: params[:new_name])
  end
end