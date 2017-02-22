#!/bin/sh
# Copyright (c) 2017 Andrejs Mivreņiks
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
TRAKT_CLIENT_ID='fc9742bb96e86fdfdd163086eb95712f7657a86f051f75e04e5334a5d2b40f64'
TRAKT_CLIENT_SECRET='040e67a1c45d81a807f92d079c4d60a578e3cf3b31d1bbc6a802012e7523db4c'

authorize_url="https://trakt.tv/oauth/authorize?response_type=code&client_id=${TRAKT_CLIENT_ID}&redirect_uri=urn:ietf:wg:oauth:2.0:oob"

echo 'We need to authorize on trakt.tv first.'
echo 'Please open the following link in your web browser:'
echo "$authorize_url"
echo
xdg-open "$authorize_url"
echo -n 'Enter a code: '; read -r auth_code

# Decide where to put an auth token
if [ -z "$XDG_DATA_HOME" ]; then
	token_file="$XDG_DATA_HOME/mpv-trakt/credentials.json"
else
	token_file="$HOME/.local/share/mpv-trakt/credentials.json"
fi
mkdir -p "${token_file%/*}"

# Request an auth token
token_url='https://api.trakt.tv/oauth/token'
token_request_body="{\"client_id\": \"${TRAKT_CLIENT_ID}\",\"client_secret\": \"${TRAKT_CLIENT_SECRET}\",\"code\": \"${auth_code}\",\"grant_type\": \"authorization_code\",\"redirect_uri\": \"urn:ietf:wg:oauth:2.0:oob\"}"
token_response_status=$(curl -s \
						-w '%{http_code}' \
						-H "Content-Type: application/json" \
						-X POST \
						-d "$token_request_body" \
						-o "$token_file" \
						"$token_url")

case "$token_response_status" in
    '200')
        echo 'Athorization succeeded'
        ;;
	'401')
        echo 'Authorization failed. Please try again.'
        rm "$token_file"
        exit 1
		;;
    *)
        echo "Unexpected trakt.tv API response code: $http_status_code"
        echo 'Authorization failed. Please try again.'
        rm "$token_file"
        exit 1
esac

# TODO Put the script to ${HOME}/.config/mpv/scripts
