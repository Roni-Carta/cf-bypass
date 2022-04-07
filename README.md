# CF-Bypass 


## Description

This tool is a simple bypass for a website running Cloudflare by finding the Origin IP of the domain. By doing so we are able to access the website without going trough Cloudflare's IP

This comes from a Misconfiguration on the Origin IP, that should not allow traffic outside of Cloudflare. 


## Install

Clone the project and run the following command

```bash
chmod u+x install.sh && ./install.sh
```


## Usage

```
CF-Bypass is a Scanner that will attempt to bypass Cloudflare by finding the Origin IP of the server.
	Usage:
		cf-bypass <flag> [options]

	Flags:
		check <hostname> <host>: Check if you can bypass the provided Hostname using the provided IP/Host

	Options:
		-h: Show this help
		-d: Enable Debugging
		-f: file containing a list of subdomains
		-s: silent output
		-m: Enabling Mode. Available Modes:
			st: Activate Security Trails Detection
			c: Activate Collaborator Detection
	Examples:
		cat subs.txt | cf-bypass [options]; # Uses Security Trails credits
		cf-bypass check www.cloudflare.com 1.1.1.1
		cf-bypass -f subs.txt
		echo www.cloudflare.com | cf-bypass -m st,c
```


## Future Improvements

- Add support for Favicon Hash IP discovery with Shodan
- Add support for Certificate based IP discovery
- Add support for Header based SSRF discovery (X-Forwarded-For: collaborator --> Finding the IP)

