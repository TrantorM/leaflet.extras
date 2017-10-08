var L = require('leaflet');
var chroma = require('chroma-js');
var _ = {
  defaults: require('lodash/object/defaults'),
  extend: require('lodash/object/extend'),
};

// determine the value for a polygon
// valueProperty can be a simple property name or
// a function that accepts a feature and returns a value.
function getValue(feature, valueProperty) {
  return (typeof valueProperty === 'function' ?
    valueProperty(feature) : feature.properties[valueProperty]);
}

// fillOpacity treatment
function getFillOpacity(feature,fillOpacityFunction) {
  var fillOpacity;
  if (typeof fillOpacityFunction === 'function' || typeof fillOpacityFunction === 'string') {
    fillOpacity = getValue(feature, fillOpacityFunction);
  } else if (typeof fillOpacityFunction === 'number') {fillOpacity = fillOpacityFunction;}
  //else {fillOpacity = layer.options.fillOpacity;}
  else {fillOpacity = fillOpacityFunction;}
  return fillOpacity;
}

// returns a function that will set the color for each polygon
function styleFunction(self) {
  return function styleFeature(feature) {

    var style = {};
    var featureValue = getValue(feature, self._options.valueProperty);

    if (!isNaN(featureValue)) {
      // Find the bucket/step/limit that self value is less than and give it that color
      // skip the first value of the limits that's the min value of our range.
      var upperLimit;
      for (var i = 1; i < self._limits.length; i++) {
        upperLimit = i === (self._limits.length-1) ? (self._limits[i] + 1) : self._limits[i];
        if (featureValue < upperLimit) {
          style.fillColor = self._colors[i-1];
          break;
        }
      }
    } else {
      // no valid valueProperty:
      style.fillColor='#000000';
    }

    // fillOpacity treatment
    //var featureOpacity = getValue(feature, self._options.fillOpacityProperty);
    if (typeof self._options.fillOpacityProperty !=='undefined') {
      style.fillOpacity = getFillOpacity(feature, self._options.fillOpacityProperty);
    }

    // Return self style, but include the user-defined style if it was passed
    switch (typeof self._userStyle) {
      case 'function':
        return _.extend(self._userStyle(), style);
      case 'object':
        return _.extend(self._userStyle, style);
      default:
        return style;
    }
  };
}

function joinData(features, data, key_x, key_y) {
  var byKey = {};

  if (key_x !== 'id') {
    // key_x is a property.
    // Rearrange features so that instead of being a big array, it's an object that is
    // indexed by the key name, that we'll use to join on.
    for (var i = 0; i < features.length; i++) {
      // byKey[features[i].properties[key_x]] = features[i];
      byKey[features[i]['properties'][key_x]] = features[i];
    }
  } else {
    // key_x isn't a property, it's the id itself.
    // Rearrange it so that instead of being a big array, it's an object that is
    // indexed by the key name, that we'll use to join on.
    for (var i = 0; i < features.length; i++) {
      byKey[features[i][key_x]] = features[i];
    }
  }

  for (i = 0; i < data.length; i++) {
      // Match the GeoJSON data (byKey) with the tabular data
      // (data), replacing the GeoJSON properties
      // with the full data.
      if (byKey[data[i][key_y]]) {
        byKey[data[i][key_y]].properties = Object.assign(byKey[data[i][key_y]].properties,data[i]);
      } else {
        console.log('The data key '+data[i][key_y]+' does not exist as a key value in the geojson file. The corresponding dataset cannot be joined and is missing in the choropleth map.');
      }
  }

  // Create a new GeoJSON array of features and set it
  // as the new usLayer content.
  features = [];
  for (i in byKey) {
      features.push(byKey[i]);
  }
  return features;
}

// Main Class extends L.GeoJSON
// geojson can be null, and the data can be set later on using setGeoJSON()
L.GeoJSONChoropleth = L.GeoJSON.extend({
  initialize: function(geojson, options, legendOptions, additionalData) {

    var self = this;

    options = options || {}

    // Set default options in case any weren't passed
    // See https://gka.github.io/chroma.js/ for details
    _.defaults(options, {
      valueProperty: 'value',
      fillOpacityProperty: 'value',
      scale: ['white', 'red'],
      steps: 5,
      mode: 'q',
      channelMode: 'rgb',
      padding: false,
      correctLightness: false,
      bezierInterpolate: false
    });

    // save options
    self._options = options;

    // Save what the user passed as the style property for later use (since we're overriding it)
    self._userStyle = options.style

    // Create color buckets
    var cols = options.colors;
    if(!cols) {
      if(options.bezierInterpolate) {
        cols = chroma.bezier(options.scale).scale();
      } else {
        cols = chroma.scale(options.scale);
        cols = options.channelMode !== 'rgb' ? cols.mode(options.channelMode) : cols ; //rgb is default.
        cols = options.correctLightness ? cols.correctLightness() : cols;
      }
      cols = options.padding ?
        cols.padding(options.padding).colors(options.steps) : cols.colors(options.steps);
    }
    self._colors = cols;

    // will be calculated when data is added
    // the geojson data can be added later on
    self._limits = null;

    // Check if we need to create a legend
    if(!$.isEmptyObject(legendOptions)) {

      var formatOptions = {}, // formatting of number range
        legendTitle = null, // title for the legend
        highlightStyle = null, // style used to highlight matching polygons on hover
        resetStyle = null; // style to reset back to, can be null
      if(legendOptions.formatOptions) {
        formatOptions = legendOptions.formatOptions;
        delete legendOptions.formatOptions;
      }
      if(legendOptions.title) {
        legendTitle = legendOptions.title;
        delete legendOptions.title;
      }
      if(legendOptions.highlightStyle) {
        highlightStyle = legendOptions.highlightStyle;
        delete legendOptions.highlightStyle;
      }
      if(legendOptions.resetStyle) {
        resetStyle = legendOptions.resetStyle;
        delete legendOptions.resetStyle;
      }

      // default formatting of the numbers
      _.defaults(formatOptions, {
        locale: 'en-US',
        options: {
          style: 'decimal',
          maximumFractionDigits : 2
        }
      })

      self._legend = L.control(legendOptions);
      self._legend.formatOptions = formatOptions;
      self._legend.title = legendTitle;
      self._legend.highlightStyle = highlightStyle;
      self._legend.resetStyle = resetStyle;
    }

    // proceed on to L.GeoJSON's initialize call, but
    // don't pass the geojson object yet because
    // we haven't called setGeoJSON yet
    L.GeoJSON.prototype.initialize.call(self, null,
      _.extend(self._options,{style: styleFunction(this)}));

    // call setGeoJSON in case geojson was provided
    // else it will have to be called manually later.
    if(geojson) {
      self.setGeoJSON(geojson,additionalData);
    }

  },
  onAdd: function(map) {
    var self = this;

    L.LayerGroup.prototype.onAdd.call(self, map);

    if(self._legend) {
      // add Legend to map only if limits are calculated, else just store the map.
      // this allows the legend to be added when actual data is added to the layer.
      if(self._legend.onAdd) {
        self._legend.addTo(map);
      } else {
        self._legend._map = map;
      }
    }
  },
  onRemove: function(map) {
    var self = this;
    if(self._legend) {
      self._legend.removeFrom(map);
    }
    L.LayerGroup.prototype.onRemove.call(self, map);
  },
  restyleGeoJSON: function(valuePropertyFunction,fillOpacityFunction,labelPropertyFunction,legendTitle) {
    var self = this;
    // update self._options, valuePropertyFunction could be just the property name, but also a function (formula):
    self._options.valueProperty = valuePropertyFunction;
    self._options.fillOpacityProperty = fillOpacityFunction;


    // Calculate Limits:
    var features = $.map(self._layers, function(value, index) {
        return [value.feature];
    });
    var values = features.map(function (feature) {
      return getValue(feature, self._options.valueProperty);
    });
    // remove NaN's and undefined
    //values = values.filter(function(item) {return !!item;});
    console.log('values for limits:');
    console.log(values);
    //
    // Notes that our limits array has 1 more element than our colors arrary
    // this is because the limits denote a range and colors correspond to the range.
    // So if your limits are [0, 10, 20, 30], you'll have 3 colors one for each range 0-9, 10-19, 20-30
    self._limits = chroma.limits(values, self._options.mode, self._options.steps)

    //_.extend(self._options,{style: styleFunction(this)});

    self.eachLayer(function (layer) {
      // determine corresponding color for each polygon object:
      var style = {};
      var featureValue = getValue(layer.feature, self._options.valueProperty);

      if (!isNaN(featureValue)) {
        // Find the bucket/step/limit that self value is less than and give it that color
        // skip the first value of the limits that's the min value of our range.
        var upperLimit;
        for (var i = 1; i < self._limits.length; i++) {
          upperLimit = i === (self._limits.length-1) ? (self._limits[i] + 1) : self._limits[i];
          if (featureValue < upperLimit) {
            style.fillColor = self._colors[i-1];
            break;
          }
        }
      } else {
        // no valid valueProperty:
        style.fillColor='#000000';
      }

      layer.setStyle({
        fillColor: style.fillColor,
        fillOpacity: getFillOpacity(layer.feature,self._options.fillOpacityProperty)
      });
      //console.log(layer);
      if(typeof labelPropertyFunction == 'function') {
        layer.updateLabelContent(labelPropertyFunction(layer.feature));
      }

    });
    //self._legend.resetStyle = self.getResetStyle(style, highlightStyle);
    console.log(self);

    // Calculate legend items and add legend if needed
    if(self._legend) {
      console.log(legendTitle)
      if (legendTitle) {self._legend.title=legendTitle;}
      console.log(self._legend);
      var map = self._legend._map;
      self._legend.removeFrom(map);
      console.log('map:');
      console.log(map);
      console.log(self._legend);

      console.log('before addTo:');
      console.log(map);
      console.log(self._legend);
      self._legend.addTo(map);
      console.log('after addTo:');
      console.log(map);
      console.log(self._legend);
    }
  },
  setGeoJSON: function(geojson,additionalData) {
    var self = this;
		var features = L.Util.isArray(geojson) ? geojson : geojson.features;

    // $.getJSON('https://rawgit.com/TrantorM/topojson-data/master/test.json')
    //     .done(function(data) {
    //       data = JSON.parse(data);
    //       features = joinData(data, features);
    //     });
    if (additionalData) {
      features = joinData(features, additionalData.data, additionalData.key_x, additionalData.key_y);
    }

    var values = features.map(function (feature) {
      return getValue(feature, self._options.valueProperty);
    });
    // remove NaN's and undefined
    //values = values.filter(function(item) {return !!item;});
    console.log('values for limits:');
    console.log(values);

    // Notes that our limits array has 1 more element than our colors arrary
    // this is because the limits denote a range and colors correspond to the range.
    // So if your limits are [0, 10, 20, 30], you'll have 3 colors one for each range 0-9, 10-19, 20-30
    self._limits = chroma.limits(values, self._options.mode, self._options.steps)
    //
    // Add the geojson to L.GeoJSON object so that our geometries are initialized.
    L.GeoJSON.prototype.addData.call(self, geojson);


    // Calculate legend items and add legend if needed
    if(self._legend) {

      var legendTitle = self._legend.title,
        locale = self._legend.formatOptions.locale,
        localeOptions = self._legend.formatOptions.options,
        highlightStyle = self._legend.highlightStyle,
        resetStyle = self._legend.resetStyle;

        function legendEventMouseover(e) {
          document.getElementById(e.target._legendItemId).style['font-weight'] = 'bold';
        }
        function legendEventMouseout(e) {
           document.getElementById(e.target._legendItemId).style['font-weight'] = 'normal';
        }

      self._legend.onRemove = function (map) {
        // remove event listeners.
        if(!$.isEmptyObject(highlightStyle)) {
          self.eachLayer(function (layer) {
            layer._legendItemId=undefined;
            layer._highlightLegendItem=undefined;
            layer.off('mouseover',legendEventMouseover);
            layer.off('mouseout',legendEventMouseout);
          });
        }
      }

      self._legend.onAdd = function (map) {
        var div = L.DomUtil.create('div', 'info legend');
        legendTitle = self._legend.title;     // redo because if function is called from restyleGeoJSON(), the legendTitle may changed.
        if(legendTitle) {
          var title = document.createElement("div");
          title.style={};
          title.style['font-weight'] = "bold";
          title.appendChild(document.createTextNode(legendTitle));
          div.appendChild(title);
        }

        console.log('limits:');
        console.log(self._limits);
        var maxLimit=self._limits[self._limits.length-1];
        for (var i = 0; i < (self._limits.length-1); i++) {
          var from, to, legendItemDiv, color, text;
          from = self._limits[i];
          to = self._limits[i+1];
          // Slightly increase the last value so that we can use from >= featureValue < to
          // to = i === (self._limits.length-2) ? (self._limits[i+1]*1.0001) : self._limits[i+1];

          legendItemDiv = document.createElement("div"); // change from span to div due to left alignement problem of the legend items.
          legendItemDiv.classList.add("legendItem");
          legendItemDiv.id = L.stamp(legendItemDiv); // unique id for each legend item.
          legendItemDiv.dataset.from = from;
          legendItemDiv.dataset.to = to;

          color = document.createElement("i");
          color.style.background = self._colors[i];
          color.style.border = "solid 0.5px #666";

          textSpan = document.createElement("span");
          text = document.createTextNode(
            from.toLocaleString(locale, localeOptions) + ' - ' +
              to.toLocaleString(locale, localeOptions) );
          textSpan.appendChild(text);
          textSpan.style.float="right";

          legendItemDiv.appendChild(color);
          legendItemDiv.appendChild(textSpan);
          legendItemDiv.style.height="25px";            // div height must be higher than the color box, otherwise we get an alignement problem of the legend items.

          div.appendChild(legendItemDiv);


          if(!$.isEmptyObject(highlightStyle)) {

            self.eachLayer(function (layer) {
              var featureValue = getValue(layer.feature, self._options.valueProperty);
              if ((featureValue >= from  && featureValue < to)||(featureValue===maxLimit)) {
                layer._legendItemId = legendItemDiv.id;
                if(!layer._highlightLegendItem) {
                  layer._highlightLegendItem = true;
                  layer.on({
                    mouseover: legendEventMouseover,
                    mouseout: legendEventMouseout
                  });
                }
              }
            });

            legendItemDiv.addEventListener("mouseover", function (event) {
              var span = event.currentTarget,
                from = span.dataset.from,
                to = span.dataset.to;

              span.style['font-weight'] = 'bold';

              self.eachLayer(function (layer) {
                var featureValue = getValue(layer.feature, self._options.valueProperty);

                if(span.id === layer._legendItemId) {
                    layer.setStyle(highlightStyle);
                    if(highlightStyle.bringToFront) {
                      layer.bringToFront();
                    }
                  }
              });
            });
            legendItemDiv.addEventListener("mouseout", function (event) {
              var span = event.currentTarget,
                from = span.dataset.from,
                to = span.dataset.to;

              span.style['font-weight'] = 'normal';

              self.eachLayer(function (layer) {

                var featureValue = getValue(layer.feature, self._options.valueProperty);
                resetStyle.fillOpacity = getFillOpacity(layer.feature, self._options.fillOpacityProperty);

                if(span.id === layer._legendItemId) {
                    if(!$.isEmptyObject(resetStyle)) {
                      layer.setStyle(resetStyle);
                    } else {
                      self.resetStyle(layer);
                    }
                    if(highlightStyle.sendToBack) {
                      layer.bringToBack();
                    }
                  }
              });
            });
          }
        }

        return div;
      };
      // depending on how the GeoJSON data is supplied the map may or maynot be present at this time.
      if(self._legend._map) {
        self._legend.addTo(self._legend._map);
      }
      console.log(self);
    }
  }
});

L.choropleth = module.exports = function (geojson, options, legendOptions, additionalData) {
  console.log('L.choropleth:');
  console.log(additionalData);
  console.log(legendOptions);
  console.log(options);
  return new L.GeoJSONChoropleth(geojson, options, legendOptions, additionalData);
};
