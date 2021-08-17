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
