import serial
import time
import sys
import math
import re

ser = serial.Serial("COM168", 9600)

def read(ser):
    if (ser.inWaiting()>0):
        return ser.read(ser.inWaiting())

def write16(ser, address, value):
    ser.write(b"?w%04X%02X" % (address, value & 0xFF))
    #time.sleep(0.01)
    ser.write(b"?w%04X%02X" % (address+1, (value>>8) & 0xFF))
    #time.sleep(0.01)
    #read(ser)
    response = read(ser).decode("utf-8").strip()
    if response not in ["OKOK", "OK"]:
        print("0x%04X" % (address), response)
    #sys.stdout.write(read(ser).decode("utf-8"))
    
def write8(ser, address, value):
    ser.write(b"?w%04X%02X" % (address, value & 0xFF))
    #time.sleep(0.01)
    #read(ser)
    response = read(ser).decode("utf-8").strip()
    if response != "OK":
        print(response)
    #sys.stdout.write(read(ser).decode("utf-8"))

def read16(ser, address):
    time.sleep(0.01)
    read(ser)
    ser.write(b"?r%04X" % (address+1))
    #time.sleep(0.02)
    ser.write(b"?r%04X" % (address))
    time.sleep(0.01)
    output = read(ser).decode("utf-8")
    #sys.stdout.write(output)
    output = re.sub(r"\s+", "", output)
    return int(output, 16)
    
LED_MATRIX_OFFSET = (0x0400)
FRAME_OFFSET      = (0x1000)

#for i in range(1024):
#    colour = 0x0000;
#    write16(ser, FRAME_OFFSET + i*2, 0)

def clear():
    for i in range(256):
        write16(ser, FRAME_OFFSET + (i*2), 0)

clear()

for x in range(8):
    for y in range(8):
        r = (x * 32) & 0xFF
        g = (0) & 0xFF
        b = (y * 32) & 0xFF
        colour = ((b >> 3) << 11) | ((g >> 2) << 5) | (r >> 3);
        write16(ser, FRAME_OFFSET +  0 + (x*2) + (y * 64), colour)
        #if x in [0,1] and y in [1,5]:
        #write16(ser, FRAME_OFFSET + 16 + (x*2) + (y * 64), colour)

    
#write16(ser, FRAME_OFFSET + 32 + 0, 0x001F)
#write16(ser, FRAME_OFFSET + 32 + 2, 0x07E0)
#write16(ser, FRAME_OFFSET + 32 + 4, 0xF800)
#write16(ser, FRAME_OFFSET + 32 + 6, 0x0000)

#write16(ser, FRAME_OFFSET + 0x040, 0x001F)
#write16(ser, FRAME_OFFSET + 0x080, 0x07E0)
#write16(ser, FRAME_OFFSET + 0x0C0, 0xF800)
#write16(ser, FRAME_OFFSET + 0x100, 0x0000)

#write16(ser, FRAME_OFFSET + 16, 0x0000)
#write16(ser, FRAME_OFFSET + 18, 0x0000)
#write16(ser, FRAME_OFFSET + 20, 0x0000)
#write16(ser, FRAME_OFFSET + 22, 0x0000)
#
#write16(ser, FRAME_OFFSET + 24, 0x0000)
#write16(ser, FRAME_OFFSET + 26, 0x0000)
#write16(ser, FRAME_OFFSET + 28, 0x0000)
#write16(ser, FRAME_OFFSET + 30, 0x0000)



print("0x%04X" % (read16(ser, FRAME_OFFSET +  0)))
print("0x%04X" % (read16(ser, FRAME_OFFSET +  2)))
print("0x%04X" % (read16(ser, FRAME_OFFSET +  4)))
print("0x%04X" % (read16(ser, FRAME_OFFSET +  6)))
print("0x%04X" % (read16(ser, FRAME_OFFSET +  8)))
print("0x%04X" % (read16(ser, FRAME_OFFSET + 10)))
print("0x%04X" % (read16(ser, FRAME_OFFSET + 12)))
print("0x%04X" % (read16(ser, FRAME_OFFSET + 14)))


for x in range(8):
    line = ''
    for y in range(8):
        line += " %04X" % (read16(ser, FRAME_OFFSET + (x*2) + (y*64)))

    print(line)
