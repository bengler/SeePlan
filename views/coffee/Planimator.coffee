class Planimator

  HOUR = 1000*60*60

  constructor: (@scene, @config) ->
    @startTime = new Date("2005", "6")
    @currentTime = new Date(@startTime.getTime());
    @queue = []
    @caseCount = 0

    @worker = new Worker('/js/CommunicationWorker.js')

    @worker.onmessage = (event) => 
      for c in event.data
        @queue.push(new Case(c, @config))
      @caseCount += event.data.length
      @worker.postMessage({cmd: "doneProcessing"})
    
  animate: ->
    $("#current_time").text(@queue[0].initiatedAt.toDateString()) if @queue.length > 0
    @currentTime.setTime(@currentTime.getTime() + (HOUR * @config.hoursPerFrame))

    maxInstances = 0
    while @queue.length > 0 and @queue[0].initiatedAt < @currentTime and maxInstances < 5
      @queue.shift().addToScene(@scene) 
      maxInstances += 1

    if @queue.length < 1000
      @worker.postMessage({cmd: "getCasesByDateAndOffset", startTime:  @startTime, offset: @caseCount})
      
    # if @queue.length == 0
      # console.info("** Ouch. Queue underrun **")

window.Planimator = Planimator
