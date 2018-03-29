#!/usr/bin/env python
# m51g
# 2017/12/09

import requests
import wget
import sys
import time

# API: https://api.real-debrid.com/

# CAREFUL: This token is PRIVATE, identifies univocally your user and gives full access to the account!
# Never give it to third parties. You can get it here:
# https://real-debrid.com/apitoken
API_TOKEN = "xxxxx"
hdr = {'Authorization': 'Bearer ' + API_TOKEN }
url = "https://api.real-debrid.com/rest/1.0/"

#resp = s.get( url + 'user', headers=hdr, timeout=7 )	# user info
#       s.post(url + "unrestrict/check", data={'link': link_da_scaricare}) # Check if a file is downloadable on the concerned hoster
#       s.post(url + "unrestrict/link", data={'remote':0, 'link': link_da_scaricare }, headers=hdr)

if len(sys.argv) != 2:
	print("We need the file with all the links")
	exit(1)

s = requests.Session()
resp = s.get( url + 'user', headers=hdr, timeout=7 )
if resp.status_code != 200 or resp.json()['username'] != 'dany_loc':
	print("Error while connecting to real-debrid!")
	exit(2)

with open(sys.argv[1], 'r') as file_in:
	for line in file_in:
		if not line.startswith('http'):
			continue

		link = line.strip()

		resp = s.post(url + "unrestrict/check", data={'link': link})

		try:
			if resp.json()['error']:
				with open('missing.log','a') as log:
					log.write( link + '\t(' + resp.json()['error'] +')\n')
				continue
		except:
			pass
		
		flg = 2
		while flg >= 0:
			resp = 	s.post(url + "unrestrict/link", data={'remote':0, 'link': link }, headers=hdr)
			jresp=resp.json()
			try:
				print(jresp['filename'])
				flg=-5
			except:
				flg=flg-1
				time.sleep(5)
		if flg != -5 :
			with open('missing.log', 'a') as log:
				log.write( link + '\t(' + str(jresp) +')\n')
			continue
		
		print(jresp)
		wget.download( jresp['download'] ,out=jresp['filename'] )
		print('\n')
		
		if time.localtime().tm_hour >= 9 and time.localtime().tm_hour < 23 :  # these 3 lines put to sleep the download until 9 am
			time.sleep(14*3600)
			print("\t... Stopped till evening...")

s.close()
