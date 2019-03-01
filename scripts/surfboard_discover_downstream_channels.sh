#1/bin/sh

#MIT License
#
#Copyright (c) 2019 Rob McCready
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.


# Get modem address from command line or default it
modemAddress=$1
if test -z "$modemAddress"
then
	modemAddress=192.168.100.1
fi


# Retrieve status webpage and parse tables into XML
CURL_OUTPUT=$(curl -s http://$modemAddress/cgi-bin/status 2>/dev/null | hxnormalize -x -d -l 256 2> /dev/null | hxselect -i 'table.simpleTable' | sed 's/ kSym\/s//g' | sed 's/ MHz//g' | sed 's/ dBmV//g' | sed 's/ dB//g' | sed 's/<td> */<td>/g')
STATUS_XML="<tables>$CURL_OUTPUT</tables>"


# Pull out downstream channel data and format INDEX and CHANNEL IDs into discovery format
echo "{"
echo '"data": ['

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "concat('{%{#INDEX}%: %', position()-1, '%, %{#CHANNELID}%: %', td[position()=4], '%},')" -n | sed 's/%/"/g' | sed '$ s/.$//'

echo ']'
echo "}"
