# Updating source files

We need sources from following repos:

* PLCrashReporter - https://github.com/microsoft/plcrashreporter

## Updating

* replace Source/ in ADCrashReporter with Source/ from PLCrashReporter
* add "#import "PLCrashNamespace.h" into all header files (.h, .hpp). This is beacause swift packages do not support prefix headers, and we need to import PLCrashNamespace.h everywhere in order to get the APPD prefix working.