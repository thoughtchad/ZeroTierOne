#!/bin/bash

echo '*** ZeroTier-Kubernetes self-auth test script'
chown -R daemon /app/vendor/zerotier-one
chgrp -R daemon /app/vendor/zerotier-one
su daemon -s /bin/bash -c '/zerotier-one -d -U -p9993 >>/tmp/zerotier-one.out 2>&1'
dev=""
nwconf=$(ls *.conf)
nwid="${nwconf%.*}"

sleep 10
dev=$(cat /app/vendor/zerotier-one/identity.public| cut -d ':' -f 1)

echo '*** Joining'
./zerotier-cli join "$nwid".conf
# Fill out local service auth token
AUTHTOKEN=$(cat /app/vendor/zerotier-one/authtoken.secret)
sed "s|\local_service_auth_token_replaced_automatically|${AUTHTOKEN}|" .zerotierCliSettings > /root/.zerotierCliSettings
echo '*** Authorizing'
./zerotier-cli net-auth @my.zerotier.com "$nwid" "$dev"
echo '*** Cleaning up' # Remove controller auth token
rm -rf .zerotierCliSettings /root/.zerotierCliSettings
node server.js