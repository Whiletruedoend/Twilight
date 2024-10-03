module UploadsHelper
  def upload_dirs(current_url)
    check_path_exist(current_url)
    upload_path = "#{Rails.configuration.credentials[:upload_path]}/#{current_url}"
    populate_directory(upload_path)
  end

  def check_path_exist(path)
    @absolute_path = safe_expand_path(path)
    @relative_path = path
    FileUtils.mkdir_p(@absolute_path) unless File.exist?(@absolute_path)
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

  def populate_directory(current_directory)
    directory = Dir.entries(current_directory)
    @directory = directory.map do |file|
      real_path_absolute = "#{current_directory}/#{file}"
      stat = File.stat(real_path_absolute)
      is_file = stat.file?
      upload = Upload.find_by(path: file)
      {
        size: (is_file ? (number_to_human_size stat.size rescue '-'): '-'),
        type: (is_file ? :file : :directory),
        date: (stat.mtime.strftime('%d %b %Y %H:%M') rescue '-'),
        relative: my_escape("uploads/#{upload&.slug}").gsub('%2F', '/'),
        entry: "#{file}#{is_file ? '': '/'}",
        name: File.basename(real_path_absolute),
        uuid: upload&.uuid || ".",
        slug: upload&.slug || ".",
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