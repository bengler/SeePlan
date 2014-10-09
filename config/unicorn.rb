APP_ROOT =  "/srv/seeplan/"

worker_processes 4
working_directory APP_ROOT
timeout 30

stdout_path APP_ROOT + "/log/unicorn.stdout.log"
stderr_path APP_ROOT + "/log/unicorn.stderr.log"

listen "/tmp/unicorn.seeplan.sock", :backlog => 64
