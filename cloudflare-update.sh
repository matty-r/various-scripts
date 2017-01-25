#!/bin/bash
# Add cloudflare account details
email="cloudaccount@email.com"
key="cloudflareglobalapikey"
domain="mydomain.com"

ip=$(curl -s http://ipv4.icanhazip.com)

zone_id=$(curl --silent -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}&status=active&page=1&per_page=20&order=status&direction=desc&match=any" \
  -H "X-Auth-Email: ${email}" -H "X-Auth-Key: ${key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
echo "Zone ID: $zone_id"


record_id=$(curl --silent -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${domain}&page=1&per_page=20&order=type&direction=desc&match=any" \
  -H "X-Auth-Email: ${email}" -H "X-Auth-Key: ${key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
echo "Record ID: $record_id"

update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
  -H "X-Auth-Email: ${email}" -H "X-Auth-Key: ${key}" -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"$domain\",\"content\":\"$ip\"}")

if [[ $update == *"\"success\":false"* ]]; then
    message="Failed with:\n$update"
    echo -e "$message"
    exit 1 
else
    message="IP changed to: $ip"
    echo "$message"
fi
