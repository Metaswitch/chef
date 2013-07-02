#!/bin/bash

case $1 in
start)
        /usr/local/freeswitch/bin/freeswitch -ncwait
;;

stop)
        /usr/local/freeswitch/bin/freeswitch -stop
;;

restart)
        /usr/local/freeswitch/bin/freeswitch -stop
        /usr/local/freeswitch/bin/freeswitch -ncwait
;;

esac
