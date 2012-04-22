
class SceneKeeper

  SHOW_STATS = false

  constructor: ->
    if not Detector.webgl
      $("#error").show()
      $("#main").hide()

  init: ->
    @config = { 
      hoursPerFrame: 3,
      case: {
        minSize: 100,
        exchangeMultiplier: 20,
        opacity: 0.3,
        color: 0xff8000
      } 
    }

    @initScene()
    @initGeometry()
    @initMaterials()
    @groundPlane = new GroundPlane().addToScene(@scene, @config)
    @planimator = new Planimator(@scene, @config)
    
    @animate()
    @stopped = false

  initGeometry: ->
    @instancedGeometries = {}
    @instancedGeometries.caseGeometry = new THREE.SphereGeometry(1, 16, 16)

  initMaterials: ->
    PI2 = Math.PI * 2
    @instancedMaterials = {}
    @instancedMaterials.particle = new THREE.ParticleCanvasMaterial {color: 0xff0000, program: (context) ->
      context.beginPath()
      context.arc( 0, 0, 1, 0, PI2, true )
      context.closePath()
      context.fill() }

  getGeometries: ->
    @instancedGeometries

  getMaterials: ->
    @instancedMaterials

  initScene: ->

    container = document.createElement('div')
    document.body.appendChild(container)

    @camera = new THREE.Camera(60, window.innerWidth / window.innerHeight, 2000, 1000000)

    @cameraTarget = [10.752053, 59.907985]
    @camera.target.position = Conversions.toCart(@cameraTarget..., 1.00010)

    @camera.useTarget = true

    @cameraDistance = 0
    @cameraRotation = 0
    @cameraHeight = 1.0016

    cameraPosLL = [@cameraTarget[0] + @cameraDistance, @cameraTarget[1] + @cameraRotation, @cameraHeight]
    @cameraRotation = Conversions.toCart(cameraPosLL...)

    @scene = new THREE.Scene
    @scene.fog = new THREE.FogExp2 0xcccccc, 0.000003

    # light = new THREE.PointLight(0xffffff, 1, 1000000)
    # light.position = @camera.position
    # @scene.addObject(light)

    @renderer = new THREE.WebGLRenderer({ clearAlpha: 1,  })
    @renderer.setSize(window.innerWidth, window.innerHeight)
    @renderer.setClearColorHex(0xcccccc, 255)
    container.appendChild(@renderer.domElement)

    if SHOW_STATS
      @stats = new Stats()
      @stats.domElement.style.position = 'absolute'
      @stats.domElement.style.top = '0px'
      @stats.domElement.style.left = '0px'
      container.appendChild(@stats.domElement)        

    window.addEventListener('mousedown', @onDocumentMouseDown, true)
    window.addEventListener('mouseup', @onDocumentMouseUp, true)
    window.addEventListener('mousemove', @onDocumentMouseMove, true)
    window.addEventListener('mousewheel', @onDocumentMouseWheel, true)
    window.addEventListener('resize', @onWindowResize, false)

    @cameraDistance = 10000
    @cameraRotation = 8.8
    @cameraDistance = 0.17
    @calculateCamera()


  calculateCamera: ->
    cameraPosLL = [@cameraTarget[0] + Math.sin(-@cameraRotation) * @cameraDistance , 
                   @cameraTarget[1] + Math.cos(-@cameraRotation) * @cameraDistance * 0.5, @cameraHeight]
    @camera.position = Conversions.toCart(cameraPosLL...)


  onDocumentMouseMove: (event) =>
    if @isUserInteracting
      @cameraRotation = ( @onPointerDownPointerX - event.clientX ) * 0.002 + @onPointerDownLon
      @cameraDistance = -( event.clientY - @onPointerDownPointerY ) * 0.0005 + @onPointerDownLat

    @calculateCamera()

  onDocumentMouseUp: (event) =>
    @isUserInteracting = false

  onDocumentMouseWheel: (event) =>
    if event.wheelDeltaY 
        @cameraHeight -= event.wheelDeltaY * 0.000001
    else if event.wheelDelta
        @cameraHeight -= event.wheelDelta * 0.000001
    else if event.detail 
        @cameraHeight -= event.detail * 0.000001

    @cameraHeight = 1.0001 if @cameraHeight < 1.0001
    @calculateCamera()


  onDocumentMouseDown: (event) =>
    event.preventDefault()

    @isUserInteracting = true

    @onPointerDownPointerX = event.clientX
    @onPointerDownPointerY = event.clientY

    @onPointerDownLon = @cameraRotation
    @onPointerDownLat = @cameraDistance

    if obj = @findMouseObject(event)
      obj.onClicked() if obj.onClicked?

  onWindowResize: (event) =>
    @camera.aspect = window.innerWidth / window.innerHeight
    @camera.updateProjectionMatrix()
    @renderer.setSize(window.innerWidth, window.innerHeight)

  findMouseObject: (event) ->
    @projector = new THREE.Projector() unless @projector?
    vector = new THREE.Vector3( ( event.clientX / window.innerWidth ) * 2 - 1, - ( event.clientY / window.innerHeight ) * 2 + 1, 0.5 )
    @projector.unprojectVector(vector, @camera)
    ray = new THREE.Ray(@camera.position, vector.subSelf(@camera.position).normalize())
    intersects = ray.intersectObjects(@scene.children)
    if intersects.length > 0 
      return intersects[0].object
    return null

  animate: ->
    @render()
    @stats.update() if SHOW_STATS
    requestAnimationFrame(=> @animate()) unless @stopped
    @planimator.animate()

    @camera.up = @camera.position.clone().normalize()

  render: ->
    TWEEN.update()

    @renderer.render(@scene, @camera)

  
$(window).load ->
  window.sceneKeeper = new SceneKeeper
  sceneKeeper.init()
