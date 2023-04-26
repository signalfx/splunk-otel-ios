import unittest
import os
from appium import webdriver
from time import sleep
from random import choice, randint
from datetime import datetime
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import NoSuchElementException
from selenium.common.exceptions import TimeoutException
import sys

BUNDLE_ID = 'com.splunk.opentelemetry.SmokeTest'

class IOSTests(unittest.TestCase):

    def setUp(self):
        currentDate = datetime.now().strftime('%Y-%m-%d')
        currentTime = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        caps = {}

        sl_file_id = sys.argv[2]
        
        caps['platformName'] = 'iOS'
        caps['appium:app'] = f'storage:{sl_file_id}'
        caps['appium:deviceName'] = "iPhone Simulator"
        caps['appium:platformVersion'] = sys.argv[1]
        caps['appium:automationName'] = 'XCUITest'
        caps['sauce:options'] = {}
        caps['sauce:options']['build'] = 'Platform Configurator Build ' + currentDate
        caps['sauce:options']['name'] = 'Platform Configurator Job ' + currentTime
   
        sl_user = os.environ['SAUCELABS_USER']
        sl_key = os.environ['SAUCELABS_KEY']
        url = f'https://{sl_user}:{sl_key}@ondemand.us-west-1.saucelabs.com:443/wd/hub'
        self.driver=webdriver.Remote(url, caps)
        
    def tearDown(self):
        sleep(1)
        self.driver.quit()

    ''' 
    Loads every element in the current view.
    '''    
    def load(self):
        find_next = self.driver.find_element_by_xpath("//*")
        return
    
    def test_API_PostClick(self):
        self.driver.find_element(By.ID, "foobar").click()
     
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

        
    def validate_more_spans(self):
        sleep(10) #it takes time to generate spans.
        self.driver.execute_script('mobile: scroll', {'direction': 'down'})
        el=self.driver.find_element(By.ID,"Span Validation")
        el.click()
        try:
            WebDriverWait(self.driver, 10,5,NoSuchElementException).until(
                EC.visibility_of_element_located((By.ID, "Success")),
                message='Span validation failed',
            )
        except TimeoutException:
                self.driver.find_element(By.ID,"Success")
   
        
   
if __name__ == "__main__":
    suite = unittest.TestLoader().loadTestsFromTestCase(IOSTests)
    testRunner_result = unittest.TextTestRunner(verbosity=2).run(suite)
    if testRunner_result.wasSuccessful():
        exit(0)
    else:
        exit(1)
