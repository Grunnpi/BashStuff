ps -leaf | grep -i sboub | grep -v sboub | awk '{ system("sudo su - iamgroot -c \047/usr/bin/kill -9 " $4 "\047") }'
