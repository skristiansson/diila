#!/usr/bin/python
import sys
import datetime
import collections
import ConfigParser

version = 1.0
clk_period = 20 # in ns
sample_cnt = 1024

class Signal:
    def __init__(self, name, offset, bits, ascii_id):
        self.name = name
        self.bits = bits
        self.offset = offset
        self.id = ascii_id

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

def read_config():
    cfg = ConfigParser.RawConfigParser(dict_type=collections.OrderedDict)
    cfg.read('dump2vcd.conf')
    return cfg

def read_dump(filename):
    f = open(filename, 'r')
    data = []
    for line in f:
        addr_str, data_str = line.split(':')
        data.extend(data_str.strip().split('\t'))

    return data

if __name__ == "__main__":
    args = sys.argv[1:]

    data = read_dump(args[0])
    cfg = read_config()

    # build signals
    signals = []
    i = 1
    offset = 0
    for signal in cfg.options('signals'):
        bit_cnt = int(cfg.get('signals', signal))
        signals.append(Signal(signal, offset, bit_cnt, chr(33 + i)))
        offset += bit_cnt
        if not signal.startswith('empty'):
            i += 1

    print vcd_header()
    print "$scope module diila $end"
    print "$var wire 1 {0} clk $end".format(chr(33+0))

    for signal in signals:
        if not signal.name.startswith('empty'):
            print "$var wire {0} {1} {2} $end".format(signal.bits, signal.id,
                                                      signal.name)
    print "$upscope $end"
    print "$enddefinitions $end"
    print "$dumpvars"
    print "1{0}".format(chr(33+0)) # clk signal

    for signal in signals:
        if not signal.name.startswith('empty'):
            binary = bin(0)[2:0].zfill(signal.bits)
            if signal.bits > 1:
                print "b{0} {1}".format(binary, signal.id)
            else:
                print "{0}{1}".format(binary, signal.id)

    print "$end"

    for i in range(sample_cnt):
        print "#{0}".format(i * clk_period)
        print "1{0}".format(chr(33+0))

        # Print signals
        for signal in signals:
            if not signal.name.startswith('empty'):
                # Calculate in what 32-bit word the signal is
                first_word = int(signal.offset/32);
                last_word = int((signal.offset + signal.bits - 1)/32);
                bit_offset = signal.offset - first_word*32
                # Get bit vector composed of all needed words
                def get_word_bits(word):
                    word_value = int(data[i + sample_cnt*word], 16)
                    return bin(word_value)[2:].zfill(32)
                words_needed = range(first_word, last_word+1)
                words_bin_value = "".join(map(get_word_bits, words_needed))
                # Pick out the signal from the words
                bin_value = words_bin_value[bit_offset:bit_offset+signal.bits]
                if signal.bits > 1:
                    print "b{0} {1}".format(bin_value, signal.id)
                else:
                    print "{0}{1}".format(bin_value, signal.id)

        print "#{0}".format(i * clk_period + clk_period/2)
        print "0{0}".format(chr(33+0))
