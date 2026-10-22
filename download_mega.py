#!/usr/bin/env python3
import sys
import os
import struct
import base64
import json
import requests
from Cryptodome.Cipher import AES
from Cryptodome.Util import Counter

def base64_url_decode(data):
    data += '=' * ((4 - len(data) % 4) % 4)
    return base64.urlsafe_b64decode(data)

def a32_to_str(a):
    return struct.pack('>%dI' % len(a), *a)

def str_to_a32(b):
    if len(b) % 4:
        b += b'\0' * (4 - len(b) % 4)
    return struct.unpack('>%dI' % (len(b) / 4), b)

def download_mega_file(url, out_path):
    print(f"[*] Processing Mega URL: {url}")
    # Extract file_id and file_key
    if "#" in url:
        parts = url.split("/file/")[1].split("#")
        file_id, file_key_str = parts[0], parts[1]
    else:
        raise ValueError("Invalid URL format, expected /file/ID#KEY")
    
    key_bytes = base64_url_decode(file_key_str)
    file_key = str_to_a32(key_bytes)
    
    # 128-bit key derived by XORing the halves
    k = (file_key[0] ^ file_key[4], file_key[1] ^ file_key[5],
         file_key[2] ^ file_key[6], file_key[3] ^ file_key[7])
    iv = (file_key[4], file_key[5])
    
    # Query Mega API for download link
    api_url = "https://g.api.mega.co.nz/cs"
    payload = [{"a": "g", "g": 1, "p": file_id}]
    resp = requests.post(api_url, json=payload).json()
    if isinstance(resp, list):
        data = resp[0]
    else:
        data = resp
        
    if "g" not in data:
        raise RuntimeError(f"Mega API error: {data}")
        
    dl_url = data["g"]
    file_size = data["s"]
    print(f"[*] File size: {file_size} bytes ({file_size / 1024 / 1024:.2f} MB)")
    print(f"[*] Downloading from CDN...")
    
    # Prepare AES-CTR decryptor
    k_bytes = a32_to_str(k)
    initial_counter = ((iv[0] << 32) + iv[1]) << 64
    counter = Counter.new(128, initial_value=initial_counter)
    cipher = AES.new(k_bytes, AES.MODE_CTR, counter=counter)
    
    # Stream download and decrypt
    r = requests.get(dl_url, stream=True)
    r.raise_for_status()
    
    downloaded = 0
    with open(out_path, "wb") as f:
        for chunk in r.iter_content(chunk_size=65536):
            if chunk:
                decrypted = cipher.decrypt(chunk)
                f.write(decrypted)
                downloaded += len(chunk)
                print(f"\r[*] Progress: {downloaded}/{file_size} bytes ({downloaded*100//file_size}%)", end="", flush=True)
                
    print(f"\n[+] Successfully saved to {out_path} ({os.path.getsize(out_path)} bytes)")

if __name__ == "__main__":
    url = sys.argv[1]
    out = sys.argv[2]
    download_mega_file(url, out)
