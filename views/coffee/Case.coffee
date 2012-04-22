class Case
  VALID_KINDS = ["Byggesak", "Forespørsel", "Måle-/delesak", "Plansaker"]
  KIND_COLORS = [0x404A69, 0x8AC0DE, 0xFFFFFF, 0xFFAC00]

  constructor: (options, @config) ->

    @documentId = options.documentId
    @initiatedAt = new Date(options.initiatedAt)
    @title = options.title
    @kind = options.kind
    @location = options.location
    @exchangeCount = options.exchangeCount

    color = KIND_COLORS[@kind]

    # awesome

    # @material_basic = new THREE.MeshBasicMaterial( { depthTest: true, color: color, opacity: @config.case.opacity, wireframe: false, blending: THREE.AdditiveBlending, transparent:true } )

    # @material_basic = new THREE.MeshBasicMaterial( { depthTest: true, color: color, opacity: 0.35, wireframe: false, blending: THREE.AdditiveAlphaBlending, transparent:true } )

    # @material_basic = new THREE.MeshPhongMaterial( { depthTest: true, color: color, opacity: 0.7, wireframe: false, blending: THREE.NormalBlending, transparent:true } )

    # @material_basic = new THREE.MeshBasicMaterial( { depthTest: true, color: color, opacity: 0.70, wireframe: false, blending: THREE.MultiplyBlending, transparent:true } )

    @material_basic = new THREE.MeshBasicMaterial( { depthTest: true, color: color, opacity: 0.8, wireframe: false, blending: THREE.NormalBlending, transparent:  true} )

  onClicked: =>
    $('#case_description').empty()
    uri = "http://web102881.pbe.oslo.kommune.no/saksinnsyn/casedet.asp?direct=Y&mode=all&caseno=" + @documentId
    $('<a>',{
      text: @title,
      title: @title,
      target: "_blank",
      href: uri,
    }).appendTo('#case_description')


  addToScene: (scene) ->
    pos = Conversions.toCart(@location..., 1)
    posDest = Conversions.toCart(@location..., 1 + @exchangeCount/16000)

    pos.z += Math.random() / 20
      
    mesh = new THREE.Mesh(sceneKeeper.getGeometries().caseGeometry, [@material_basic])
    mesh.position = pos
    
    mesh.scale.x = mesh.scale.y = mesh.scale.z = 0.0001 
    mesh.rotation.y = Math.random() 
    
    mesh.onClicked = (=> @onClicked())
    
    final_scale = @config.case.minSize + (@exchangeCount * @config.case.exchangeMultiplier)
    # final_scale = @config.case.minSize + (0.62035 * Math.pow(@exchangeCount,0.80) * @config.case.exchangeMultiplier * 4)
    
    motionTween = new TWEEN.Tween(mesh.position)
                  .easing(TWEEN.Easing.Cubic.EaseIn)
                  .to({x: posDest.x, y: posDest.y, z: posDest.z}, 16000 + @exchangeCount * 10)
                  .start()
    
    meshTween = new TWEEN.Tween(mesh.scale)
                  .easing(TWEEN.Easing.Elastic.EaseInOut)
                  .delay(Math.random() * 24)
                  .to({x: final_scale, y: final_scale, z:final_scale}, 1000 + @exchangeCount * 10)
                  .start()
    
    meshTweenFadeOut = new TWEEN.Tween(@material_basic)
                  .easing(TWEEN.Easing.Quadratic.EaseOut)
                  .delay(6000 + Math.random() * 100)
                  .to({opacity: 0.00001}, 2000)
    
    meshTweenPointShrink = new TWEEN.Tween(mesh.scale)
                  .delay(6000 + Math.random() * 100)
                  .to({x: 0.001, y: 0.001, z:0.001}, 400)
                  .onComplete => 
                    scene.removeObject(mesh)
    
    meshTween.chain(meshTweenFadeOut)
    meshTweenFadeOut.chain(meshTweenPointShrink)
    scene.addObject(mesh)

    # particle = new THREE.Particle(sceneKeeper.getMaterials().particle)
    # particle.position = pos
    # particle.scale.x = particle.scale.y = 30000
    # scene.addObject(particle)


window.Case = Case