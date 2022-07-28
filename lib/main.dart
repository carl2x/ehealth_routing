import 'package:flutter/material.dart';
import 'package:ehealth_routing/directions_model.dart';
import 'package:ehealth_routing/directions_repository.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter eHealth Routing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.white,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(40.4237, -86.9212),
    zoom: 12,
  );

  late GoogleMapController _googleMapController;
  Marker? _currMarker;
  Directions? _info;
  var markerNumber = 1;
  final Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};
  final Map<PolylineId, Polyline> _polylines = <PolylineId, Polyline>{};
  final Map<String, Map<String, double>> _trips =
      <String, Map<String, double>>{};
  bool structureRuined = false;
  int _feet = 0;
  double _miles = 0.0;
  int _days = 0;
  int _hours = 0;
  int _mins = 0;
  String distanceText = '';
  String durationText = '';

  @override
  void dispose() {
    _googleMapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        title: _currMarker == null
            ? const Text('eHealth Routing')
            : const Text('eHealth'),
        actions: [
          if (_currMarker != null)
            TextButton(
              onPressed: () => _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _currMarker!.position,
                    zoom: 17,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                primary: Colors.blue,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('ZOOM ON MARKER'),
            ),
          TextButton(
            onPressed: (() {
              setState(() {
                _info = null;
                _currMarker = null;
                structureRuined = false;
                markerNumber = 1;
                _markers.clear();
                _polylines.clear();
                _days = 0;
                _hours = 0;
                _mins = 0;
                _miles = 0.0;
                _feet = 0;
              });
            }),
            style: TextButton.styleFrom(
              primary: Colors.orange,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('CLEAR'),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            trafficEnabled: true,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) => _googleMapController = controller,
            markers: Set<Marker>.of(_markers.values),
            polylines: Set<Polyline>.of(_polylines.values),
            onLongPress: _addMarker,
          ),
          if (_info != null && (_miles > 0 || _feet > 0))
            Positioned(
              top: 20.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6.0,
                  horizontal: 12.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.yellowAccent,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 6.0,
                    )
                  ],
                ),
                child: Text(
                  "$distanceText,$durationText",
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        onPressed: () => _googleMapController.animateCamera(
          _info != null
              ? CameraUpdate.newLatLngBounds(_info!.bounds, 100.0)
              : CameraUpdate.newCameraPosition(_initialCameraPosition),
        ),
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }

  void _addMarker(LatLng pos) async {
    _currMarker = null;
    MarkerId currMarkerID = MarkerId(markerNumber.toString());
    Marker? marker;
    setState(() {
      marker = Marker(
        markerId: currMarkerID,
        onTap: () {
          setState(() {
            _currMarker = marker;
          });
        },
        infoWindow: InfoWindow(
            title: 'Marker #${currMarkerID.value}',
            onTap: () {
              setState(() {
                if (_markers.length == 1) {
                  _markers.removeWhere((key, value) => key == currMarkerID);
                }
                // When there are at least two markers
                if (_markers.length >= 2) {
                  // Case One: No Previous Marker (1st Marker in route)
                  if (!structureRuined &&
                      !_markers.containsKey(MarkerId(
                          (int.parse(currMarkerID.value) - 1).toString()))) {
                    // Remove marker
                    _markers.removeWhere((key, value) => key == currMarkerID);

                    _polylines.removeWhere(
                        (key, value) => key == PolylineId(currMarkerID.value));

                    // Subtract trip info from total route
                    _days -= _trips[currMarkerID.value]!["days"]!.toInt();
                    _hours -= _trips[currMarkerID.value]!["hours"]!.toInt();
                    _mins -= _trips[currMarkerID.value]!["mins"]!.toInt();
                    _miles -= _trips[currMarkerID.value]!["miles"]!;
                    _feet -= _trips[currMarkerID.value]!["feet"]!.toInt();
                    // Remove trip
                    _trips
                        .removeWhere((key, value) => key == currMarkerID.value);
                    _formatDistanceTime();
                  }
                  // Case Two: No After Markers (last Marker in route)
                  else if (!structureRuined &&
                      !_markers.containsKey(MarkerId(
                          (int.parse(currMarkerID.value) + 1).toString()))) {
                    // Remove marker
                    _markers.removeWhere((key, value) => key == currMarkerID);

                    _polylines.removeWhere((key, value) =>
                        key ==
                        PolylineId(
                            (int.parse(currMarkerID.value) - 1).toString()));

                    // Subtract trip info from total route
                    _days -= _trips[(int.parse(currMarkerID.value) - 1)
                            .toString()]!["days"]!
                        .toInt();
                    _hours -= _trips[(int.parse(currMarkerID.value) - 1)
                            .toString()]!["hours"]!
                        .toInt();
                    _mins -= _trips[(int.parse(currMarkerID.value) - 1)
                            .toString()]!["mins"]!
                        .toInt();
                    _miles -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["miles"]!;
                    _feet -= _trips[(int.parse(currMarkerID.value) - 1)
                            .toString()]!["feet"]!
                        .toInt();
                    // Remove trip
                    _trips.removeWhere((key, value) =>
                        key == (int.parse(currMarkerID.value) - 1).toString());
                    _formatDistanceTime();
                  }
                  // Case Three: Has Both Previous and After Markers
                  else {
                    structureRuined = true;
                    // Remove marker
                    _markers.removeWhere((key, value) => key == currMarkerID);
                    int prevMarker = int.parse(currMarkerID.value) - 1;
                    while (!_markers
                        .containsKey(MarkerId(prevMarker.toString()))) {
                      prevMarker--;
                    }
                    _polylines.removeWhere((key, value) =>
                        key == PolylineId(prevMarker.toString()));
                    _polylines.removeWhere(
                        (key, value) => key == PolylineId(currMarkerID.value));

                    // Subtract trip info from total route
                    _days -= _trips[prevMarker.toString()]!["days"]!.toInt();
                    _hours -= _trips[prevMarker.toString()]!["hours"]!.toInt();
                    _mins -= _trips[prevMarker.toString()]!["mins"]!.toInt();
                    _miles -= _trips[prevMarker.toString()]!["miles"]!;
                    _feet -= _trips[prevMarker.toString()]!["feet"]!.toInt();
                    // Remove trip
                    _trips.remove((key, value) => key == prevMarker.toString());

                    // Subtract trip info from total route
                    _days -= _trips[currMarkerID.value]!["days"]!.toInt();
                    _hours -= _trips[currMarkerID.value]!["hours"]!.toInt();
                    _mins -= _trips[currMarkerID.value]!["mins"]!.toInt();
                    _miles -= _trips[currMarkerID.value]!["miles"]!;
                    _feet -= _trips[currMarkerID.value]!["feet"]!.toInt();
                    // Remove trip
                    _trips
                        .removeWhere((key, value) => key == currMarkerID.value);

                    _getDirections(
                        MarkerId(prevMarker.toString()),
                        MarkerId(
                            (int.parse(currMarkerID.value) + 1).toString()));
                  }
                }
                if (_markers.isEmpty) {
                  markerNumber = 1;
                  structureRuined = false;
                }
              });
            },
            snippet: "Tap to Delete"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        position: pos,
        draggable: true,
        onDragEnd: ((LatLng newPos) {
          setState(() {
            _markers[currMarkerID] =
                _markers[currMarkerID]!.copyWith(positionParam: newPos);
            // When there are at least two markers
            if (_markers.length >= 2) {
              // Case One: No Previous Marker (1st Marker in route)
              if (!_markers.containsKey(
                  MarkerId((int.parse(currMarkerID.value) - 1).toString()))) {
                _polylines.removeWhere(
                    (key, value) => key == PolylineId(currMarkerID.value));

                // Subtract trip info from total route
                _days -= _trips[currMarkerID.value]!["days"]!.toInt();
                _hours -= _trips[currMarkerID.value]!["hours"]!.toInt();
                _mins -= _trips[currMarkerID.value]!["mins"]!.toInt();
                _miles -= _trips[currMarkerID.value]!["miles"]!;
                _feet -= _trips[currMarkerID.value]!["feet"]!.toInt();
                // Remove trip
                _trips.removeWhere((key, value) => key == currMarkerID.value);

                // Generate new trip in route
                _getDirections(currMarkerID,
                    MarkerId((int.parse(currMarkerID.value) + 1).toString()));
              }
              // Case Two: No After Markers (last Marker in route)
              else if (!_markers.containsKey(
                  MarkerId((int.parse(currMarkerID.value) + 1).toString()))) {
                _polylines.removeWhere((key, value) =>
                    key ==
                    PolylineId((int.parse(currMarkerID.value) - 1).toString()));

                // Subtract trip info from total route
                _days -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["days"]!
                    .toInt();
                _hours -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["hours"]!
                    .toInt();
                _mins -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["mins"]!
                    .toInt();
                _miles -= _trips[
                    (int.parse(currMarkerID.value) - 1).toString()]!["miles"]!;
                _feet -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["feet"]!
                    .toInt();
                // Remove trip
                _trips.removeWhere((key, value) =>
                    key == (int.parse(currMarkerID.value) - 1).toString());

                // Generate new trip in route
                _getDirections(
                    MarkerId((int.parse(currMarkerID.value) - 1).toString()),
                    currMarkerID);
              }
              // Case Three: Has Both Previous and After Markers
              else {
                _polylines.removeWhere((key, value) =>
                    key ==
                    PolylineId((int.parse(currMarkerID.value) - 1).toString()));
                _polylines.removeWhere(
                    (key, value) => key == PolylineId(currMarkerID.value));

                // Subtract trip info from total route
                _days -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["days"]!
                    .toInt();
                _hours -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["hours"]!
                    .toInt();
                _mins -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["mins"]!
                    .toInt();
                _miles -= _trips[
                    (int.parse(currMarkerID.value) - 1).toString()]!["miles"]!;
                _feet -= _trips[(int.parse(currMarkerID.value) - 1)
                        .toString()]!["feet"]!
                    .toInt();
                // Remove trip
                _trips.remove((key, value) =>
                    key == (int.parse(currMarkerID.value) - 1).toString());

                // Subtract trip info from total route
                _days -= _trips[currMarkerID.value]!["days"]!.toInt();
                _hours -= _trips[currMarkerID.value]!["hours"]!.toInt();
                _mins -= _trips[currMarkerID.value]!["mins"]!.toInt();
                _miles -= _trips[currMarkerID.value]!["miles"]!;
                _feet -= _trips[currMarkerID.value]!["feet"]!.toInt();
                // Remove trip
                _trips.removeWhere((key, value) => key == currMarkerID.value);

                // Generate new trips in route
                _getDirections(
                    MarkerId((int.parse(currMarkerID.value) - 1).toString()),
                    currMarkerID);
                _getDirections(currMarkerID,
                    MarkerId((int.parse(currMarkerID.value) + 1).toString()));
              }
            }
          });
        }),
      );
      _markers[currMarkerID] = marker as Marker;
    });
    // Only get direction if there are more than two points on map
    if (_markers.length >= 2) {
      _getDirections(MarkerId((int.parse(currMarkerID.value) - 1).toString()),
          currMarkerID);
    }
    // Move on to the next marker
    markerNumber++;
  }

  void _getDirections(MarkerId markerIdStart, MarkerId markerIdEnd) async {
    // Get directions
    final directions = await DirectionsRepository().getDirections(
        origin: _markers[markerIdStart]!.position,
        destination: _markers[markerIdEnd]!.position);
    setState(() => _info = directions);

    List<String> distanceElements = _info!.totalDistance.split(" ");
    List<String> durationElements = _info!.totalDuration.split(" ");
    Map<String, double> tripToAdd = <String, double>{};
    int feet = 0;
    double miles = 0.0;
    int days = 0;
    int hours = 0;
    int mins = 0;

    if (distanceElements.contains("ft")) {
      feet = int.parse(distanceElements[distanceElements.indexOf("ft") - 1]);
      _feet += feet;
    }
    if (distanceElements.contains("mi")) {
      miles = double.parse(distanceElements[distanceElements.indexOf("mi") - 1]
          .replaceAll(",", ""));
      _miles += miles;
    }
    if (durationElements.contains("days")) {
      days = int.parse(durationElements[durationElements.indexOf("days") - 1]);
      _days += days;
    }
    if (durationElements.contains("day")) {
      days = int.parse(durationElements[durationElements.indexOf("day") - 1]);
      _days += days;
    }
    if (durationElements.contains("hours")) {
      hours =
          int.parse(durationElements[durationElements.indexOf("hours") - 1]);
      _hours += hours;
    }
    if (durationElements.contains("hour")) {
      hours = int.parse(durationElements[durationElements.indexOf("hour") - 1]);
      _hours += hours;
    }
    if (durationElements.contains("mins")) {
      mins = int.parse(durationElements[durationElements.indexOf("mins") - 1]);
      _mins += mins;
    }
    if (durationElements.contains("min")) {
      mins = int.parse(durationElements[durationElements.indexOf("min") - 1]);
      _mins += mins;
    }

    tripToAdd["days"] = days.toDouble();
    tripToAdd["hours"] = hours.toDouble();
    tripToAdd["mins"] = mins.toDouble();
    tripToAdd["miles"] = miles;
    tripToAdd["feet"] = feet.toDouble();
    _trips[markerIdStart.value] = tripToAdd;

    _formatDistanceTime();

    PolylineId currPolyID = PolylineId(markerIdStart.value);
    Polyline currPoly;
    setState(() {
      currPoly = Polyline(
        polylineId: currPolyID,
        color: Colors.red,
        width: 5,
        points: _info!.polylinePoints
            .map((e) => LatLng(e.latitude, e.longitude))
            .toList(),
      );
      _polylines[currPolyID] = currPoly;
    });
  }

  void _formatDistanceTime() {
    if ((_feet + 5280 * _miles) < 1000) {
      distanceText = "$_feet ft";
    } else {
      distanceText =
          "${((_feet + 5280 * _miles) / 5280).toStringAsFixed(1)} mi";
    }
    durationText = '';
    if (_mins >= 60) {
      _mins = _mins % 60;
      _hours += 1;
    }
    if (_hours >= 24) {
      _hours = _hours % 24;
      _days += 1;
    }
    if (_days == 1) {
      durationText += " $_days day";
    }
    if (_days > 1) {
      durationText += " $_days days";
    }
    if (_hours > 0) {
      durationText += " $_hours hr";
    }
    if (_mins > 0) {
      durationText += " $_mins min";
    }
  }
}
