from tkinter import constants
import unittest
import os
from appium import webdriver
from time import sleep
from random import choice, randint
from datetime import datetime
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import sys

BUNDLE_ID = 'com.splunk.opentelemetry.SmokeTest'

class IOSTests(unittest.TestCase):

    # set up appium
    def setUp(self):
        currentDate = datetime.now().strftime('%Y-%m-%d')
        currentTime = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        caps = {}
        
        caps['platformName'] = 'iOS'
        caps['appium:app'] = 'storage:filename=SmokeTest.zip' # The filename of the mobile app
        caps['appium:deviceName'] = sys.argv[2]
        caps['appium:platformVersion'] = sys.argv[1]
        caps['sauce:options'] = {}
        caps['sauce:options']['appiumVersion'] = '1.22.3'
        caps['sauce:options']['build'] = 'Platform Configurator Build ' + currentDate
        caps['sauce:options']['name'] = 'Platform Configurator Job ' + currentTime
        
        url = 'https://sso-splunk.saucelabs.com-shattimare:aee7320d-0d97-469d-a6a4-3d4c1ed6c5f0@ondemand.us-west-1.saucelabs.com:443/wd/hub'
        self.driver=webdriver.Remote(url,caps)
    

    def tearDown(self):
        sleep(1)
        self.driver.quit()

    #Loads every element in the current view.
    def load(self):
        find_next = self.driver.find_element_by_xpath("//*")
        return
            

    ''' 
    Validating initializing, app start, and presentation span.
    '''
    def test_SDK_Initialize(self):
        sleep(10);
        self.driver.find_element(By.ID,"SDK Initialize validation").click();
        WebDriverWait(self.driver, 5).until(
            EC.element_to_be_clickable((By.ID, "Success")),
            message='Span validation failed',
        )

    ''' 
    Generating the POST network request with the URLSession and Validating the network span data.
    '''
    def test_API_PostClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"URLSession").click();
        self.driver.find_element(By.ID,"post").click();
        self.validate_span();

    ''' 
    Generating the GET network request with the URLSession and Validating the network span data.
    '''
    def test_API_GetClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"URLSession").click();
        self.driver.find_element(By.ID,"get").click();
        self.validate_span();

    ''' 
    Generating the PUT network request with the URLSession and Validating the network span data.
    '''
    def test_API_PutClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"URLSession").click();
        self.driver.find_element(By.ID,"put").click();
        self.validate_span();
        
    ''' 
    Generating the DELETE network request with the URLSession and Validating the network span data.
    '''
    def test_API_DeleteClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"URLSession").click();
        self.driver.find_element(By.ID,"delete").click();
        self.validate_span();
        
    ''' 
    Generating the POST network request with the Alamofire and Validating the network span data.
    '''
    def test_Alamofire_PostClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"Alamofire").click();
        self.driver.find_element(By.ID,"post").click();
        self.validate_span();
        
    ''' 
    Generating the GET network request with the Alamofire and Validating the network span data.
    '''    
    def test_Alamofire_GetClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"Alamofire").click();
        self.driver.find_element(By.ID,"get").click();
        self.validate_span();
        
    ''' 
    Generating the PUT network request with the Alamofire and Validating the network span data.
    '''
    def test_Alamofire_PutClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"Alamofire").click();
        self.driver.find_element(By.ID,"put").click();
        self.validate_span();
        
    ''' 
    Generating the DELETE network request with the Alamofire and Validating the network span data.
    '''   
    def test_Alamofire_DeleteClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"Alamofire").click();
        self.driver.find_element(By.ID,"delete").click();
        self.validate_span();
        
    ''' 
    Generating the POST network request with the AFNetworking and Validating the network span data.
    ''' 
    def test_AFNetworking_PostClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"AFNetworking").click();
        self.driver.find_element(By.ID,"post").click();
        self.validate_span();
        
    ''' 
    Generating the GET network request with the AFNetworking and Validating the network span data.
    '''   
    def test_AFNetworking_GetClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"AFNetworking").click();
        self.driver.find_element(By.ID,"get").click();
        self.validate_span();
        
    ''' 
    Generating the PUT network request with the AFNetworking and Validating the network span data.
    '''     
    def test_AFNetworking_PutClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"AFNetworking").click();
        self.driver.find_element(By.ID,"put").click();
        self.validate_span();

    ''' 
    Generating the DELETE network request with the AFNetworking and Validating the network span data.
    '''     
    def test_AFNetworking_DeleteClick(self):
        self.driver.find_element(By.ID,"Network Request").click();
        self.driver.find_element(By.ID,"AFNetworking").click();
        self.driver.find_element(By.ID,"delete").click();
        self.validate_span();

    ''' 
    Generating the screen navigation data and Validating span data.
    '''    
    def test_ScreenTrackClick(self):
        self.driver.find_element(By.ID,"Screen-Track").click();
        self.driver.find_element(By.ID,"Custom Screen Name").click();
        self.validate_span();
        
    ''' 
    Validating custom span.
    '''
    def test_CustomSpanClick(self):
        self.driver.find_element(By.ID,"Custom").click()
        sleep(5)
        self.driver.find_element(By.ID,"SDK Initialize validation").click()
        WebDriverWait(self.driver, 5).until(
            EC.element_to_be_clickable((By.ID, "Success")),
            message='Span validation failed',
        )  
        
    ''' 
    Validating Error/Exception span.
    '''
    def test_ErrorSpanClick(self):
        self.driver.find_element(By.ID,"Error").click()
        sleep(5)
        self.driver.find_element(By.ID,"SDK Initialize validation").click()
        WebDriverWait(self.driver, 5).until(
            EC.element_to_be_clickable((By.ID, "Success")),
            message='Span validation failed',
        )

#     ''' 
#     Validating resignactive span.
#     '''
#     def test_ResignActiveSpanClick(self):
#         self.driver.find_element(By.ID,"BackGround/ForeGround").click()
#         self.driver.background_app(10)
#         self.driver.activate_app(BUNDLE_ID)
#         sleep(5)
#         self.driver.find_element(By.ID,"SDK Initialize validation").click()
#         WebDriverWait(self.driver, 5).until(
#             EC.element_to_be_clickable((By.ID, "Success")),
#             message='Span validation failed',
#         )

#     ''' 
#     Validating enterforeground span.
#     '''
#     def test_EnterForeGroundSpanClick(self):
#         self.driver.find_element(By.ID,"BackGround/ForeGround").click()
#         self.driver.background_app(10)
#         self.driver.activate_app(BUNDLE_ID)
#         sleep(5)
#         self.driver.find_element(By.ID,"SDK Initialize validation").click()
#         WebDriverWait(self.driver, 5).until(
#             EC.element_to_be_clickable((By.ID, "Success")),
#             message='Span validation failed',
#         )

#     ''' 
#     Validating webview span.
#     '''
#     def test_WebViewClick(self):
#         self.driver.find_element(By.ID,"WKWebView").click()
#         sleep(5)
#         self.driver.find_element(By.ID,"SDK Initialize validation").click()
#         WebDriverWait(self.driver, 5).until(
#             EC.element_to_be_clickable((By.ID, "Success")),
#             message='Span validation failed',
#         )

    ''' 
    Validating AppTerminate span.
    '''
    def test_AppTerminateSpanClick(self):
        self.driver.find_element(By.ID,"Terminate").click()
        sleep(5)
        self.driver.find_element(By.ID,"SDK Initialize validation").click()
        WebDriverWait(self.driver, 5).until(
            EC.element_to_be_clickable((By.ID, "Success")),
            message='Span validation failed',
        )
        
    ''' 
    Validating crash span.
    '''
    def test_CrashOnViewLoadClick(self):
        self.driver.find_element(By.ID,"Crash").click();
        self.driver.find_element(By.ID,"Crash on ViewDidload").click();
        self.driver.activate_app(BUNDLE_ID)
        sleep(5)
        self.driver.find_element(By.ID,"SDK Initialize validation").click()
        WebDriverWait(self.driver, 5).until(
            EC.element_to_be_clickable((By.ID, "Success")),
            message='Span validation failed',
        )

     
    def validate_span(self):
        sleep(10);
        self.driver.find_element(By.ID,"Span Validation").click();
        WebDriverWait(self.driver, 5).until(
            EC.element_to_be_clickable((By.ID, "Success")),
            message='Span validation failed',
        )
        
   
if __name__ == "__main__":
    suite = unittest.TestLoader().loadTestsFromTestCase(IOSTests)
    testRunner_result = unittest.TextTestRunner(verbosity=2).run(suite)
    if testRunner_result.wasSuccessful():
        exit(0)
    else:
        exit(1)
