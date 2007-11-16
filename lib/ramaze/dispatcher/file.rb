#          Copyright (c) 2006 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.

module Ramaze
  module Dispatcher

    # First of the dispatchers, looks up the public path and serves the
    # file if found.

    class File
      class << self
        include Trinity

        # Entry point from Dispatcher::filter.
        # searches for the file and builds a response with status 200 if found.

        def process(path)
          return unless file = open_file(path)
          response.build(file, STATUS_CODE['OK'])
        end

        # returns file-handle with the open file on success, setting the
        # Content-Type as found in Tool::MIME

        def open_file(path)
          file = resolve_path(path)
          if ::File.file?(file) or ::File.file?(file=file/'index')
            response['Content-Type'] = Tool::MIME.type_for(file) unless ::File.extname(file).empty?
            log(file)
            ::File.open(file, 'rb')
          end
        end

        def resolve_path(path)
          ::File.join(Global.public_root, path)
        end

        def log(file)
          case file
          when *Global.boring
          else
            Inform.debug("Serving static: #{file}")
          end
        end
      end
    end
  end
end
