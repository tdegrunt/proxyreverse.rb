module ProxyReverse
  class FrontendRequest
    attr_accessor :host

    def initialize(client)
      @parser = HTTP::RequestParser.new(self)
      @client = client
      @data = ''
    end

    def receive_data(data)
      @data << data
      @parser << data
    end

    def on_message_begin
      @headers = nil
      @body = ''
      @complete = false
    end

    def on_headers_complete(_env)
      @headers = @parser.headers
      @host = @headers['Host']
      @transferEncoding = 'identity'

      @headers['Host'] = @client.options[:backend_host] if @client.options[:rewrite_domain]

      @transferEncoding = @headers['Transfer-Encoding'] if @headers.has_key?('Transfer-Encoding')

      buf = "#{@parser.http_method} #{@parser.request_url} HTTP/#{@parser.http_version.join('.')}\r\n"
      @headers.each_pair do |name, value|
        buf << "#{name}: #{value}\r\n"
      end
      buf << "\r\n"

      @client.relay_to_servers(buf)
    end

    def on_body(chunk)
      @client.relay_to_servers(chunk)
    end

    def on_message_complete
      write_file
      @complete = true
    end

    def complete?
      @complete
    end

    def write_file
      file_name = "raw_#{@parser.http_method}_#{Time.now.to_f.to_s.gsub('.', '')}.http"
      File.open(file_name, 'w') do |file|
        file.write @data
      end
    end
  end
end
