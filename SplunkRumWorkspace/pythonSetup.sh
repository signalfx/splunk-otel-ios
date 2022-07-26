#!/bin/bash

# install appium python client.
cd SmokeTest/
python3 -m pip install Appium-Python-Client
python3 test_appium.py ${{ matrix.os }} "${{ matrix.device }}"
