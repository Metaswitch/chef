#!/bin/bash

export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/

case $1 in
start)
        cd /opt/OpenIMSCore/FHoSS/deploy
        nohup ./startup.sh &
;;

stop)
        pkill -f HSSContainer
;;

restart)
        pkill -f HSSContainer
        cd /opt/OpenIMSCore/FHoSS/deploy
        nohup ./startup.sh &
;;

status)
        pgrep -f HSSContainer >/dev/null
        exit $?
;;

esac
