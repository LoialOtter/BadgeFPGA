import serial
import time
import sys
import math

ser = serial.Serial("COM168", 9600)

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
SID_OFFSET_FILT           = (0x0115) # 16 bit
SID_OFFSET_RESFILT        = (0x0117)
SID_OFFSET_MODEVOL        = (0x0118)
SID_OFFSET_FILTQ          = (0x0119) # 16 bit

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
write16(ser, SID_OFFSET_VOICE1_SSTREL, 0xF3)

write16(ser, SID_OFFSET_VOICE1_FREQ, 62567)

print ('testing new block')
write16(ser, 0x0200, 0x0000)

#                  k             b0          b1           b2                     a1                      a2
coefficients = [[ 1.00, 0.3472149097327731, -0.5066439117653485, 0.20034959965280252, 0.11990724790045414, 0.17411566905137832],
                [ 1.00, 0.3472149097327731, -0.5066439117653485, 0.20034959965280252, 0.11990724790045414, 0.17411566905137832],
                [ 1.00, 0.3472149097327731, -0.5066439117653485, 0.20034959965280252, 0.11990724790045414, 0.17411566905137832],
                [ 1.00, 0.3472149097327731, -0.5066439117653485, 0.20034959965280252, 0.11990724790045414, 0.17411566905137832]]
                #[ 0.10, 0.21018049366874755, 0, -0.21018049366874755, -1.4293001117877477,  0.5796390126625048  ], # f= 70hz, Q=0.8
                #[ 0.10, 0.33582867877810796, 0, -0.33582867877810796, -0.7807802152196699,  0.32834264244378397 ], # f=150hz, Q=0.8
                ##[ 1.00, 0.01616107033877859, 0, -0.01616107033877859, -1.9634257372307398,  0.9676778593224429  ]  # f=523.25hz, Q=0.8
                #[ 1.0, 0.0032745502573856993, 0, -0.0032745502573856993, -1.9891430822435663, 0.9934508994852287 ]
                #]

line_num = 0
for line in coefficients:
    write16(ser, 0x0220 + (line_num*12) +  0, (0xFFFF & int( line[0] *16384))) # 0-k
    write16(ser, 0x0220 + (line_num*12) +  2, (0xFFFF & int(-line[4] *16384))) # 0-a1
    write16(ser, 0x0220 + (line_num*12) +  4, (0xFFFF & int(-line[5] *16384))) # 0-a2
    write16(ser, 0x0220 + (line_num*12) +  6, (0xFFFF & int( line[1] *16384))) # 0-b0
    write16(ser, 0x0220 + (line_num*12) +  8, (0xFFFF & int( line[2] *16384))) # 0-b1
    write16(ser, 0x0220 + (line_num*12) + 10, (0xFFFF & int( line[3] *16384))) # 0-b2
    line_num = line_num + 1

write16(ser, 0x0200, 0x0001)
        
write16(ser, 0x0202, 0x0000)
write16(ser, 0x0204, 0x0000)
write16(ser, 0x0206, 0x0000)
write16(ser, 0x0208, 0x7FFF)
print ('written')


freq = 2600
fsample = 1000000

f = 2 * math.sin((math.pi * freq) / (fsample))
print(f)
print(int(f * (1<<16)))

write16(ser, SID_OFFSET_FILT, int(f * (1<<16)))

write16(ser, SID_OFFSET_FILTQ, int(1.0 * (1<<12)))

write16(ser, SID_OFFSET_MODEVOL, 0x07)
write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_NOISE | VOICE_GATE)
#for i in range(64):
#    freq = (i / 64) * 2000
#    f = 2 * math.sin((math.pi * freq) / (fsample))
#    write16(ser, SID_OFFSET_FILT, int(f * (1<<16)))
time.sleep(2)
write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_NOISE | 0)
time.sleep(1)

#write16(ser, SID_OFFSET_MODEVOL, 0x07)
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_PULSE | VOICE_GATE)
#for i in range(64):
#    freq = (i / 64) * 2000
#    f = 2 * math.sin((math.pi * freq) / (fsample))
#    write16(ser, SID_OFFSET_FILT, int(f * (1<<16)))
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_PULSE | 0)
#time.sleep(1)
#
#write16(ser, SID_OFFSET_MODEVOL, 0x07)
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_PULSE | VOICE_GATE)
#for i in range(64):
#    freq = (i / 64) * 2000
#    f = 2 * math.sin((math.pi * freq) / (fsample))
#    write16(ser, SID_OFFSET_FILT, int(f * (1<<16)))
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_PULSE | 0)
#time.sleep(1)
#
#write16(ser, SID_OFFSET_MODEVOL, 0x07)
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_PULSE | VOICE_GATE)
#for i in range(64):
#    freq = (i / 64) * 2000
#    f = 2 * math.sin((math.pi * freq) / (fsample))
#    write16(ser, SID_OFFSET_FILT, int(f * (1<<16)))
#write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_PULSE | 0)
#time.sleep(1)
#write16(ser, SID_OFFSET_MODEVOL, 0x00)


##write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_TRI | VOICE_GATE)
##for i in range(64):
##    write16(ser, SID_OFFSET_VOICE1_FREQ, 0x6FFF - (i << 8))
###time.sleep(2)
##write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_NOISE | 0)
##time.sleep(1)
##
##write16(ser, SID_OFFSET_MODEVOL, 0x1F)
##
##write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_TRI | VOICE_GATE)
##for i in range(64):
##    write16(ser, SID_OFFSET_VOICE1_FREQ, 0x6FFF - (i << 8))
###time.sleep(2)
##write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_NOISE | 0)
##time.sleep(1)
##
##write16(ser, SID_OFFSET_MODEVOL, 0x4F)
##
##write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_TRI | VOICE_GATE)
##for i in range(64):
##    write16(ser, SID_OFFSET_VOICE1_FREQ, 0x6FFF - (i << 8))
###time.sleep(2)
##write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_NOISE | 0)
##time.sleep(1)
##
##write16(ser, SID_OFFSET_MODEVOL, 0x3F)
##
##write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_TRI | VOICE_GATE)
##for i in range(64):
##    write16(ser, SID_OFFSET_VOICE1_FREQ, 0x6FFF - (i << 8))
###time.sleep(2)
##write16(ser, SID_OFFSET_VOICE1_CONTROL, VOICE_NOISE | 0)
##time.sleep(1)
##

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

