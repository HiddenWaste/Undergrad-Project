import serial
from pythonosc import udp_client
import time

# OSC setup for SuperCollider
osc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)

# Serial setup
ser = serial.Serial('COM3', 9600)

def map_value(value, in_min, in_max, out_min, out_max):
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min

try:
    while True:
        # Read and parse data
        data = ser.readline().decode().strip()
        if data.startswith("Pot 1:"):
            values = data.split('\t')
            pot1 = int(values[0].split(': ')[1])
            pot2 = int(values[1].split(': ')[1])
            pot3 = int(values[2].split(': ')[1])
            
            # Map values for SuperCollider
            volume = map_value(pot1, 0, 1023, 0, 100)
            freq = map_value(pot2, 0, 1023, 50, 2000)
            param = map_value(pot3, 0, 1023, 0, 1)
            
            # Send to SuperCollider
            osc_client.send_message("/pot/volume", volume)
            osc_client.send_message("/pot/freq", freq)
            osc_client.send_message("/pot/param", param)
            
            # Print values for debugging
            print(f"Volume: {volume:.1f}, Freq: {freq:.1f}, Param: {param:.2f}")
            
            time.sleep(0.05)  # Small delay to prevent flooding

except KeyboardInterrupt:
    print("\nClosing connections...")
    ser.close()
    print("Done!")