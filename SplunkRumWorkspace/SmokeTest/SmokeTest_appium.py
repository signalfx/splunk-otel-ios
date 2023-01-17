from tkinter import constants
import unittest
from lib2to3.pgen2 import driver
import os
from appium import webdriver
from time import sleep
from random import choice, randint
from datetime import datetime
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import NoSuchElementException
import sys

BUNDLE_ID = 'com.splunk.opentelemetry.SmokeTest'

class IOSTests(unittest.TestCase):

    ''' 
    Set up appium
    '''
    def setUp(self):
        currentDate = datetime.now().strftime('%Y-%m-%d')
        currentTime = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        caps = {}
        
        caps['platformName'] = 'iOS'
        caps['appium:app'] = 'storage:filename=SmokeTest.zip' 
        caps['appium:deviceName'] = sys.argv[2] 
        caps['appium:platformVersion'] = sys.argv[1]
        caps['sauce:options'] = {}
        caps['sauce:options']['build'] = 'Platform Configurator Build ' + currentDate
        caps['sauce:options']['name'] = 'Platform Configurator Job ' + currentTime
   
        url = 'https://sso-splunk.saucelabs.com-piyushp:634514f6-3878-42e2-89b5-68c5158a4d4b@ondemand.us-west-1.saucelabs.com:443/wd/hub'
        self.driver=webdriver.Remote(url,caps)
        
    
if __name__ == "__main__":
    suite = unittest.TestLoader().loadTestsFromTestCase(IOSTests)
    testRunner_result = unittest.TextTestRunner(verbosity=2).run(suite)
    if testRunner_result.wasSuccessful():
        exit(0)
    else:
        exit(1)
