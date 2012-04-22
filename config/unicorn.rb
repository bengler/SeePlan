APP_ROOT = File.expand_path(File.dirname(File.dirname(__FILE__)))

worker_processes 4
working_directory APP_ROOT
preload_app true
timeout 30

stderr_path APP_ROOT + "/log/unicorn.stderr.log"
stdout_path APP_ROOT + "/log/unicorn.stdout.log"

pid APP_ROOT + "/tmp/pids/unicorn.pid"

listen APP_ROOT + "/tmp/sockets/unicorn.sock", :backlog => 64