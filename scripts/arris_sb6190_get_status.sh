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
if [ -z "$modemAddress" ]; then
  modemAddress=192.168.100.1
fi

username=$2
if [ -z "$username" ]; then
  username=admin
fi

password=$3
if [ -z "$password" ]; then
  password=
fi

#echo $modemAddress $username $password

#
# Validate dependencies are available
#

if ! [ -x "$(command -v awk)" ]; then
  echo '{"success": 0, "message": "awk command not found"}'
  exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
  echo '{"success": 0, "message": "curl command not found"}'
  exit 1
fi

if ! [ -x "$(command -v hxnormalize)" ]; then
  echo '{"success": 0, "message": "hxnormalize command not found"}'
  exit 1
fi

if ! [ -x "$(command -v hxselect)" ]; then
  echo '{"success": 0, "message": "hxselect command not found"}'
  exit 1
fi

if ! [ -x "$(command -v sed)" ]; then
  echo '{"success": 0, "message": "sed command not found"}'
  exit 1
fi

if ! [ -x "$(command -v xmlstarlet)" ]; then
  echo '{"success": 0, "message": "xmlstarlet command not found"}'
  exit 1
fi


rm -f /tmp/arris_sb6190_get_status.cookies

curl \
  -s \
  -c /tmp/arris_sb6190_get_status.cookies \
  -d "username=$username&password=$password&ar_nonce=87580161" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST http://$modemAddress/cgi-bin/adv_pwd_cgi >/dev/null 2>&1


#
# Check for a valid response code then do second call for data
#
RESPONSE_CODE=$(curl -b /tmp/arris_sb6190_get_status.cookies -s -o /dev/null -w "%{http_code}" http://$modemAddress/cgi-bin/status)
if [ $RESPONSE_CODE -ne 200 ]; then
  echo '{"success": 0, "message": "HTTP failure code: '$RESPONSE_CODE'"}'
  exit 1
fi

# Retrieve status webpage and parse tables into XML
CURL_OUTPUT=$(curl -b /tmp/arris_sb6190_get_status.cookies -s http://$modemAddress/cgi-bin/status 2>/dev/null | hxnormalize -x -d -l 256 2> /dev/null | hxselect -i 'table.simpleTable' | sed 's/ kSym\/s//g' | sed 's/ MHz//g' | sed 's/ dBmV//g' | sed 's/ dB//g' | sed 's/<td> */<td>/g')
STATUS_XML="<tables>$CURL_OUTPUT</tables>"

echo "{"
echo '"http_status": '$RESPONSE_CODE', '

# Print all status config elements
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/text() = 'Startup Procedure') and (position()>2)]" -v "concat('%', translate(td[position()=1], 'ABCDEFGHIJKLMNOPQRSTUVWXYZ ', 'abcdefghijklmnopqrstuvwxyz_'), '%: %', td[position()=2], '%,')" -n | sed 's/%/"/g'


# Calculate Downstream Channel Count
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=1]" -n | awk 'END { print "\"downstream_channels\": \"" NR "\","}'


# Calculate Downstream Power stats
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=6]" -n | awk '{ if(min == "" || $1 < min) {min=$1} } END { print "\"downstream_power_minimum\": \"" min "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=6]" -n | awk '{ total += $1 } END { print "\"downstream_power_average\": \"" total/NR "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=6]" -n | awk '{ if(max == "" || $1 > max) {max=$1} } END { print "\"downstream_power_maximum\": \"" max "\","}'


# Calculate Downstream SNR stats
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=7]" -n | awk '{ if(min == "" || $1 < min) {min=$1} } END { print "\"downstream_snr_minimum\": \"" min "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=7]" -n | awk '{ total += $1 } END { print "\"downstream_snr_average\": \"" total/NR "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=7]" -n | awk '{ if(max == "" || $1 > max) {max=$1} } END { print "\"downstream_snr_maximum\": \"" max "\","}'


# calculate corrected & uncorrectable totals
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=8]" -n | awk '{ total += $1 } END { print "\"downstream_corrected_total\": \"" total "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "td[position()=9]" -n | awk '{ total += $1 } END { print "\"downstream_uncorrectable_total\": \"" total "\","}'


# Calculate Upstream Channel Count
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Upstream Bonded Channels') and (position()>2)]" -v "td[position()=1]" -n | awk 'END { print "\"upstream_channels\": \"" NR "\","}'


# Calculate Upstream Rate stats
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Upstream Bonded Channels') and (position()>2)]" -v "td[position()=5]" -n | awk '{ if(min == "" || $1 < min) {min=$1} } END { print "\"upstream_symbol_rate_minimum\": \"" min "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Upstream Bonded Channels') and (position()>2)]" -v "td[position()=5]" -n | awk '{ total += $1 } END { print "\"upstream_symbol_rate_average\": \"" total/NR "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Upstream Bonded Channels') and (position()>2)]" -v "td[position()=5]" -n | awk '{ if(max == "" || $1 > max) {max=$1} } END { print "\"upstream_symbol_rate_maximum\": \"" max "\","}'


# Calculate Upstream Power stats
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Upstream Bonded Channels') and (position()>2)]" -v "td[position()=7]" -n | awk '{ if(min == "" || $1 < min) {min=$1} } END { print "\"upstream_power_minimum\": \"" min "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Upstream Bonded Channels') and (position()>2)]" -v "td[position()=7]" -n | awk '{ total += $1 } END { print "\"upstream_power_average\": \"" total/NR "\","}'

echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Upstream Bonded Channels') and (position()>2)]" -v "td[position()=7]" -n | awk '{ if(max == "" || $1 > max) {max=$1} } END { print "\"upstream_power_maximum\": \"" max "\","}'


# Print all downstream channels
echo '"downstream": ['
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Downstream Bonded Channels') and (position()>2)]" -v "concat('{%index%: %', position()-1, '%, %channel_id%: %', td[position()=4], '%, %lock_status%: %', td[position()=2], '%, %modulation%: %', td[position()=3], '%, %frequency%: %', td[position()=5], '%, %power%: %', td[position()=6], '%, %snr%: %', td[position()=7], '%, %corrected%: %', td[position()=8], '%, %uncorrectables%: %', td[position()=9], '%},')" -n | sed 's/%/"/g' | sed '$ s/.$//'
echo '],'


# Print all upstream channels
echo '"upstream": ['
echo $STATUS_XML | xmlstarlet sel -t -m "//tables/table/tbody/tr[(../tr/th/strong/text() = 'Upstream Bonded Channels') and (position()>2)]" -v "concat('{%index%: %', position()-1, '%, %channel_id%: %', td[position()=4], '%, %lock_status%: %', td[position()=2], '%, %channel_type%: %', td[position()=3], '%, %symbol_rate%: %', td[position()=5], '%, %frequency%: %', td[position()=6], '%, %power%: %', td[position()=7], '%},')" -n | sed 's/%/"/g' | sed '$ s/.$//'
echo ']'

echo "}"
