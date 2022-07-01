import requests
import urllib.request
from time import sleep

LOG_FILE_URL = "http://localhost:8080/consolelog/logs.txt"

INITIALIZE_SPAN = b'Span SplunkRum.initialize'
APP_START_SPAN = b'Span AppStart'
PRESENTATION_SPAN = b'Span PresentationTransition'

POST_SPAN = b'Span HTTP POST' 
GET_SPAN = b'Span HTTP GET' 
PUT_SPAN = b'Span HTTP PUT' 
DELETE_SPAN = b'Span HTTP DELETE' 
NETWORK_CALL_POST_URL = b'https://reqres.in/api/login'  
NETWORK_CALL_DELETE_URL = b'https://my-json-server.typicode.com/typicode/demo/posts/1'
NETWORK_CALL_GET_URL = b'https://www.splunk.com'
NETWORK_CALL_PUT_URL = b'https://reqres.in/api/users/2'

SCREEN_CHANGE_SPAN = b'Span screen name change'
SHOWVC_SPAN = b'Span ShowVC'
SCREEN_TRACK_VC = b'ScreenTrackVC'
CUSTOME_SCREEN_TRACK_VC = b'CustomScreenNameVC'

# Deleting the log after validation completes.
def delete_log():
    response = requests.delete(LOG_FILE_URL)
    if response.content == b'true':
        print("Logs are deleted...")
    else:
        print("Failed to delete logs.")

#Validating the RUM SDK initialize span.
def sdk_initialize_validation():
    sleep(5);
    data = urllib.request.urlopen(LOG_FILE_URL)
    initializeFound = False
    appStartFound = False
    presentationFound = False
    for line in data:
        if INITIALIZE_SPAN in line:
            print("Found....Initialize_Span")
            initializeFound = True
        if APP_START_SPAN in line:
            print("Found....App_Start_Span")
            appStartFound = True
        if PRESENTATION_SPAN in line:
            print("Found....Presentation_span")
            presentationFound = True
    delete_log()
    if initializeFound == False or appStartFound == False or presentationFound == False:
       exit(1)

#Validating the Netowork POST API span.
def method_post_validation():
    sleep(5);
    data = urllib.request.urlopen(LOG_FILE_URL)
    methodFound = False
    urlFound = False
    for line in data:
        if POST_SPAN in line:
            print("Found....Method")
            methodFound = True
        if NETWORK_CALL_POST_URL in line:
            print("Found....URL")
            urlFound = True
    delete_log()
    if methodFound == False or urlFound == False:
       exit(1)

#Validating the Netowork GET API span.
def method_get_validation():
    sleep(5);
    data = urllib.request.urlopen(LOG_FILE_URL)
    methodFound = False
    urlFound = False
    for line in data:
        if GET_SPAN in line:
            print("Found....Method")
            methodFound = True
        if NETWORK_CALL_GET_URL in line:
            print("Found....URL")
            urlFound = True
    delete_log()
    if methodFound == False or urlFound == False:
       exit(1)

#Validating the Netowork PUT API span.
def method_put_validation():
    sleep(5);
    data = urllib.request.urlopen(LOG_FILE_URL)
    methodFound = False
    urlFound = False
    for line in data:
        if PUT_SPAN in line:
            print("Found....Method")
            methodFound = True
        if NETWORK_CALL_PUT_URL in line:
            print("Found....URL")
            urlFound = True
    delete_log()
    if methodFound == False or urlFound == False:
       exit(1)

#Validating the Netowork DELETE API span.
def method_delete_validation():
    sleep(5);
    data = urllib.request.urlopen(LOG_FILE_URL)
    methodFound = False
    urlFound = False
    for line in data:
        if DELETE_SPAN in line:
            print("Found....Method")
            methodFound = True
        if NETWORK_CALL_DELETE_URL in line:
            print("Found....URL")
            urlFound = True
    delete_log()
    if methodFound == False or urlFound == False:
       exit(1)

#Validating the Screen tracking span.
def screen_track_validation():
    sleep(5);
    data = urllib.request.urlopen(LOG_FILE_URL)

    screenChangeFound = False
    showSpanFound = False
    screenTrackVCFound = False
    customeScreenTrackVCFound = False

    for line in data:
        if SCREEN_CHANGE_SPAN in line:
            print("Found....Screen_Change_Span")
            screenChangeFound = True
        if SHOWVC_SPAN in line:
            print("Found....Show_VC_Span")
            showSpanFound = True
        if SCREEN_TRACK_VC in line:
            print("Found....Screen_Track_VC")
            screenTrackVCFound = True
        if CUSTOME_SCREEN_TRACK_VC in line:
            print("Found....Custome_Screen_Track_VC")
            customeScreenTrackVCFound = True
    delete_log()
    if screenChangeFound == False or showSpanFound == False or screenTrackVCFound == False or customeScreenTrackVCFound == False:
       exit(1)
