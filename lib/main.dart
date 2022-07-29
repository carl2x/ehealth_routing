import 'package:flutter/material.dart';
import 'package:ehealth_routing/directions_model.dart';
import 'package:ehealth_routing/directions_repository.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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

  late GoogleMapController _mapController;
  Marker? _currMarker;
  Directions? _info;
  Position? _currentPosition;

  var _markerNumber = 1;
  final Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};
  final Map<PolylineId, Polyline> _polylines = <PolylineId, Polyline>{};
  final Map<String, Map<String, double>> _trips =
      <String, Map<String, double>>{};
  int _feet = 0;
  double _miles = 0.0;
  int _days = 0;
  int _hours = 0;
  int _mins = 0;
  String distanceText = '';
  String durationText = '';

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  _getCurrentLocation() async {
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        // Store the position in the variable
        _currentPosition = position;

        print('CURRENT POS: $_currentPosition');

        // For moving the camera to current location
        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0,
            ),
          ),
        );
      });
      //await _getAddress();
    }).catchError((e) {
      print(e);
    });
  }

  void _addMarker(LatLng pos) async {
    MarkerId currMarkerID = MarkerId(_markerNumber.toString());
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
            snippet: "Tap to Delete",
            onTap: () {
              setState(() {
                // Exception
                if (_markers.length == 1) {
                  _markers.removeWhere((key, value) => key == currMarkerID);
                }
                // When there are at least two markers
                if (_markers.length >= 2) {
                  bool prevFound = false;
                  bool nextFound = false;
                  int prevMarkerNum = int.parse(currMarkerID.value) - 1;
                  for (int i = 0; i < _markerNumber - 1; i++) {
                    if (_markers
                        .containsKey(MarkerId(prevMarkerNum.toString()))) {
                      prevFound = true;
                      break;
                    }
                    prevMarkerNum--;
                  }
                  int nextMarkerNum = int.parse(currMarkerID.value) + 1;
                  for (int i = 0; i < _markerNumber - 1; i++) {
                    if (_markers
                        .containsKey(MarkerId(nextMarkerNum.toString()))) {
                      nextFound = true;
                      break;
                    }
                    nextMarkerNum++;
                  }
                  // Case One: No Previous Marker (1st Marker in route)
                  if (!prevFound &&
                      _polylines[PolylineId(currMarkerID.value)] != null) {
                    _polylines.removeWhere(
                        (key, value) => key == PolylineId(currMarkerID.value));
                    _removeCurrentTrip(currMarkerID.value);
                    // Remove marker
                    _markers.removeWhere((key, value) => key == currMarkerID);

                    _formatDistanceTime();
                  }
                  // Case Two: No After Markers (last Marker in route)
                  else if (!nextFound &&
                      _polylines[PolylineId(currMarkerID.value)] == null) {
                    _polylines.removeWhere((key, value) =>
                        key == PolylineId(prevMarkerNum.toString()));
                    _removeCurrentTrip(prevMarkerNum.toString());
                    // Remove marker
                    _markers.removeWhere((key, value) => key == currMarkerID);

                    _formatDistanceTime();
                  }
                  // Case Three: Has Both Previous and After Markers
                  else {
                    _polylines.removeWhere((key, value) =>
                        key == PolylineId(prevMarkerNum.toString()));
                    _polylines.removeWhere(
                        (key, value) => key == PolylineId(currMarkerID.value));
                    _removeCurrentTrip(prevMarkerNum.toString());
                    _removeCurrentTrip(currMarkerID.value);
                    // Remove marker
                    _markers.removeWhere((key, value) => key == currMarkerID);

                    _getDirections(MarkerId(prevMarkerNum.toString()),
                        MarkerId(nextMarkerNum.toString()));
                  }
                }
                if (_markers.length == 1) {
                  _clear(false);
                }
                if (_markers.isEmpty) {
                  _clear(true);
                }
              });
            }),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        position: pos,
        draggable: true,
        onDragEnd: ((LatLng newPos) {
          setState(() {
            _markers[currMarkerID] =
                _markers[currMarkerID]!.copyWith(positionParam: newPos);
            // When there are at least two markers
            if (_markers.length >= 2) {
              bool prevFound = false;
              bool nextFound = false;
              int prevMarkerNum = int.parse(currMarkerID.value) - 1;
              for (int i = 0; i < _markerNumber - 1; i++) {
                if (_markers.containsKey(MarkerId(prevMarkerNum.toString()))) {
                  prevFound = true;
                  break;
                }
                prevMarkerNum--;
              }
              int nextMarkerNum = int.parse(currMarkerID.value) + 1;
              for (int i = 0; i < _markerNumber - 1; i++) {
                if (_markers.containsKey(MarkerId(nextMarkerNum.toString()))) {
                  nextFound = true;
                  break;
                }
                nextMarkerNum++;
              }
              // Case One: No Previous Marker (1st Marker in route)
              if (!prevFound &&
                  _polylines[PolylineId(currMarkerID.value)] != null) {
                _polylines.removeWhere(
                    (key, value) => key == PolylineId(currMarkerID.value));
                _removeCurrentTrip(currMarkerID.value);

                // Generate new trip in route
                _getDirections(
                    currMarkerID, MarkerId(nextMarkerNum.toString()));
              }
              // Case Two: No After Markers (last Marker in route)
              else if (!nextFound &&
                  _polylines[PolylineId(currMarkerID.value)] == null) {
                _polylines.removeWhere((key, value) =>
                    key == PolylineId(prevMarkerNum.toString()));
                _removeCurrentTrip(prevMarkerNum.toString());

                // Generate new trip in route
                _getDirections(
                    MarkerId(prevMarkerNum.toString()), currMarkerID);
              }
              // Case Three: Has Both Previous and After Markers
              else {
                _polylines.removeWhere((key, value) =>
                    key == PolylineId(prevMarkerNum.toString()));
                _polylines.removeWhere(
                    (key, value) => key == PolylineId(currMarkerID.value));
                _removeCurrentTrip(prevMarkerNum.toString());
                _removeCurrentTrip(currMarkerID.value);

                // Generate new trips in route
                _getDirections(
                    MarkerId(prevMarkerNum.toString()), currMarkerID);
                _getDirections(
                    currMarkerID, MarkerId(nextMarkerNum.toString()));
              }
            }
          });
        }),
      );
      _markers[currMarkerID] = marker as Marker;
    });
    _currMarker = marker;
    // Only get direction if there are more than two points on map
    if (_markers.length >= 2) {
      int prevMarkerNum = int.parse(currMarkerID.value) - 1;
      for (int i = 0; i < _markers.length; i++) {
        if (_markers.containsKey(MarkerId(prevMarkerNum.toString()))) {
          break;
        }
        prevMarkerNum--;
      }
      _getDirections(MarkerId(prevMarkerNum.toString()), currMarkerID);
    }
    // Move on to the next marker
    _markerNumber++;
  }

  void _removeCurrentTrip(String currMarkerIDValue) {
    // Subtract trip info from total route
    _days -= _trips[currMarkerIDValue]!["days"]!.toInt();
    _hours -= _trips[currMarkerIDValue]!["hours"]!.toInt();
    _mins -= _trips[currMarkerIDValue]!["mins"]!.toInt();
    _miles -= _trips[currMarkerIDValue]!["miles"]!;
    _feet -= _trips[currMarkerIDValue]!["feet"]!.toInt();
    // Remove trip
    _trips.removeWhere((key, value) => key == currMarkerIDValue);
  }

  void _clear(bool clearMarker) {
    setState(() {
      if (clearMarker) {
        _currMarker = null;
        _markerNumber = 1;
        _markers.clear();
        _info = null;
      }
      _polylines.clear();
      _days = 0;
      _hours = 0;
      _mins = 0;
      _miles = 0.0;
      _feet = 0;
    });
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
        color: Colors.redAccent,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleTextStyle:
            const TextStyle(fontSize: 22.0, fontWeight: FontWeight.w500),
        foregroundColor: Colors.white,
        backgroundColor: Colors.redAccent,
        title: _currMarker == null
            ? const Text('eHealth Routing')
            : const Text('eHealth'),
        actions: [
          if (_currMarker != null)
            TextButton(
              onPressed: () => _mapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _currMarker!.position,
                    zoom: 16,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                primary: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: const Text('ZOOM ON MARKER'),
            ),
          if (_markers.isNotEmpty)
            TextButton(
              onPressed: (() {
                _clear(true);
              }),
              style: TextButton.styleFrom(
                primary: Colors.black,
                backgroundColor: Colors.yellow,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: const Text('CLEAR'),
            ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: true,
            trafficEnabled: true,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) => _mapController = controller,
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
          Align(
            alignment: Alignment.centerLeft,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ClipOval(
                      child: Material(
                        color: Colors.white, // button color
                        child: InkWell(
                          splashColor: Colors.blue.shade100, // inkwell color
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(Icons.add),
                          ),
                          onTap: () {
                            _mapController.animateCamera(
                              CameraUpdate.zoomIn(),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipOval(
                      child: Material(
                        color: Colors.white, // button color
                        child: InkWell(
                          splashColor: Colors.blue.shade100, // inkwell color
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(Icons.remove),
                          ),
                          onTap: () {
                            _mapController.animateCamera(
                              CameraUpdate.zoomOut(),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipOval(
                      child: Material(
                        color: Colors.orange.shade100, // button color
                        child: InkWell(
                          splashColor: Colors.orange, // inkwell color
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(Icons.my_location),
                          ),
                          onTap: () {
                            _mapController.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: LatLng(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                  ),
                                  zoom: 18.0,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        onPressed: () => _mapController.animateCamera(
          _info != null
              ? CameraUpdate.newLatLngBounds(_info!.bounds, 100.0)
              : CameraUpdate.newCameraPosition(_initialCameraPosition),
        ),
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }
}
