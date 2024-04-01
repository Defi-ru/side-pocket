#!/bin/bash
# ScriptName: rlauncher.sh
# Help orginize cyrcle for command


FILE="users.txt"

if [ ! -f $FILE ]; then
        echo -e "Error! $FILE file is not exist..."
        exit 2
fi

while read user
do
    # Print command here:
    # - - -
    ./pocket-openvpn.sh useradd $user
    # - - -
done < $FILE

exit 0
