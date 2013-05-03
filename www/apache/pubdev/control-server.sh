#!/bin/bash

#
# usage ./control-server.sh start
# or ./control-server.sh stop
# 

if [ -z "$HTTPD" ]
then
  HTTPD=`which httpd`
fi

if [ -z "$HTTPD" ]
then
  echo cannot find apache httpd binary or HTTPD environment variable
  exit
fi

# echo using httpd:  $HTTPD

$HTTPD -d $PWD -k "$@"
