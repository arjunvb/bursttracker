# BurstTracker (Offline) README

## Dependencies
1. Obtain [QXDM](https://www.qualcomm.com/media/documents/files/qxdm-professional-qualcomm-extensible-diagnostic-monitor.pdf) license and install software.
2. Place phone in diagnostic mode, and connect to laptop with QPST (comes with QXDM installation).
3. Install MATLAB (no special toolboxes necessary).

## Running BurstTracker (Offline)
BurstTracker can be run offline. Run the following scripts to get metrics from BurstTracker:

1. Run desired application on mobile phone, and collect logs with QXDM. Save QXDM logs in `.txt` format using QCAT (comes with QXDM installation).

2. Parse QXDM logs to MAST.TTS format:
```
$ bash qxdm_raw_to_qxdm_master.sh <path to top-level directory containing QXDM logs>
$ bash qxdm_raw_to_qxdm_master.sh /data/qxdm_test/
```
Here, the folder `qxdm\_test` the raw `.txt` QXDM files. This script generates MAST.TTIS files, which
can be found in the folder `qxdm\_test/qxdm/master`.

Note: this version of BurstTracker includes instrumentation collect many other radio-layer metrics
that are also exposed by QXDM. The relevant metrics computed by BurstTracker include: `THP_TIME_DL` and `THP_DL`.

