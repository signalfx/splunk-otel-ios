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
        options = Options()
        options.platform_name = 'iOS'

        sl_file_id = sys.argv[2]
        
        options.set_capability('appium:app', f'storage:{sl_file_id}')
        options.set_capability('appium:deviceName', 'iPhone Simulator')
        options.set_capability('appium:platformVersion', sys.argv[1])
        options.set_capability('appium:automationName', 'XCUITest')
        sauce_options = {
            'name': 'SplunkRum tests' + currentTime,
            'accessKey': os.environ['SAUCELABS_KEY'],
            'username': os.environ['SAUCELABS_USER']
	    }
        options.set_capability('sauce:options', sauce_options)
        url = f'https://ondemand.us-west-1.saucelabs.com:443/wd/hub'
        self.driver=webdriver.Remote(url, options=options)
        
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
