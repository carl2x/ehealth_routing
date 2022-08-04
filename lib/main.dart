/*
 * This is the main file where the app and its homescreen reside.
 */

import 'package:ehealth_routing/directions_model.dart';
import 'package:ehealth_routing/directions_repository.dart';
import 'package:ehealth_routing/.env.dart';
import 'package:ehealth_routing/popups.dart';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
//import 'package:geocoding/geocoding.dart';

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
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(40.4237, -86.9212),
    zoom: 12,
  );

  late BuildContext _context;
  late GoogleMapController _mapController;

  Marker? _currMarker;
  Marker? _currPosMarker;
  Directions? _info;
  Position? _currentPosition;

  bool _trafficEnabled = false;
  bool _trafficePressed = false;
  bool _satelliteEnabled = false;
  bool _satellitePressed = false;
  bool _gotCurrentLocation = false;

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
  String _distanceText = '';
  String _durationText = '';

  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: googleAPIKey);
  double _inputLatitude = 0.0;
  double _inputLongitude = 0.0;

  bool _autoMode = false;
  bool _calcFinished = true;
  Marker? _firstMarker;
  Map<MarkerId, bool> visited = <MarkerId, bool>{};

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error("Location permissions are permanently denied,"
          " we cannot request permissions.");
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  // This function uses the geolocator package to get current location
  // and also updates the camera.
  void _getCurrentLocation() async {
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        _gotCurrentLocation = true;
        _currentPosition = position;

        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15.0,
            ),
          ),
        );
      });
    }).catchError((e) {});
  }

  void _addMarkerManual(LatLng pos) async {
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
            // Delete
            setState(() {
              if (_markers[currMarkerID]!.position.latitude ==
                      _currPosMarker?.position.latitude &&
                  _markers[currMarkerID]!.position.longitude ==
                      _currPosMarker?.position.longitude) {
                _currPosMarker = null;
              }
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
                if (!prevFound) {
                  _polylines.removeWhere(
                      (key, value) => key == PolylineId(currMarkerID.value));
                  if (_trips.containsKey(currMarkerID.value)) {
                    _removeTrip(currMarkerID.value);
                  }
                  // Remove marker
                  _markers.removeWhere((key, value) => key == currMarkerID);

                  // Sets first marker in route to red
                  _firstMarker = _markers[MarkerId(nextMarkerNum.toString())];
                  _markers[MarkerId(nextMarkerNum.toString())] =
                      _markers[MarkerId(nextMarkerNum.toString())]!.copyWith(
                          iconParam: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed));
                  _formatDistanceTime();
                }
                // Case Two: No After Markers (last Marker in route)
                else if (!nextFound) {
                  _polylines.removeWhere((key, value) =>
                      key == PolylineId(prevMarkerNum.toString()));
                  if (_trips.containsKey(prevMarkerNum.toString())) {
                    _removeTrip(prevMarkerNum.toString());
                  }
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
                  if (_trips.containsKey(prevMarkerNum.toString())) {
                    _removeTrip(prevMarkerNum.toString());
                  }
                  if (_trips.containsKey(currMarkerID.value)) {
                    _removeTrip(currMarkerID.value);
                  }
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
              _currMarker = null;
            });
          },
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        position: pos,
        draggable: true,
        onDragEnd: ((LatLng newPos) {
          setState(
            () {
              _markers[currMarkerID] =
                  _markers[currMarkerID]!.copyWith(positionParam: newPos);
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
                if (!prevFound) {
                  _polylines.removeWhere(
                      (key, value) => key == PolylineId(currMarkerID.value));
                  if (_trips.containsKey(currMarkerID.value)) {
                    _removeTrip(currMarkerID.value);
                  }

                  // Generate new trip in route
                  _getDirections(
                      currMarkerID, MarkerId(nextMarkerNum.toString()));
                }
                // Case Two: No After Markers (last Marker in route)
                else if (!nextFound) {
                  _polylines.removeWhere((key, value) =>
                      key == PolylineId(prevMarkerNum.toString()));
                  if (_trips.containsKey(prevMarkerNum.toString())) {
                    _removeTrip(prevMarkerNum.toString());
                  }

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
                  if (_trips.containsKey(prevMarkerNum.toString())) {
                    _removeTrip(prevMarkerNum.toString());
                  }
                  if (_trips.containsKey(currMarkerID.value)) {
                    _removeTrip(currMarkerID.value);
                  }

                  // Generate new trips in route
                  _getDirections(
                      MarkerId(prevMarkerNum.toString()), currMarkerID);
                  _getDirections(
                      currMarkerID, MarkerId(nextMarkerNum.toString()));
                }
              }
            },
          );
        }),
      );
      // Adds marker to hashtable
      _markers[currMarkerID] = marker as Marker;
      // Sets first marker in route to red
      if (_markers.length == 1) {
        _firstMarker = _markers[currMarkerID];
        _markers[currMarkerID] = _markers[currMarkerID]!.copyWith(
            iconParam:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));
      }
    });
    _currMarker = marker;
    // Only get direction if there are more than two points on map
    if (_markers.length >= 2) {
      int prevMarkerNum = int.parse(currMarkerID.value) - 1;
      for (int i = 0; i < _markerNumber - 1; i++) {
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

  void _removeTrip(String currMarkerIDValue) {
    // Subtract trip info from total route
    _days -= _trips[currMarkerIDValue]!["days"]!.toInt();
    _hours -= _trips[currMarkerIDValue]!["hours"]!.toInt();
    _mins -= _trips[currMarkerIDValue]!["mins"]!.toInt();
    _miles -= _trips[currMarkerIDValue]!["miles"]!;
    _feet -= _trips[currMarkerIDValue]!["feet"]!.toInt();
    // Remove trip
    _trips.removeWhere((key, value) => key == currMarkerIDValue);
  }

  void _addMarkerAuto(LatLng pos) async {
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
                bool prevFound = false;
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
                    break;
                  }
                  nextMarkerNum++;
                }
                // Case One: No Previous Marker (1st Marker in route)
                if (!prevFound) {
                  _polylines.removeWhere(
                      (key, value) => key == PolylineId(currMarkerID.value));
                  if (_trips.containsKey(currMarkerID.value)) {
                    _removeTrip(currMarkerID.value);
                  }
                  // Remove marker
                  _markers.removeWhere((key, value) => key == currMarkerID);

                  // Sets first marker in route to red
                  _firstMarker = _markers[MarkerId(nextMarkerNum.toString())];
                  _markers[MarkerId(nextMarkerNum.toString())] =
                      _markers[MarkerId(nextMarkerNum.toString())]!.copyWith(
                          iconParam: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed));
                } else {
                  _markers.removeWhere((key, value) => key == currMarkerID);
                }
                _clear(false);
              }),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          position: pos,
          draggable: true,
          onDragEnd: ((LatLng newPos) {
            setState(() {
              _markers[currMarkerID] =
                  _markers[currMarkerID]!.copyWith(positionParam: newPos);
              _clear(false);
            });
          }));
      // Adds marker to hashtable
      _markers[currMarkerID] = marker as Marker;
      // Sets first marker in route to red
      if (_markers.length == 1) {
        _firstMarker = _markers[currMarkerID];
        _markers[currMarkerID] = _markers[currMarkerID]!.copyWith(
            iconParam:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));
      }
    });
    _currMarker = marker;
    _clear(false);
    // Move on to the next marker
    _markerNumber++;
  }

  void _calculateRoute() {
    _clear(false);
    if (_markers.length == 2) {
      int nextMarkerNum = int.parse(_firstMarker!.markerId.value) + 1;
      for (int i = 0; i < _markerNumber - 1; i++) {
        if (_markers.containsKey(MarkerId(nextMarkerNum.toString()))) {
          break;
        }
        nextMarkerNum++;
      }
      _getDirections(
          _firstMarker!.markerId, MarkerId(nextMarkerNum.toString()));
    } else {
      _calcFinished = false;
      _calcRouteHelper(_firstMarker!.markerId, 1);
    }
  }

  // numIteration is 1 based
  void _calcRouteHelper(MarkerId markerIdStart, int numIteration) async {
    if (numIteration > _markers.length) {
      _calcFinished = true;
      return;
    }
    visited[markerIdStart] = true;

    Map<String, double> tripToAdd = <String, double>{};
    int feetToAdd = 9223372036854775807;
    double milesToAdd = 9223372036854775807.0;
    int daysToAdd = 0;
    int hoursToAdd = 0;
    int minsToAdd = 0;
    Directions? info;

    MarkerId nearestMarkerId = markerIdStart; // will always get overwritten

    for (MarkerId markerIdEnd in _markers.keys) {
      if ((visited[markerIdEnd] == false ||
              !visited.containsKey(markerIdEnd) ||
              (numIteration == _markers.length &&
                  markerIdEnd == _firstMarker!.markerId)) &&
          markerIdStart != markerIdEnd) {
        try {
          final directions = await DirectionsRepository().getDirections(
              origin: _markers[markerIdStart]!.position,
              destination: _markers[markerIdEnd]!.position);
          setState(() => info = directions);
        } catch (e) {
          showRouteErrorDialog(_context);
          return;
        }
        List<String> distanceElements = info!.totalDistance.split(" ");
        List<String> durationElements = info!.totalDuration.split(" ");
        int feet = 0;
        double miles = 0.0;
        int days = 0;
        int hours = 0;
        int mins = 0;

        if (distanceElements.contains("ft")) {
          feet =
              int.parse(distanceElements[distanceElements.indexOf("ft") - 1]);
        }
        if (distanceElements.contains("mi")) {
          miles = double.parse(
              distanceElements[distanceElements.indexOf("mi") - 1]
                  .replaceAll(",", ""));
        }
        if (durationElements.contains("days")) {
          days =
              int.parse(durationElements[durationElements.indexOf("days") - 1]);
        } else if (durationElements.contains("day")) {
          days =
              int.parse(durationElements[durationElements.indexOf("day") - 1]);
        }
        if (durationElements.contains("hours")) {
          hours = int.parse(
              durationElements[durationElements.indexOf("hours") - 1]);
        } else if (durationElements.contains("hour")) {
          hours =
              int.parse(durationElements[durationElements.indexOf("hour") - 1]);
        }
        if (durationElements.contains("mins")) {
          mins =
              int.parse(durationElements[durationElements.indexOf("mins") - 1]);
        } else if (durationElements.contains("min")) {
          mins =
              int.parse(durationElements[durationElements.indexOf("min") - 1]);
        }
        if (feet.toDouble() + miles < feetToAdd.toDouble() + milesToAdd) {
          nearestMarkerId = markerIdEnd;
          feetToAdd = feet;
          milesToAdd = miles;
          daysToAdd = days;
          hoursToAdd = hours;
          minsToAdd = mins;
          _info = info;
        }
      }
    }
    tripToAdd["days"] = daysToAdd.toDouble();
    tripToAdd["hours"] = hoursToAdd.toDouble();
    tripToAdd["mins"] = minsToAdd.toDouble();
    tripToAdd["miles"] = milesToAdd;
    tripToAdd["feet"] = feetToAdd.toDouble();
    _trips[markerIdStart.value] = tripToAdd;

    _feet += feetToAdd;
    _miles += milesToAdd;
    _days += daysToAdd;
    _hours += hoursToAdd;
    _mins += minsToAdd;

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
    _calcRouteHelper(nearestMarkerId, ++numIteration);
  }

  void _clear(bool clearMarker) {
    setState(() {
      if (clearMarker) {
        _markerNumber = 1;
        _markers.clear();
        _info = null;
        _currPosMarker = null;
        _currMarker = null;
        _firstMarker = null;
      }
      visited.clear();
      _polylines.clear();
      _days = 0;
      _hours = 0;
      _mins = 0;
      _miles = 0.0;
      _feet = 0;
      _inputLatitude = 0.0;
      _inputLongitude = 0.0;
    });
  }

  void _getDirections(MarkerId markerIdStart, MarkerId markerIdEnd) async {
    // Get directions
    try {
      final directions = await DirectionsRepository().getDirections(
          origin: _markers[markerIdStart]!.position,
          destination: _markers[markerIdEnd]!.position);
      setState(() => _info = directions);
    } catch (e) {
      showRouteErrorDialog(_context);
      return;
    }

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
    } else if (durationElements.contains("day")) {
      days = int.parse(durationElements[durationElements.indexOf("day") - 1]);
      _days += days;
    }
    if (durationElements.contains("hours")) {
      hours =
          int.parse(durationElements[durationElements.indexOf("hours") - 1]);
      _hours += hours;
    } else if (durationElements.contains("hour")) {
      hours = int.parse(durationElements[durationElements.indexOf("hour") - 1]);
      _hours += hours;
    }
    if (durationElements.contains("mins")) {
      mins = int.parse(durationElements[durationElements.indexOf("mins") - 1]);
      _mins += mins;
    } else if (durationElements.contains("min")) {
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
      _distanceText = "$_feet ft";
    } else {
      _distanceText =
          "${((_feet + 5280 * _miles) / 5280).toStringAsFixed(1)} mi";
    }
    _durationText = '';
    if (_mins >= 60) {
      _mins = _mins % 60;
      _hours += 1;
    }
    if (_hours >= 24) {
      _hours = _hours % 24;
      _days += 1;
    }
    if (_days == 1) {
      _durationText += " $_days day";
    } else if (_days > 1) {
      _durationText += " $_days days";
    }
    if (_hours > 0) {
      _durationText += " $_hours hr";
    }
    if (_mins > 0) {
      _durationText += " $_mins min";
    }
  }

  Future<void> _displayPrediction(Prediction? p) async {
    try {
      PlacesDetailsResponse detail =
          await _places.getDetailsByPlaceId("${p!.placeId}");

      //var placeId = p.placeId;
      //var address = await locationFromAddress("${p!.description}");

      _inputLatitude = detail.result.geometry!.location.lat;
      _inputLongitude = detail.result.geometry!.location.lng;
    } catch (e) {
      showSearchErrorDialog(_context);
    }
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_inputLatitude, _inputLongitude),
          zoom: 15,
          tilt: 0,
        ),
      ),
    );
    if (!_autoMode) {
      _addMarkerManual(LatLng(_inputLatitude, _inputLongitude));
    } else {
      _addMarkerAuto(LatLng(_inputLatitude, _inputLongitude));
    }
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    double floatButtonOffset = 16.0;
    //var height = MediaQuery.of(context).size.height;
    //var width = MediaQuery.of(context).size.width;

    Text mainTitleText = const Text('eHealth Routing');
    Text autoModeTitleText = const Text('Auto Routing Mode');
    Text markerCountText = Text('Marker Count: ${_markers.length}');

    return Scaffold(
      // Top Appbar
      appBar: AppBar(
        centerTitle: false,
        titleTextStyle: _markers.isEmpty
            ? const TextStyle(fontSize: 22.0, fontWeight: FontWeight.w500)
            : const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500),
        foregroundColor: Colors.white,
        backgroundColor: _autoMode ? Colors.blue : Colors.redAccent,
        title: _markers.isEmpty
            ? (_autoMode ? autoModeTitleText : mainTitleText)
            : markerCountText,
        actions: [
          if (_markers.isEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _autoMode = !_autoMode;
                });
              },
              style: TextButton.styleFrom(
                primary: Colors.white,
              ),
              child: const Icon(Icons.auto_mode),
            ),
          TextButton(
            onPressed: () => showHelpDialog(_context),
            style: TextButton.styleFrom(
              primary: Colors.white,
            ),
            child: const Icon(Icons.help_outline),
          ),
          if (_currMarker != null)
            TextButton(
              onPressed: () => _mapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _currMarker!.position,
                    zoom: 17,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                primary: Colors.white,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, inherit: false),
              ),
              child: const Text('FOCUS'),
            ),
          if (_markers.isNotEmpty)
            TextButton(
              onPressed: (() {
                _clear(true);
              }),
              style: TextButton.styleFrom(
                primary: Colors.black,
                backgroundColor: Colors.yellow,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, inherit: false),
              ),
              child: const Text('CLEAR'),
            ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            padding: const EdgeInsets.only(left: 15), // Moves Google Logo
            mapType: _satelliteEnabled ? MapType.hybrid : MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: true,
            trafficEnabled: _trafficEnabled,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) => _mapController = controller,
            markers: Set<Marker>.of(_markers.values),
            polylines: Set<Polyline>.of(_polylines.values),
            onLongPress: _autoMode ? _addMarkerAuto : _addMarkerManual,
          ),
          // Route distance and duration display
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
                  "$_distanceText,$_durationText",
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // CenterLeft
          Align(
            alignment: Alignment.centerLeft,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                    left: floatButtonOffset, bottom: floatButtonOffset),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    FloatingActionButton.small(
                      heroTag: "Zoom In",
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.black,
                      onPressed: () {
                        _mapController.animateCamera(CameraUpdate.zoomIn());
                      },
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 0),
                    FloatingActionButton.small(
                      heroTag: "Zoom Out",
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.black,
                      onPressed: () {
                        _mapController.animateCamera(CameraUpdate.zoomOut());
                      },
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 15),
                    FloatingActionButton(
                      heroTag: "Show Route",
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.black,
                      onPressed: () => _mapController.animateCamera(
                        _info != null
                            ? CameraUpdate.newLatLngBounds(_info!.bounds, 100.0)
                            : CameraUpdate.newCameraPosition(
                                _initialCameraPosition),
                      ),
                      child: const Icon(Icons.center_focus_strong),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // BottomCenter Up
          if (_autoMode && _markers.length > 1)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(primary: Colors.yellow),
                        onPressed: _calcFinished
                            ? () {
                                _calculateRoute();
                              }
                            : null,
                        child: _calcFinished
                            ? const Text(
                                "Calculate Route",
                                style: TextStyle(
                                    fontSize: 16.0,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    inherit: false),
                              )
                            : const Text(
                                "Calculating...",
                                style: TextStyle(
                                    fontSize: 16.0,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    inherit: false),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // BottomCenter Down
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      style: _satellitePressed
                          ? ElevatedButton.styleFrom(
                              primary: Colors.blue,
                              fixedSize: const Size(10, 10))
                          : ElevatedButton.styleFrom(primary: Colors.blueGrey),
                      onPressed: () {
                        setState(() {
                          _satellitePressed = !_satellitePressed;
                          _satelliteEnabled = !_satelliteEnabled;
                        });
                      },
                      child: const Icon(Icons.satellite_alt),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: _trafficePressed
                          ? ElevatedButton.styleFrom(primary: Colors.blue)
                          : ElevatedButton.styleFrom(primary: Colors.blueGrey),
                      onPressed: () {
                        setState(() {
                          _trafficePressed = !_trafficePressed;
                          _trafficEnabled = !_trafficEnabled;
                        });
                      },
                      child: const Icon(Icons.traffic),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // CenterRight
          Align(
            alignment: Alignment.centerRight,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                    right: floatButtonOffset, bottom: floatButtonOffset),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    FloatingActionButton.small(
                      heroTag: "Search",
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.black,
                      onPressed: () async {
                        Prediction? p = await PlacesAutocomplete.show(
                          offset: 0,
                          strictbounds: false,
                          region: "us",
                          language: "en",
                          context: context,
                          mode: Mode.overlay,
                          apiKey: googleAPIKey,
                          sessionToken: null,
                          components: [Component(Component.country, "us")],
                          types: const <String>[],
                          hint: "Search for a location",
                          startText: "",
                        );
                        if (p != null) {
                          _displayPrediction(p);
                        }
                      },
                      child: const Icon(Icons.search),
                    ),
                    const SizedBox(height: 0),
                    FloatingActionButton.small(
                      heroTag: "Current Location Marker",
                      backgroundColor: _gotCurrentLocation
                          ? Theme.of(context).primaryColor
                          : Colors.black54,
                      foregroundColor:
                          _gotCurrentLocation ? Colors.black : Colors.white,
                      onPressed: _gotCurrentLocation
                          ? () async {
                              if (_currPosMarker != null &&
                                  _currentPosition!.latitude ==
                                      _currPosMarker!.position.latitude &&
                                  _currentPosition!.longitude ==
                                      _currPosMarker!.position.longitude) {
                                _mapController.animateCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      target: LatLng(_currentPosition!.latitude,
                                          _currentPosition!.longitude),
                                      zoom: 15.0,
                                    ),
                                  ),
                                );
                              } else {
                                _getCurrentLocation();
                                if (!_autoMode) {
                                  _addMarkerManual(LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude));
                                } else {
                                  _addMarkerAuto(LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude));
                                }
                                _currPosMarker = _currMarker;
                              }
                            }
                          : null,
                      child: _gotCurrentLocation
                          ? const Icon(Icons.location_pin)
                          : const Icon(Icons.location_off),
                    ),
                    const SizedBox(height: 15),
                    FloatingActionButton(
                      heroTag: "Current Location",
                      backgroundColor:
                          _gotCurrentLocation ? Colors.white : Colors.black54,
                      onPressed: () async {
                        _getCurrentLocation();
                      },
                      child: _gotCurrentLocation
                          ? const Icon(
                              Icons.my_location,
                              color: Colors.black,
                            )
                          : const Icon(
                              Icons.my_location,
                              color: Colors.white,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
