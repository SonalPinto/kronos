#!/usr/bin/python3

import re
import argparse

def bin2mem(ibinfile):
    obinfile = re.sub('.bin$', '.mem', ibinfile)

    IFILE = open(ibinfile, "rb")
    OFILE = open(obinfile, "w")

    progbytes = IFILE.read();
    progsize = len(progbytes)

    print("processing {}".format(ibinfile))
    print("program size: {} bytes".format(progsize))

    word = []
    for i, x in enumerate(progbytes):
      word.append(x)
      if i & 0x3 == 0x3:
        OFILE.write(''.join('{:02X}'.format(b) for b in reversed(word)))
        OFILE.write("\n")
        word = []

    IFILE.close()
    OFILE.close()

    print("Memory file: {}".format(obinfile))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='RISCV Binary to SystemVerilog Memory Converter')
    parser.add_argument('--bin', default=None, help="--bin <file.bin> Specify binary file to be processed")

    args = parser.parse_args()

    bin2mem(args.bin)
