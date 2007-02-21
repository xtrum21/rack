unless defined? RAILS_ROOT
  raise "Rails' environment has to be loaded before using Rack::Adapter::Rails"
end

require "dispatcher"

module Rack
  module Adapter
    # TODO: Extract this
    class Rails
      def initialize
        @file = Rack::File.new(::File.join(RAILS_ROOT, "public"))
        @dispatcher = RailsDispatcher.new
      end
      
      def call(env)
        file_response = @file.call(env)
        status = file_response.first
        
        if status == 200
          file_response
        else
          @dispatcher.call(env)
        end
      end
    end
    
    class RailsDispatcher
      def call(env)
        response = dispatch(CGIStub.new(env))
        headers  = response.headers
        status   = headers.delete("Status")
        
        [ status, headers, response.body ]
      end
      
      protected
      
      def dispatch(cgi)
        session_options = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS

        request  = ActionController::CgiRequest.new(cgi, session_options)
        response = ActionController::CgiResponse.new(cgi)

        Dispatcher.send(:prepare_application)

        controller = ActionController::Routing::Routes.recognize(request)
        controller.process(request, response)

        return response
      end
      
      class RailsDispatcher::CGIStub
        def initialize(env) @env = env end
        def env_table() @env end
        def params() {} end
        def cookies() {} end
        def query_string() @env["QUERY_STRING"] end

        def key?(key)
          p "Rack::CGI#key? called with #{key.inspect}"
          false
        end
      end
    end
  end
end