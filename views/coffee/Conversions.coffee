class Conversions

  EARTH_RADIUS = 12742000

  degToRad: (deg) ->
    deg * Math.PI / 180.0

  toCart: (lon, lat, multiplier = 1) ->
    rad_lat = @degToRad(lat)
    rad_lon = @degToRad(lon)
    new THREE.Vector3  EARTH_RADIUS * multiplier * Math.cos(rad_lat) * Math.cos(rad_lon),
                  		 EARTH_RADIUS * multiplier * Math.cos(rad_lat) * Math.sin(rad_lon),
                  		 EARTH_RADIUS * multiplier * Math.sin(rad_lat)

window.Conversions = new Conversions
