#!/usr/bin/python3

import sys
import os
import re

def main():
    ibinfile = sys.argv[1]
    obinfile = ibinfile + ".ready"

    IFILE = open(ibinfile, "rb")
    OFILE = open(obinfile, "wb")

    progbytes = IFILE.read();

    OFILE.write((len(progbytes)).to_bytes(4, byteorder='little'))
    OFILE.write(progbytes);

    IFILE.close();
    OFILE.close()

    new_memfile = re.sub('bin.ready', 'mem.ready', obinfile)
    cmd = "srec_cat {} -binary -byte-swap 4 -o {} -vmem".format(obinfile, new_memfile)

    os.system(cmd)

if __name__ == '__main__':
    main()
