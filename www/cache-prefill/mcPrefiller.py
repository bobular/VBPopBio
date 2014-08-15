#########################################################################################################
#
# Script to automatically prefill the mem-cache for PopBio.
#
# Opens the PopBio projects page, grabs the list of projects and URLs, opens each one and 
# waits until there no more AJAX requests. Option to print each URL as it iterates.
#
#
# Requirements (note: these have already been installed globally on vb-dev): 
# - PhantomJS
# - python::selenium
# - python::multiprocessing
#
#
# Command line parameters:
# -   -w <URL of the PopBio projects list> defaults to http://www.vectorbase.org/popbio/projects
# -   -i  <number of parallel threads> defaults to 3
# -   -v <verbose. Prints out URLS of each project page at end of each execution> defaults to false
#
# 
# Usage examples:
# - python mcPrefiller.py
# - python mcPrefiller.py -w http://pre.vectorbase.org/popbio/projects
# - python mcPrefiller.py -w http://pre.vectorbase.org/popbio/projects -i 5 
# - python mcPrefiller.py -i 5 -v
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
import sys, multiprocessing, getopt



# the url of the popbio projects list page
projectpage = "http://www.vectorbase.org/popbio/projects"

# time in seconds to timeout per URL
timeout_max = 3600 # = 1hr

# number of instances to navigate to each project page
numInstances = 3

# print out each project's URL.
verbose = False

# list of project urls
urls = []


try:
	opt, args = getopt.getopt(sys.argv[1:], "w:i:v")
	for o, arg in opt:
		if o == "-w":
			projectpage = arg
		elif o == "-i":
			numInstances = int(arg)
		elif o == "-v":
			verbose = True
except: 	
	print 'Usage: python mcPrefiller.py -w <URL> -i <numInstances> -v <verbose>'
     	sys.exit(2)


# get number of active AJAX requests. Returns True if no active connections
def ajax_complete(driver):
	if (driver.execute_script("return Ajax.activeRequestCount") > 0):
		return False
	else:
		return True


# navigates to given URL and waits until Ajax commands have finished
def navigator(url):	
	driver = webdriver.PhantomJS(desired_capabilities={'phantomjs.page.settings.resourceTimeout': '5000000'})
	driver.get(url)
	WebDriverWait(driver, timeout_max).until(ajax_complete,  "Timeout")
	if verbose:
		print url
	driver.quit()


while (len(urls) == 0):
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


# multiple instances to navigate to each project's page
pool = multiprocessing.Pool(numInstances)
pool.map(navigator, urls)
pool.close()


