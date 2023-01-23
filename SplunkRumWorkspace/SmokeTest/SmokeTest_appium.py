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
        caps['appium:automationName'] = 'XCUITest'
        caps['sauce:options'] = {}
        caps['sauce:options']['build'] = 'Platform Configurator Build ' + currentDate
        caps['sauce:options']['name'] = 'Platform Configurator Job ' + currentTime
        
        
        url = 'https://sso-splunk.saucelabs.com-piyushp:634514f6-3878-42e2-89b5-68c5158a4d4b@ondemand.us-west-1.saucelabs.com:443/wd/hub'
        self.driver=webdriver.Remote(url,caps)
        
        
        
    '''
    Quit web driver.
    '''
    def tearDown(self):
        sleep(5)
        self.driver.quit()

    '''
    Loads every element in the current view.
    '''
    def load(self):
        find_next = self.driver.find_element_by_xpath("//*")
        return
    
    
#    '''
#    Generating the slowRenders span with the usleep(100 * 1000) 100ms and Validating the slowframe span data.
#    '''
#    def test_SlowFrame(self):
#        self.driver.find_element(By.ID,"SMALL SLEEP").click();
#        self.validate_span();
    
        
#
#    '''
#    Generating the frozenRenders span with the usleep(1000 * 1000) 1000ms and Validating the frozenframe span data.
#    '''
#    def test_FrozenFrame(self):
#        self.driver.find_element(By.ID,"LARGE SLEEP").click();
#        self.validate_span();
        
    
    def validate_span(self):
        sleep(10);  #it takes time to generate spans.
        self.driver.find_element(By.ID,"Span Validation").click();
        try:
            WebDriverWait(self.driver, 10,5,NoSuchElementException).until(
                EC.visibility_of_element_located((By.ID, "Success")),
                message='Span validation failed',
            )
        except TimeoutException:
                self.driver.find_element(By.ID,"Success")

#
#    def validate_more_spans(self):
#        sleep(10) #it takes time to generate spans.
#        self.driver.execute_script('mobile: scroll', {'direction': 'down'})
#        el=self.driver.find_element(By.ID,"Span Validation")
#        el.click()
#        try:
#            WebDriverWait(self.driver, 10,5,NoSuchElementException).until(
#                EC.visibility_of_element_located((By.ID, "Success")),
#                message='Span validation failed',
#            )
#        except TimeoutException:
#                self.driver.find_element(By.ID,"Success")
        
        
    
if __name__ == "__main__":
    suite = unittest.TestLoader().loadTestsFromTestCase(IOSTests)
    testRunner_result = unittest.TextTestRunner(verbosity=2).run(suite)
    if testRunner_result.wasSuccessful():
        exit(0)
    else:
        exit(1)
