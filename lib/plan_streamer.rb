require 'em-websocket' 
require './environment' 
require 'i18n' 
require 'active_support/all'
require 'memcached'
require 'digest/sha1'


module PlanStreamer

  def self.c
    puts "Doh"
  end

  def self.start
    dc = Memcached.new("localhost:11211")
    EventMachine.run {
        EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 3000) do |ws|
            ws.onopen {
              puts "WebSocket connection open"
            }

            ws.onclose { 
              puts "Connection closed"
            }

            ws.onmessage { |msg|
              params = JSON.parse(msg)
              cmd = params[0]

              from_document_date = Time.parse(params[1]).beginning_of_day
              offset = params[2].to_i

              cache_key = Digest::SHA1.hexdigest("#{from_document_date.to_s}_#{offset.to_s}")[0..20]
              values_json = nil
              begin
              	values_json = dc.get(cache_key)
              rescue Memcached::ServerIsMarkedDead
                dc = Memcached.new("localhost:11211")
              rescue Memcached::NotFound              
              end
              
              unless values_json
                cases = Case.all(:fields => [:document_id, :location, :title, :initiated_at, :recorded_number_of_exchanges], :location.not => nil, :initiated_at.gt => from_document_date, :offset => offset, :order => :initiated_at.asc, :limit => 500)

                puts "Got #{cases.length} cases from #{from_document_date} with offset #{offset}"

                values = cases.map do |c| 
                  # TODO: debug this at some point when you have time
                  if c.location.nil?
                    puts "reloading"
                    c = Case.get(c.document_id) 
                  end

                  {
                    title: c.title,
                    kind: c.numerical_kind,
                    location: [c.location.x,c.location.y],
                    exchangeCount: c.recorded_number_of_exchanges,
                    documentId: c.document_id,
                    initiatedAt: c.initiated_at.to_time
                  }
                end
                values_json = Yajl::Encoder.encode(values)
                dc.set(cache_key, values_json)
              end
              ws.send(values_json)
            }
        end
    }
  end
end