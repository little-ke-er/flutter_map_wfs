# 基于flutter_map 实现wfs服务加载

## pubspec.yaml

```
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.2
  # dio 
  dio: ^4.0.0
  # map
  flutter_map: any
```

## View

```
import 'package:flutter/material.dart';
import 'package:flutter_app/page/map/crs.dart';
import 'package:flutter_app/page/map/wfs/wfs_layer.dart';
import 'package:flutter_app/widget/app_page.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  @override
  Widget buildBody(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
          plugins: [WFSPlugin()],
          crs: epsg4490CRS,
          interactiveFlags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          maxZoom: 18,
          minZoom: 4,
          center: LatLng(38.24395844, 114.23923483),
          zoom: 17),
      layers: [
        TileLayerOptions(
          backgroundColor: Colors.transparent,
          urlTemplate:
              'https://',
        ),
        TileLayerOptions(
          backgroundColor: Colors.transparent,
          urlTemplate:
              'https://'
        ),
        WFSLayerOptions(
            url: "http://?",
            typeName: "???",
            render: render),
        WFSLayerOptions(
            url: "http:?",
            typeName: "???",
            render: render),
        WFSLayerOptions(
            url: "http://?",
            typeName: "???",
            maxFeatures: 800,
            render: render),

      ],
    );
  }

  render(dynamic attributes, dynamic points, String type) {
    switch (type) {
      case "Point":
        return Marker(
            width: 5.r,
            height: 5.r,
            point: points,
            builder: (context) {
              return CircleAvatar(backgroundColor: Colors.blue);
            });
        break;
      case "MultiLineString":
        return Polyline(points: points, strokeWidth: 5);
        break;
      case "MultiPolygon":
        return Polygon(
            points: points,
            borderStrokeWidth: 2,
            color: Colors.transparent);
        break;
    // todo other type
    }
  }
}

```

## layer

```
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/request/request.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';

import '../../../main.dart';

class WFSPlugin extends MapPlugin {
  @override
  Widget createLayer(
      LayerOptions options, MapState mapState, Stream<Null> stream) {
    return WFSLayer(options, mapState, stream);
  }

  @override
  bool supportsLayer(LayerOptions options) {
    return options is WFSLayerOptions;
  }
}

class WFSLayerOptions extends LayerOptions {
  final String service;

  final String request;

  final String outputFormat;

  final String version;
  final String typeName;
  final int maxFeatures;
  final String url;
  final Map<String, String> otherParameters;

  String Function(LatLngBounds bounds) bboxBuilder;
  final dynamic Function(dynamic attributes, dynamic points, String type)
      render;

  final dynamic Function(dynamic jsonData) decodeJsonData; //custom decode

  static String _bboxBuilder(LatLngBounds bounds) {
    return "&bbox=${bounds.west},${bounds.south},${bounds.east},${bounds.north}";
  }

  WFSLayerOptions({
    this.service = "WFS",
    this.request = "GetFeature",
    this.outputFormat = "application%2Fjson",
    this.version = "1.0.0",
    this.maxFeatures = 1000,
    this.typeName,
    this.url = "",
    this.otherParameters = const {},
    this.bboxBuilder = _bboxBuilder,
    this.decodeJsonData,
    this.render,
    Key key,
    Stream<Null> rebuild,
  });
}

class WFSLayer extends StatefulWidget {
  final WFSLayerOptions wfsOpts;
  final MapState map;
  final Stream<Null> stream;
  final Dio dio = Dio(BaseOptions(
      connectTimeout: 60000, receiveTimeout: 60000, sendTimeout: 60000));

  WFSLayer(this.wfsOpts, this.map, this.stream) {
    if (isDebug) {
      (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
          (client) {
        client.findProxy = (uri) {
          return "PROXY ${HttpRequest.PROXY_IP}:${HttpRequest.PROXY_PORT}";
        };
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      };
    }
  }

  @override
  State<StatefulWidget> createState() {
    return WFSState();
  }
}

class WFSState extends State<WFSLayer> {
  var timer = Timer(Duration(milliseconds: 100), () => {});

  bool isMoving = false;
  List<Marker> markers = [];
  List<Polyline> polylines = [];
  List<Polygon> polygons = [];

  @override
  void initState() {
    widget.stream.listen((event) {
      requestDataDelay();
    });
    requestDataDelay();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var layers = <Widget>[];
    layers.add(PolygonLayer(
        PolygonLayerOptions(polygons: polygons), widget.map, widget.stream));
    layers.add(PolylineLayer(
        PolylineLayerOptions(polylines: polylines), widget.map, widget.stream));
    layers.add(MarkerLayer(
        MarkerLayerOptions(markers: markers), widget.map, widget.stream));

    return Container(
      child: Stack(
        children: layers,
      ),
    );
  }

  void requestDataDelay() {
    if (isMoving) {
      timer.cancel();
    }
    isMoving = true;
    timer = Timer(Duration(milliseconds: 500), () {
      isMoving = false;
      requestData();
    });
  }

  void requestData() async {
    try {
      var response = await widget.dio.get(_buildUrl());
      var jsonData = response.data;
      if (jsonData is String) {
        jsonData = jsonDecode(jsonData);
      }
      if (widget.wfsOpts.decodeJsonData != null) {
        widget.wfsOpts.decodeJsonData(jsonData);
      } else {
        _decodeJsonData(jsonData);
      }
    } catch (e) {
      print(e);
    }
  }

  String _buildUrl() {
    final buffer = StringBuffer(widget.wfsOpts.url)
      ..write(widget.wfsOpts.service != null
          ? '&service=${widget.wfsOpts.service}'
          : "")
      ..write(widget.wfsOpts.request != null
          ? '&request=${widget.wfsOpts.request}'
          : "")
      ..write(widget.wfsOpts.outputFormat != null
          ? '&outputFormat=${widget.wfsOpts.outputFormat}'
          : "")
      ..write(widget.wfsOpts.version != null
          ? '&version=${widget.wfsOpts.version}'
          : "")
      ..write(widget.wfsOpts.maxFeatures != null
          ? '&maxFeatures=${widget.wfsOpts.maxFeatures}'
          : "")
      ..write(widget.wfsOpts.typeName != null
          ? '&typeName=${widget.wfsOpts.typeName}'
          : "")
      ..write(widget.wfsOpts.bboxBuilder(widget.map.bounds));
    widget.wfsOpts.otherParameters
        .forEach((k, v) => buffer.write('&$k=${Uri.encodeComponent(v)}'));
    return buffer.toString();
  }

  dynamic _decodeJsonData(dynamic jsonData) {
    var features = jsonData["features"];
    markers.clear();
    polylines.clear();
    polygons.clear();
    for (dynamic feature in features) {
      var geometry = feature["geometry"];
      var properties = feature["properties"];
      var type = geometry["type"];
      var coordinates = geometry["coordinates"];
      _parseGeometry(type, coordinates, properties);
    }
    setState(() {});
  }

  void _parseGeometry(type, coordinates, properties) {
    switch (type) {
      case "Point":
        dynamic marker = widget.wfsOpts
            .render(properties, LatLng(coordinates[1], coordinates[0]), type);
        markers.add(marker);
        break;
      case "MultiLineString":
        for (dynamic line in coordinates) {
          List<LatLng> points = [];
          for (dynamic point in line) {
            points.add(LatLng(point[1], point[0]));
          }
          dynamic polyline = widget.wfsOpts.render(properties, points, type);
          polylines.add(polyline);
        }
        break;
      case "MultiPolygon":
        for (dynamic gons in coordinates) {
          for (dynamic gon in gons) {
            List<LatLng> points = [];
            for (dynamic point in gon) {
              points.add(LatLng(point[1], point[0]));
            }
            dynamic polygon = widget.wfsOpts.render(properties, points, type);
            polygons.add(polygon);
          }
        }
        break;
      //todo other type
    }
  }
}

```