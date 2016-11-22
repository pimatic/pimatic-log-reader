pimatic log-reader plugin
=========================

The log-reader let you define sensors based on log entries in log files of other programs.
So you can trigger rules based on log entries. See the example-Section for more details.

Configuration:
--------------

Add the plugin to to plugins-Array in the config.json file:

    { 
      "plugin": "log-reader"
    }

Then add a sensor for your log-entries to the devices section:

    {
      "id": "some-id",
      "name": "some name",
      "class": "LogWatcher",
      "file": "/var/log/some-logfile",
      "attributes": [
        "someAttr"
      ],
      "lines": [
        {
          "match": "some log entry 1",
          "predicate": "entry 1",
          "someAttr": "1" 
        },
        {
          "match": "some log entry 2",
          "predicate": "entry 2",
          "someAttr": "2"
        }
      ]
    }


Then you can use the predicates defined in your config.

Examples:
---------

### Turn a speaker on and off when a music player starts or stops playing:

Assuming that you are using [gmediarender](https://github.com/hzeller/gmrender-resurrect) and the 
log is written to "/var/log/gmediarender". Then define following sensor:

    {
      "id": "gmediarender-status",
      "name": "Music Player",
      "class": "LogWatcher",
      "file": "/var/log/gmediarender",
      "attributes": [
        "music-state"
      ],
      "lines": [
        {
          "match": "TransportState: PLAYING",
          "predicate": "music starts",
          "music-state": "playing" 
        },
        {
          "match": "TransportState: STOPPED",
          "predicate": "music stops",
          "music-state": "stopped"
        }
      ]
    }

and add the following rules for an existing speaker actuator:

    when music starts then turn the speaker on

    when music stops then turn the speaker off

### Turn the printer on when you start printing:

Define the following sensor:

    {
      "id": "printer-status",
      "name": "Printer Log",
      "class": "LogWatcher",
      "file": "/var/log/cups/page_log",
      "attributes": [],
      "lines": [
        {
          "match": "psc_1100",
          "predicate": "new print job"
        }
      ]
    }

and define the rule:

    if new print job then turn printer on

### Gather temperature values from a log file:

If the log file looks like this:

    temperature: 21.1
    temperature: 22.2

You can create a TemperatureSensor for this with:

    {
      "id": "temperature-from-logfile",
      "name": "Temperature",
      "class": "LogWatcher",
      "file": "/var/log/temperature",
      "attributes": [
        {
          "name": "temperature",
          "type": "number",
          "unit": "°C"
        }
      ],
      "lines": [
        {
          "match": "temperature: (.+)",
          "temperature": "$1"
        }
      ]
    }

### Get a switch state from a logfile:

If the log file looks like this:

    Switch1: On
    Switch1: Off

You can create a SwitchSensor for this with:

    {
      "id": "switchstate-from-logfile",
      "name": "Switch",
      "class": "LogWatcher",
      "file": "/var/log/switch",
      "attributes": [
        {
          "name": "Switch1",
          "type": "boolean"
        }
      ],
      "lines": [
        {
          "match": "Switch1: On",
          "Switch1": true
        },
        {
          "match": "Switch1: Off",
          "Switch1": false
        }
      ]
    }
    
    {
      "id": "switchstate-from-logfile",
      "name": "Switch",
      "class": "LogWatcher",
      "file": "/var/log/switch",
      "attributes": [
        {
          "name": "Switch1",
          "type": "boolean"
          "labels": [
            "Is switched on",
            "Is switched off"
          ]
        }
      ],
      "lines": [
        {
          "match": "Switch1: On",
          "Switch1": true
        },
        {
          "match": "Switch1: Off",
          "Switch1": false
        }
      ]
    }
