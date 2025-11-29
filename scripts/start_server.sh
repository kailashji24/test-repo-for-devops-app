#!/bin/bash
cd /home/ec2-user/app
# Start the jar file (Adjust the path if your jar is named differently after build)
nohup java -jar target/*.jar > /dev/null 2> /dev/null < /dev/null &