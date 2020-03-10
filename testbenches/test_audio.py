import serial
import time
import sys

ser = serial.Serial("COM166", 9600)

def read(ser):
    if (ser.inWaiting()>0):
        sys.stdout.write(ser.read(ser.inWaiting()).decode("utf-8"))


def write16(ser, address, value):
    ser.write(b"?w%04X%02X" % (address, value & 0xFF))
    time.sleep(0.01)
    read(ser)
    ser.write(b"?w%04X%02X" % (address+1, (value>>8) & 0xFF))
    time.sleep(0.01)
    read(ser)
    
def write8(ser, address, value):
    ser.write(b"?w%04X%02X" % (address, value & 0xFF))
    time.sleep(0.01)
    read(ser)

def write_note(ser, value):
    write16(ser, 0x0100, value)

def write_volume(ser, value):
    write8(ser, 0x0118, value)

# some notes
A3  = 3691
A3s = 3910
B3  = 4143
C4  = 4389
C4s = 4650
D4  = 4927
D4s = 5220
E4  = 5530
F4  = 5859
F4s = 6207
G4  = 6577
G4s = 6968
A4  = 7382
A4s = 7821
B4  = 8286
C5  = 8779
C5s = 9301
D5  = 9854
D5s = 10440
E5  = 11060
F5  = 11718
F5s = 12415
G5  = 13153
G5s = 13935
A5  = 14762
A5s = 15642
B5  = 16572

SID_OFFSET_VOICE1_FREQ    = (0x0100) # 16 bit
SID_OFFSET_VOICE1_PW      = (0x0102) # 16/12 bit
SID_OFFSET_VOICE1_CONTROL = (0x0104) 
SID_OFFSET_VOICE1_ATTDEC  = (0x0105)
SID_OFFSET_VOICE1_SSTREL  = (0x0106)
SID_OFFSET_VOICE2_FREQ    = (0x0107) # 16 bit
SID_OFFSET_VOICE2_PW      = (0x0109) # 16/12 bit
SID_OFFSET_VOICE2_CONTROL = (0x010B)
SID_OFFSET_VOICE2_ATTDEC  = (0x010C)
SID_OFFSET_VOICE2_SSTREL  = (0x010D)
SID_OFFSET_FILT           = (0x0115) # 16/12 bit
SID_OFFSET_RESFILT        = (0x0117)
SID_OFFSET_MODEVOL        = (0x0118)

VOICE_NOISE = 0x80
VOICE_PULSE = 0x40
VOICE_SAW   = 0x20
VOICE_TRI   = 0x10
VOICE_GATE  = 0x01

write16(ser, SID_OFFSET_VOICE1_PW, 0x800)

write16(ser, SID_OFFSET_VOICE1_CONTROL, 0)
write_note(ser, A3)

write_volume(ser, 15)

write16(ser, SID_OFFSET_VOICE1_ATTDEC, 0xFF)
write16(ser, SID_OFFSET_VOICE1_SSTREL, 0xF9)
write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_TRI | VOICE_GATE)
for i in range(128):
    write16(ser, SID_OFFSET_VOICE1_FREQ, 0x6FFF - (i << 7))
    time.sleep(0.01)
#time.sleep(2)
write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_NOISE | 0)
time.sleep(5)

#write_volume(ser, 0)
#write_note(ser, A5); time.sleep(0.5)
#print("Pulse")
#for i in range(15):
#    write_volume(ser, i)
#    time.sleep(0.1)
#for i in range(15):
#    write_volume(ser, 15-i)
#    time.sleep(0.1)
#
#print("Triangle")
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_TRI | VOICE_GATE)
#for i in range(15):
#    write_volume(ser, i)
#    time.sleep(0.1)
#for i in range(15):
#    write_volume(ser, 15-i)
#    time.sleep(0.1)
#    
#print("Saw")
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_SAW | VOICE_GATE)
#for i in range(15):
#    write_volume(ser, i)
#    time.sleep(0.1)
#for i in range(15):
#    write_volume(ser, 15-i)
#    time.sleep(0.1)
#
#print("Noise")
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_NOISE | VOICE_GATE)
#for i in range(15):
#    write_volume(ser, i)
#    time.sleep(0.1)
#for i in range(15):
#    write_volume(ser, 15-i)
#    time.sleep(0.1)
    
#write_note(ser, E5); time.sleep(0.5)
#write_note(ser, D5); time.sleep(0.5)
#write_note(ser, F5); time.sleep(0.5)
#write_note(ser, G5); time.sleep(0.5)

write_volume(ser, 0)
read(ser)
