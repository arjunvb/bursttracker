# BurstTracker (ONLINE) README

## Dependencies
1. Download [MobileInsight Desktop version](http://www.mobileinsight.net/download.html).
2. Install, following these [instructions](http://www.mobileinsight.net/get_started_desktop.html). Might need to bypass homebrew warnings by modifying the `install-macos.sh` script.
NOTE: Tested only for Mac OSX.

## Running BurstTracker (ONLINE)
BurstTracker can be run online, on a laptop connected to a phone with an LTE connection.
```
$ python mi-monitor.py <DEVICE> <BAUD> 2>&1 | python burst-tracker.py
$ python mi-monitor.py /dev/tty.lgusbserial1413 9600 2>&1 | python burst-tracker.py
```

