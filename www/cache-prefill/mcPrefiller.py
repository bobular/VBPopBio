#########################################################################################################
#
# Script to automatically prefill the mem-cache for PopBio.
#
# Opens the PopBio projects page, grabs the list of projects and URLs, opens each one and 
# waits until there no more AJAX requests.
#
#
# Requirements: 
# - PhantomJS
# - python::selenium
# - python::multiprocessing
#
#
# Command line parameters:
# - URL of the PopBio projects list
# - if empty, directs to http://www.vectorbase.org/popbio/projects
#
#
#
# Adapted from http://sullerton.com/2013/08/selenium-webdriver-wait-for-ajax-with-python/
# for selenium webdriver waiting for ajax commands to complete
#############################################################################################################


# import libraries
from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.common.exceptions import WebDriverException
import sys, multiprocessing



# the url of the popbio projects list page
# if empty, defaults to http://www.vectorbase.org/popbio/projects
try:
	sys.argv[1]
except: 
	projectpage = "http://www.vectorbase.org/popbio/projects"
else:
	projectpage = sys.argv[1]

	


# time in seconds to timeout per URL
timeout_max = 3600 # = 1hr

# number of instances to navigate to each project page
numInstances = 3




# get number of active AJAX requests. Returns True if no active connections
def ajax_complete(driver):
	if (driver.execute_script("return Ajax.activeRequestCount") > 0):
		return False
	else:
		return True


# navigates to given URL and waits until Ajax commands have finished
def navigator(url):
	print url
	driver = webdriver.PhantomJS()
	driver.get(url)
	WebDriverWait(driver, timeout_max).until(ajax_complete,  "Timeout")
	driver.quit()



# load instance of webdriver
w_driver = webdriver.PhantomJS() 

# opens the pop bio main page with list of projects and URLS
w_driver.get(projectpage)
WebDriverWait(w_driver, timeout_max).until(ajax_complete,  "Timeout") # wait to load completely


# get all the URL's that matches ?id=VBP - these are the URLS for each project
linkArray = []
ListlinkerHref = w_driver.find_elements_by_tag_name("a")
for i in ListlinkerHref:
	link = i.get_attribute('href')
	if str(link).count("?id=VBP") > 0:
		linkArray.append(link)
urls = set(linkArray)
w_driver.quit()


# multiprocessing
# multiple instances to navigate to each project's page
pool = multiprocessing.Pool(numInstances)
pool.map(navigator, urls)
pool.close()



