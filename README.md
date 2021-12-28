# ddns_azure_function
Update a series of domain records in DDNS, based on an HTTP request.

# how it works

A powershell function app takes the following 4 params and will add/update a DNS zone record set to reflect a given IP address. 

Params are: Group (resource group), Name (site / hostname), Zone (e.g. mysite.com) and the reqIP.

Note: it's very important that the body response contains the word "good <ip>" as its response format as the Syno DDNS system expects this in order to report success. 

References:
https://community.synology.com/enu/forum/17/post/57640
