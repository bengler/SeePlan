class Sockets < Thor
  desc "start", "Start websocket server"
  def start
    require './lib/plan_streamer'
    PlanStreamer::start()
  end
end