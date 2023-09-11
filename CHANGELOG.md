# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Version 0.11.2
* Fixes adding a link to a network span if traceparent is not the first key in the string
* Implement Sampler protocol for SessionBasedSampler

## Version 0.11.1
* Adds option for slowRenderingDetectionEnabled
* Adds option for bspScheduleDelay

## Version 0.11.0

* Deprecates the use of SplunkRum.initialize.  Use the SplunkRumBuilder going forward.
* Adds reportEvent convenience function.
* Adds ability to import project through cocoapods.
