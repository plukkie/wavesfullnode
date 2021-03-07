#! /usr/bin/env python3

import base58
import sys

totalargs = len(sys.argv)

if ( totalargs > 1 ):  ## We found a seed string to encode

    for count in range(1, len(sys.argv)):
        try:
            string += ' ' + str(sys.argv[count])
        except:
            string = sys.argv[count]

else:
    string = input("Unencoded string : ")

base58_string = base58.b58encode(string).decode('UTF-8')

print("base58 string : " + str(base58_string) )

