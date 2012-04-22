class GroundPlane
  
  constructor: ->
    @origin = [10.720317, 59.970123]

  
  addToScene: (@scene) ->
    planeTexture = THREE.ImageUtils.loadTexture "oslo_coastarific_lakes_2000px_indexed.png",  THREE.UVMapping, (image) =>

      aspectRatio = image.width / image.height

      planeLonLat = [10.73408, 59.9116]
      planePosition = Conversions.toCart(@origin...)

      planeTexture.image = image
      planeTexture.needsUpdate = true
      planeTexture.minFilter = THREE.Nearest
      planeTexture.magFilter = THREE.Nearest
      planeMaterial = new THREE.MeshBasicMaterial({ color:0xdddddd, map: planeTexture })

      planesize = 48500
      geometry = new THREE.CubeGeometry( planesize, 1, planesize / aspectRatio, 4, 4, 1, planeMaterial )
      plane = new THREE.Mesh(geometry, new THREE.MeshFaceMaterial() )
      plane.matrixAutoUpdate = false

      spinAmount = 1.23  
      plane.matrix = new THREE.Matrix4()
      plane.matrix.setPosition(planePosition)

      origVec = new THREE.Vector3(0, -1, 0)
      t = planePosition
      targetVec = new THREE.Vector3(t.x, t.y, t.z)
      targetVec.normalize()
      angle = Math.acos(origVec.dot(targetVec))
      axis = new THREE.Vector3(0, 0, 0)
      axis.cross(origVec, targetVec)
      axis.normalize()
      rot = new THREE.Matrix4().setRotationAxis(axis, angle)
      spin = new THREE.Matrix4().setRotationAxis(targetVec, spinAmount)
      spin.multiplySelf(rot)
      plane.matrix.multiplySelf(spin)
      plane.matrixWorldNeedsUpdate = true

      @scene.addObject(plane)

      geometry = new THREE.PlaneGeometry( planesize * 100, planesize * 100, 1, 1)
      plane = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({color: 0xdddddd}) )

      plane.matrixAutoUpdate = false

      plane.matrix.setPosition(planePosition.multiplyScalar(0.999999))

      origVec = new THREE.Vector3(0, 0, 1)
      t = planePosition
      targetVec = new THREE.Vector3(t.x, t.y, t.z)
      targetVec.normalize()
      angle = Math.acos(origVec.dot(targetVec))
      axis = new THREE.Vector3(0, 0, 0)
      axis.cross(origVec, targetVec)
      axis.normalize()
      rot = new THREE.Matrix4().setRotationAxis(axis, angle)
      spin = new THREE.Matrix4().setRotationAxis(targetVec, spinAmount)
      spin.multiplySelf(rot)
      plane.matrix.multiplySelf(spin)
      plane.matrixWorldNeedsUpdate = true

      @scene.addObject(plane)
      

  addRegistrationHelpers: () ->
    addPoint = (point, color) =>
      position = Conversions.toCart(point...)
      geometry = new THREE.CubeGeometry( 90, 90, 90, 1, 1, 1)
      mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ color: color}) )
      mesh.position = position
      @scene.addObject(mesh)

    # origo for kartet
    addPoint(@origin, 0x0000ff)

    # klumpen ytterst på nordre pir hovedøya, rød
    addPoint([10.735188, 59.89914], 0xff0000)

    # høyre nederste hjørne av maridalsvannet, grønn
    addPoint([10.787834, 59.969419], 0x00ff00)



window.GroundPlane = GroundPlane