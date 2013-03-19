#!/usr/bin/python
import sys
import datetime

version = 1.0
clk_period = 20 # in ns

def vcd_header():
    header = ("$date\n"
              "    {0}\n"
              "$end\n"
              "$version\n"
              "    dump2vcd {1}\n"
              "$end\n"
              "$timescale\n"
              "    1ns\n"
              "$end")
    return header.format(datetime.datetime.now().ctime(), version)

if __name__ == "__main__":
    args = sys.argv[1:]
    print args[0]

    f = open(args[0], 'r')
    data = []
    for line in f:
        addr_str, data_str = line.split(':')
        data.extend(data_str.strip().split('\t'))

    trig0 = []
    data0 = []
    data1 = []
    data2 = []
    for i in range(1024):
        trig0.append(data[i + 1024*0])
        data0.append(data[i + 1024*1])
        data1.append(data[i + 1024*2])
        data2.append(data[i + 1024*3])

    print vcd_header()
    print "$scope module trace_logger $end"
    print "$var wire 1 {0} clk $end".format(chr(33+0))
    print "$var wire 32 {0} trig0 $end".format(chr(33+1))
    print "$var wire 32 {0} data0 $end".format(chr(33+2))
    print "$var wire 32 {0} data1 $end".format(chr(33+3))
    print "$var wire 32 {0} data2 $end".format(chr(33+4))
    print "$upscope $end"
    print "$enddefinitions $end"
    print "$dumpvars"
    print "1{0}".format(chr(33+0))
    print "b000000000000000000 {0}".format(chr(33+1))
    print "b000000000000000000 {0}".format(chr(33+2))
    print "b000000000000000000 {0}".format(chr(33+3))
    print "b000000000000000000 {0}".format(chr(33+4))
    print "$end"

    for i in range(1024):
        print "#{0}".format(i * clk_period)
        print "1{0}".format(chr(33+0))

        print "b{0} {1}".format(bin(int(trig0[i], 16))[2:].zfill(32), chr(33+1))
        print "b{0} {1}".format(bin(int(data0[i], 16))[2:].zfill(32), chr(33+2))
        print "b{0} {1}".format(bin(int(data1[i], 16))[2:].zfill(32), chr(33+3))
        print "b{0} {1}".format(bin(int(data2[i], 16))[2:].zfill(32), chr(33+4))

        print "#{0}".format(i * clk_period + clk_period/2)
        print "0{0}".format(chr(33+0))
