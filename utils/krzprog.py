#!/usr/bin/python3

import os
import re
import argparse

MAX_PROG_SIZE = 128*1024

def convert_bin(ibinfile):
    obinfile = re.sub('.bin$', '.krz.bin', ibinfile)

    IFILE = open(ibinfile, "rb")
    OFILE = open(obinfile, "wb")

    progbytes = IFILE.read();
    progsize = len(progbytes)

    print("processing {}".format(ibinfile))
    print("size: {}B".format(progsize))

    if (progsize > MAX_PROG_SIZE):
        print("[ERROR] program is too large. Max program size = {}".format(MAX_PROG_SIZE))

    if (progsize & 0x3):
        print("[ERROR] program is not word-aligned")

    OFILE.write((progsize).to_bytes(4, byteorder='little'))
    OFILE.write(progbytes);

    IFILE.close();
    OFILE.close()

    # memfile for tests
    new_memfile = re.sub('bin$', 'mem', obinfile)
    cmd = "srec_cat {} -binary -byte-swap 4 -o {} -vmem".format(obinfile, new_memfile)
    os.system(cmd)

    print("Ready to Flash: {}".format(obinfile))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='RISCV Binary formatter for KRZ')
    parser.add_argument('--bin', default=None, help="--bin <file.bin> Specify binary file to be processed")

    args = parser.parse_args()

    convert_bin(args.bin)
