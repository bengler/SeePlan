importScripts('../js_libs/dateFormat.js');

class ServerConnection
  constructor: (@onDataAvailable) ->
    @openSocket()
    
  openSocket: ->
    uri = "ws:" + location.hostname + ":3000"
    @socket = new WebSocket(uri)
    # @socket = new WebSocket("ws://127.0.0.1:3000")
    @socket.onopen = @onOpen
    @socket.onmessage = @onMessage
    @socket.onclose = @onClose
    @requesting = false


  isBusy: () ->
    return @requesting

  send: (obj) ->
    if @socket.readyState == WebSocket.OPEN
      if @requesting
        return
      @socket.send(JSON.stringify(obj));
      @requesting = true

    else if @socket.readyState == WebSocket.CLOSED
      @openSocket()
    # else
    #   console.log("Couldn't send. Socket not open.")

  # getCasesByID: (fromDocumentId) ->
  #   @send(["getCasesByID", fromDocumentId])
    
  getCasesByDateAndOffset: (fromDate, offset) ->
    @send(["getCasesByDate", fromDate.format("isoDate"), offset])

  # onOpen: =>
  #   console.log("open!")

  onMessage: (event) =>
    @onDataAvailable(JSON.parse(event.data))

  doneProcessing: =>
    @requesting = false


  # onClose: =>
  #   console.log("closed!")

@dataAvailable = (data) =>
  postMessage(data)


@onmessage = (event) ->
  if event.data.cmd == "getCasesByDateAndOffset"
    serverConnection.getCasesByDateAndOffset(event.data.startTime, event.data.offset)
  else if event.data.cmd == "doneProcessing"
    serverConnection.doneProcessing()

serverConnection = new ServerConnection(dataAvailable)
