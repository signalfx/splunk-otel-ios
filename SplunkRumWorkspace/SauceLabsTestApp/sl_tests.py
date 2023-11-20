import unittest
import os
from appium import webdriver
from datetime import datetime
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import sys

class IOSTests(unittest.TestCase):

    def setUp(self):
        currentTime = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        caps = {}

        sl_file_id = sys.argv[2]
        
        caps['platformName'] = 'iOS'
        caps['appium:app'] = f'storage:{sl_file_id}'
        caps['appium:deviceName'] = 'iPhone Simulator'
        caps['appium:platformVersion'] = sys.argv[1]
        caps['appium:automationName'] = 'XCUITest'
        caps['sauce:options'] = {}
        caps['sauce:options']['name'] = 'SplunkRum tests' + currentTime
        caps['sauce:options']['accessKey'] = os.environ['SAUCELABS_KEY']
        caps['sauce:options']['username'] = os.environ['SAUCELABS_USER']
        url = f'https://ondemand.us-west-1.saucelabs.com:443/wd/hub'
        self.driver=webdriver.Remote(url, caps)

        
    def tearDown(self):
        self.driver.quit()

    def test_spans(self):
        self.driver.find_element(By.ID, "results").click()
        WebDriverWait(self.driver, 20).until(
            EC.text_to_be_present_in_element((By.ID, "test_result"), "success")
        )

if __name__ == "__main__":
    suite = unittest.TestLoader().loadTestsFromTestCase(IOSTests)
    testRunner_result = unittest.TextTestRunner(verbosity=2).run(suite)
    if testRunner_result.wasSuccessful():
        exit(0)
    else:
        exit(1)
