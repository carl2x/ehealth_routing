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
        title: const Text('Welcome!'),
        content: SingleChildScrollView(
          child: ListBody(
            children: const <Widget>[
              Text('This app allows you to easily add markers'
                  ' and see route information.\n'),
              Text('You can add markers directly on the map by long pressing'
                  ' anywhere. To drag markers around, long press on an existing'
                  ' marker and drag. To delete a marker, tap on the marker and'
                  ' tap on the infowindow that shows up.\n'),
              Text('The three buttons on the right hand side from top to'
                  ' bottom allows you to:'),
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
