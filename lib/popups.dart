/*
 * This file contains various pop up dialogs.
 */

import 'package:flutter/material.dart';

Future<void> showHelpDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Help Page'),
        content: SingleChildScrollView(
          child: ListBody(
            children: const <Widget>[
              Text('This app allows you to easily add markers'
                  ' and see route information.\n'),
              Text('This app has two modes: Manual and Automatic. To switch'
                  ' between modes, press the leftmost button up top.\n'),
              Text('You can add markers directly on the map by long pressing'
                  ' anywhere. To drag markers around, long press on an existing'
                  ' marker and drag. To delete a marker, tap on the marker and'
                  ' tap on the info window that shows up.\n'),
              Text('MANUAL MODE: Routes will be calculated as you'
                  ' add markers in the order you choose.\n'),
              Text('AUTO MODE: Add all desired markers, then use the "Calculate'
                  ' Route" button to generate the optimal tour. (A tour is a'
                  ' cycle that starts and ends at the first marker.)\n'),
              Text('The three buttons on the right hand side from top to'
                  ' bottom allows you to:\n'),
              Text('1. Search for a location and add that as a new marker.'),
              Text('2. Add current location as a new marker.'),
              Text('3. Show current location.'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showSearchErrorDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Search Error'),
        content: SingleChildScrollView(
          child: ListBody(
            children: const <Widget>[
              Text('Location not found. Try a more specific location.'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showRouteErrorDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Route Not Found'),
        content: SingleChildScrollView(
          child: ListBody(
            children: const <Widget>[
              Text('Marker cannot be reached.\n'),
              Text('Hint: markers can be removed by tapping on it and then'
                  ' tapping on the infowindow that shows up.'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
