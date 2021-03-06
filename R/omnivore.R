omnivoreDependencies <- function() {
  list(
    htmltools::htmlDependency(
      "leaflet.extras-omnivore",version = "0.1.0",
      system.file("htmlwidgets/lib/omnivore", package = "leaflet.extras"),
      script = c("topojson.js", "toGeoJSON.js", "wellknown.js",
                 "polyline.js", "csv2geojson.js",
                 "omnivore-bindings.js")
    )
  )
}

# Source https://github.com/timwis/leaflet-choropleth
geoJSONChoroplethDependency <- function() {
  list(
    htmltools::htmlDependency(
      "geojson-choropleth",version = "1.1.2",
      system.file("htmlwidgets/lib/geojson-choropleth", package = "leaflet.extras"),
      script = c("choropleth.js")
    )
  )
}

# Utility Function
invokeJSAddMethod <- function(
  jsMethod, # The javascript method to invoke
  map, data, layerId = NULL, group = NULL,
  markerType = NULL, markerIcons = NULL,
  markerIconProperty = NULL, markerOptions = leaflet::markerOptions(),
  clusterOptions = NULL, clusterId = NULL,
  labelProperty = NULL, labelOptions = leaflet::labelOptions(),
  popupProperty = NULL, popupOptions = leaflet::popupOptions(),
  stroke = TRUE,
  color = "#03F",
  weight = 5,
  opacity = 0.5,
  fill = TRUE,
  fillColor = color,
  fillOpacity = 0.2,
  dashArray = NULL,
  smoothFactor = 1.0,
  noClip = FALSE,
  pathOptions = leaflet::pathOptions(),
  highlightOptions = NULL,
  ...
) {
  if(!is.null(markerType) && !(markerType %in% c('marker', 'circleMarker'))) {
    stop("markerType if specified then it needs to be either 'marker' or 'clusterMarker'")
  }

  map$dependencies <- c(map$dependencies, omnivoreDependencies())

  if (!is.null(clusterOptions)) {
    map$dependencies = c(map$dependencies,
                         leaflet::leafletDependencies$markerCluster())
  }

  pathOptions = c(pathOptions, list(
    stroke = stroke, color = color, weight = weight, opacity = opacity,
    fill = fill, fillColor = fillColor, fillOpacity = fillOpacity,
    dashArray = dashArray, smoothFactor = smoothFactor, noClip = noClip))

  markerIconFunction <- NULL
  if(!is.null(markerIcons)) {
     if(inherits(markerIcons,'leaflet_icon_set') ||
        inherits(markerIcons, 'leaflet_icon')) {
       markerIconFunction <- defIconFunction
     } else if(inherits(markerIcons,'leaflet_awesome_icon_set') ||
               inherits(markerIcons, 'leaflet_awesome_icon')) {
       if(inherits(markerIcons,'leaflet_awesome_icon_set')) {
         libs <- unique(sapply(markerIcons,function(icon) icon$library))
         map <- addAwesomeMarkersDependencies(map,libs)
       } else {
         map <- addAwesomeMarkersDependencies(map,markerIcons$library)
       }
       markerIconFunction <- awesomeIconFunction
     } else {
       stop('markerIcons should be created using either leaflet::iconList() or leaflet::awesomeIconList()')
     }
  }

  if(missing(...)) {
    invokeMethod(
      map, getMapData(map), jsMethod, data, layerId, group,
      markerType, markerIcons,
      markerIconProperty, markerOptions, markerIconFunction,
      clusterOptions, clusterId,
      labelProperty, labelOptions, popupProperty, popupOptions,
      pathOptions, highlightOptions)

  } else {
    invokeMethod(
      map, getMapData(map), jsMethod, data, layerId, group,
      markerType, markerIcons,
      markerIconProperty, markerOptions, markerIconFunction,
      clusterOptions, clusterId,
      labelProperty, labelOptions, popupProperty, popupOptions,
      pathOptions, highlightOptions, ...)
  }

}


#' Adds a GeoJSON/TopoJSON to the leaflet map.
#' @description  This is a feature rich alternative to the \code{\link[leaflet]{addGeoJSON}} & \code{\link[leaflet]{addTopoJSON}}
#' with options to map feature properties to labels, popups, colors, markers etc.
#' @param map the leaflet map widget
#' @param geojson a GeoJSON/TopoJSON URL or file contents in a character vector.
#' @param layerId the layer id
#' @param group the name of the group this raster image should belong to (see
#'   the same parameter under \code{\link{addTiles}})
#' @param markerType The type of marker.  either 'marker' or 'circleMarker'
#' @param markerIcons Icons for Marker.
#' Can be a single marker using \code{\link[leaflet]{makeIcon}}
#' or a list of markers using \code{\link[leaflet]{iconList}}
#' @param markerIconProperty The property of the feature to use for marker icon.
#' Can be a JS function which accepts a feature and returns an index of \code{markerIcons}.
#' In either case the result must be one of the indexes of markerIcons.
#' @param markerOptions The options for markers
#' @param clusterOptions if not \code{NULL}, markers will be clustered using
#'   \href{https://github.com/Leaflet/Leaflet.markercluster}{Leaflet.markercluster};
#'    you can use \code{\link[leaflet]{markerClusterOptions}()} to specify marker cluster
#'   options
#' @param clusterId the id for the marker cluster layer
#' @param labelProperty The property to use for the label.
#' You can also pass in a JS function that takes in a feature and returns a text/HTML content.
#' @param labelOptions A Vector of \code{\link{labelOptions}} to provide label
#' @param popupProperty The property to use for popup content
#' You can also pass in a JS function that takes in a feature and returns a text/HTML content.
#' @param popupOptions A Vector of \code{\link{popupOptions}} to provide popups
#' @param stroke whether to draw stroke along the path (e.g. the borders of
#'   polygons or circles)
#' @param color stroke color
#' @param weight stroke width in pixels
#' @param opacity stroke opacity (or layer opacity for tile layers)
#' @param fill whether to fill the path with color (e.g. filling on polygons or
#'   circles)
#' @param fillColor fill color
#' @param fillOpacity fill opacity
#' @param dashArray a string that defines the stroke
#'   \href{https://developer.mozilla.org/en/SVG/Attribute/stroke-dasharray}{dash
#'   pattern}
#' @param smoothFactor how much to simplify the polyline on each zoom level
#'   (more means better performance and less accurate representation)
#' @param noClip whether to disable polyline clipping
#' @param pathOptions Options for shapes
#' @param highlightOptions Options for highlighting the shape on mouse over.
#' options for each label. Default \code{NULL}
#'    you can use \code{\link[leaflet]{highlightOptions}()} to specify highlight
#'   options
#' @rdname omnivore
#' @export
addGeoJSONv2 = function(
  map, geojson, layerId = NULL, group = NULL,
  markerType = NULL, markerIcons = NULL,
  markerIconProperty = NULL, markerOptions = leaflet::markerOptions(),
  clusterOptions = NULL, clusterId = NULL,
  labelProperty = NULL, labelOptions = leaflet::labelOptions(),
  popupProperty = NULL, popupOptions = leaflet::popupOptions(),
  stroke = TRUE,
  color = "#03F",
  weight = 5,
  opacity = 0.5,
  fill = TRUE,
  fillColor = color,
  fillOpacity = 0.2,
  dashArray = NULL,
  smoothFactor = 1.0,
  noClip = FALSE,
  pathOptions = leaflet::pathOptions(),
  highlightOptions = NULL
) {

  invokeJSAddMethod('addGeoJSONv2',
    map, geojson, layerId, group,
    markerType, markerIcons,
    markerIconProperty, markerOptions,
    clusterOptions, clusterId,
    labelProperty, labelOptions, popupProperty, popupOptions,
    stroke,
    color,
    weight,
    opacity,
    fill,
    fillColor,
    fillOpacity,
    dashArray,
    smoothFactor,
    noClip,
    pathOptions, highlightOptions)
}

#' Options to customize a Choropleth Legend
#' @param title An optional title for the legend
#' @param position legend position
#' @param locale The numbers will be formatted using this locale
#' @param numberFormatOptions Options for formatting numbers
#' @export
#' @rdname omnivore
legendOptions <- function(
  title = NULL,
  position = c('bottomleft', 'bottomright', 'topleft', 'topright'),
  locale = 'en-US',
  numberFormatOptions = list(style = 'decimal',
                             maximumFractionDigits = 2,
                             minimumFractionDigits = 0)
) {
  position <- match.arg(position)
  leaflet::filterNULL(
    list(
      title = title,
      position = position,
      formatOptions = list(
        locale = locale,
        options = numberFormatOptions
      )
    )
  )
}

#' Join additional data (properties) to the geojson in a Choropleth. The additional parameters are to customize the join.
#' @param data a JSON/CSV URL or file contents in a character vector.
#' @param key_x Key property of the geojson (geojson key).
#' @param key_y Key property/Column of the additional dataset to join. If no key_y is declared, the first column of the additional data is used.
#' @param delimiter Delimiter used in the csv file. If no delimiter is declared, an automatic detection tries to find the delimiter. For auto detection one of the following delimiter must be used: ',', '\\t', ';', '|'. Files with other extensions then csv are not working in the RStudio Viewer.
#' @export
#' @rdname omnivore
additionalData <- function(
  data = NULL,
  key_x = 'id',
  key_y = NULL,
  delimiter = NULL
) {
  leaflet::filterNULL(
    list(
      data = data,
      key_x = key_x,
      key_y = key_y,
      delimiter = delimiter
    )
  )
}

#' Adds a GeoJSON/TopoJSON Choropleth.
#' @param valueProperty The property to use for coloring
#' @param fillOpacityProperty The property to use for opacity
#' @param scale The scale to use from chroma.js
#' @param steps number of breakes
#' @param mode q for quantile, e for equidistant, k for k-means
#' @param channelMode Default 'rgb', can be one of 'rgb', 'lab', 'hsl', 'lch'
#' @param padding either a single number or a 2 number vector for clipping color values at ends.
#' @param correctLightness whether to correct lightness
#' @param bezierInterpolate whether to use bezier interpolate for determining colors
#' @param colors overrides scale with manual colors
#' @param legendOptions Options to show a legend.
#' @rdname omnivore
#' @export
addGeoJSONChoropleth = function(
  map, geojson, layerId = NULL, group = NULL,
  valueProperty,
  fillOpacityProperty = NULL,
  labelProperty = NULL, labelOptions = leaflet::labelOptions(),
  popupProperty = NULL, popupOptions = leaflet::popupOptions(),
  scale = c('white','red'),
  steps =5,
  mode = 'q',
  channelMode = c('rgb', 'lab', 'hsl', 'lch'),
  padding = NULL,
  correctLightness = FALSE,
  bezierInterpolate = FALSE,
  colors = NULL,
  stroke = TRUE,
  color = "#03F",
  weight = 1,
  opacity = 0.5,
  fillOpacity = 0.2,
  dashArray = NULL,
  smoothFactor = 1.0,
  noClip = FALSE,
  pathOptions = leaflet::pathOptions(),
  highlightOptions = NULL,
  legendOptions = NULL,
  additionalData = NULL
) {
  map$dependencies <- c(map$dependencies, omnivoreDependencies())
  map$dependencies <- c(map$dependencies,
                        geoJSONChoroplethDependency())

  channelMode <- match.arg(channelMode)

  pathOptions =c(pathOptions, list(
    valueProperty=valueProperty,
    fillOpacityProperty=fillOpacityProperty,
    scale=scale,
    steps=steps,
    mode=mode,
    channelMode=channelMode,
    padding=padding,
    correctLightness=correctLightness,
    bezierInterpolate=bezierInterpolate,
    colors=colors,
    stroke=stroke,
    color=color,
    weight=weight,
    opacity=opacity,
    fillOpacity=fillOpacity,
    dashArray=dashArray,
    smoothFactor=smoothFactor,
    noClip=noClip
  ))
  leaflet::invokeMethod(
    map, leaflet::getMapData(map), 'addGeoJSONChoropleth',
    geojson, layerId, group,
    labelProperty, labelOptions, popupProperty, popupOptions,
    pathOptions, highlightOptions, legendOptions, additionalData
    )
}

#' Adds a KML to the leaflet map.
#' @param kml a KML URL or contents in a character vector.
#' @rdname omnivore
#' @export
addKML = function(
  map, kml, layerId = NULL, group = NULL,
  markerType = NULL, markerIcons = NULL,
  markerIconProperty = NULL, markerOptions = leaflet::markerOptions(),
  clusterOptions = NULL, clusterId = NULL,
  labelProperty = NULL, labelOptions = leaflet::labelOptions(),
  popupProperty = NULL, popupOptions = leaflet::popupOptions(),
  stroke = TRUE,
  color = "#03F",
  weight = 5,
  opacity = 0.5,
  fill = TRUE,
  fillColor = color,
  fillOpacity = 0.2,
  dashArray = NULL,
  smoothFactor = 1.0,
  noClip = FALSE,
  pathOptions = leaflet::pathOptions(),
  highlightOptions = NULL
) {
  invokeJSAddMethod('addKML',
    map, kml, layerId, group,
    markerType, markerIcons,
    markerIconProperty, markerOptions,
    clusterOptions, clusterId,
    labelProperty, labelOptions, popupProperty, popupOptions,
    stroke,
    color,
    weight,
    opacity,
    fill,
    fillColor,
    fillOpacity,
    dashArray,
    smoothFactor,
    noClip,
    pathOptions, highlightOptions)
}

#' Adds a KML Choropleth.
#' @rdname omnivore
#' @export
addKMLChoropleth = function(
  map, kml, layerId = NULL, group = NULL,
  valueProperty,
  labelProperty = NULL, labelOptions = leaflet::labelOptions(),
  popupProperty = NULL, popupOptions = leaflet::popupOptions(),
  scale = c('white','red'),
  steps =5,
  mode = 'q',
  channelMode = c('rgb', 'lab', 'hsl', 'lch'),
  padding = NULL,
  correctLightness = FALSE,
  bezierInterpolate = FALSE,
  colors = NULL,
  stroke = TRUE,
  color = "#03F",
  weight = 1,
  opacity = 0.5,
  fillOpacity = 0.2,
  dashArray = NULL,
  smoothFactor = 1.0,
  noClip = FALSE,
  pathOptions = leaflet::pathOptions(),
  highlightOptions = NULL,
  legendOptions = NULL
) {
  map$dependencies <- c(map$dependencies, omnivoreDependencies())
  map$dependencies <- c(map$dependencies,
                        geoJSONChoroplethDependency())
  channelMode <- match.arg(channelMode)
  pathOptions =c(pathOptions, list(
    valueProperty=valueProperty,
    scale=scale,
    steps=steps,
    mode=mode,
    channelMode=channelMode,
    padding=padding,
    correctLightness=correctLightness,
    bezierInterpolate=bezierInterpolate,
    colors=colors,
    stroke=stroke,
    color=color,
    weight=weight,
    opacity=opacity,
    fillOpacity=fillOpacity,
    dashArray=dashArray,
    smoothFactor=smoothFactor,
    noClip=noClip
  ))
  leaflet::invokeMethod(
    map, leaflet::getMapData(map), 'addKMLChoropleth',
    kml, layerId, group,
    labelProperty, labelOptions, popupProperty, popupOptions,
    pathOptions, highlightOptions, legendOptions
    )
}

#' Options for parsing CSV
#' @param latfield field name for latitude
#' @param lonfield field name for longitude
#' @param delimiter field seperator
#' @rdname omnivore
#' @export
csvParserOptions <- function(
  latfield,
  lonfield,
  delimiter = ','
) {
  list(
    latfield = latfield,
    lonfield = lonfield,
    delimiter = delimiter
  )
}

#' Adds a CSV to the leaflet map.
#' @param csv a CSV URL or contents in a character vector.
#' @param csvParserOptions options for parsing the CSV.
#' Use \code{\link{csvParserOptions}}() to supply csv parser options.
#' @rdname omnivore
#' @export
addCSV = function(
  map, csv, csvParserOptions, layerId = NULL, group = NULL,
  markerType = NULL, markerIcons = NULL,
  markerIconProperty = NULL, markerOptions = leaflet::markerOptions(),
  clusterOptions = NULL, clusterId = NULL,
  labelProperty = NULL, labelOptions = leaflet::labelOptions(),
  popupProperty = NULL, popupOptions = leaflet::popupOptions(),
  stroke = TRUE,
  color = "#03F",
  weight = 5,
  opacity = 0.5,
  fill = TRUE,
  fillColor = color,
  fillOpacity = 0.2,
  dashArray = NULL,
  smoothFactor = 1.0,
  noClip = FALSE,
  pathOptions = leaflet::pathOptions(),
  highlightOptions = NULL
) {
  invokeJSAddMethod('addCSV',
    map, csv, layerId, group,
    markerType, markerIcons,
    markerIconProperty, markerOptions,
    clusterOptions, clusterId,
    labelProperty, labelOptions, popupProperty, popupOptions,
    stroke,
    color,
    weight,
    opacity,
    fill,
    fillColor,
    fillOpacity,
    dashArray,
    smoothFactor,
    noClip,
    pathOptions, highlightOptions, csvParserOptions)
}

#' Adds a GPX to the leaflet map.
#' @param gpx a GPX URL or contents in a character vector.
#' @rdname omnivore
#' @export
addGPX = function(
  map, gpx, layerId = NULL, group = NULL,
  markerType = NULL, markerIcons = NULL,
  markerIconProperty = NULL, markerOptions = leaflet::markerOptions(),
  clusterOptions = NULL, clusterId = NULL,
  labelProperty = NULL, labelOptions = leaflet::labelOptions(),
  popupProperty = NULL, popupOptions = leaflet::popupOptions(),
  stroke = TRUE,
  color = "#03F",
  weight = 5,
  opacity = 0.5,
  fill = TRUE,
  fillColor = color,
  fillOpacity = 0.2,
  dashArray = NULL,
  smoothFactor = 1.0,
  noClip = FALSE,
  pathOptions = leaflet::pathOptions(),
  highlightOptions = NULL
) {
  invokeJSAddMethod('addGPX',
    map, gpx, layerId, group,
    markerType, markerIcons,
    markerIconProperty, markerOptions,
    clusterOptions, clusterId,
    labelProperty, labelOptions, popupProperty, popupOptions,
    stroke,
    color,
    weight,
    opacity,
    fill,
    fillColor,
    fillOpacity,
    dashArray,
    smoothFactor,
    noClip,
    pathOptions, highlightOptions)
}
