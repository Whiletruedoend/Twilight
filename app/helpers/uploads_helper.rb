module UploadsHelper
  def upload_dirs
    check_path_exist('')
    upload_path = Rails.configuration.credentials[:upload_path]
    populate_directory(upload_path, '')
  end

  def check_path_exist(path)
    @absolute_path = safe_expand_path(path)
    @relative_path = path
    raise ActionController::RoutingError, 'Not Found' unless File.exist?(@absolute_path)
    @absolute_path
  end

  def safe_expand_path(path)
    upload_path = Rails.configuration.credentials[:upload_path]
    current_directory = File.expand_path(upload_path)
    tested_path = File.expand_path(path, upload_path)
    unless tested_path.starts_with?(current_directory)
      raise ArgumentError, 'Should not be parent of root'
    end
    tested_path
  end

  def populate_directory(current_directory, current_url)
    directory = Dir.entries(current_directory)
    @directory = directory.map do |file|
      real_path_absolute = "#{current_directory}/#{file}"
      stat = File.stat(real_path_absolute)
      is_file = stat.file?
      upload = Upload.find_by(path: current_url.present? ? "#{current_url}/#{file}" : file)
      {
        size: (is_file ? (number_to_human_size stat.size rescue '-'): '-'),
        type: (is_file ? :file : :directory),
        date: (stat.mtime.strftime('%d %b %Y %H:%M') rescue '-'),
        relative: my_escape("uploads/#{current_url}#{upload&.slug}").gsub('%2F', '/'),
        entry: "#{file}#{is_file ? '': '/'}",
        absolute: real_path_absolute
      }
    end.sort_by { |entry| "#{entry[:type]}#{entry[:relative]}" }
  end

  def my_escape(string)
    string.gsub(/([^ a-zA-Z0-9_.-]+)/) do
      '%' + $1.unpack('H2' * $1.bytesize).join('%').upcase
    end
  end
end