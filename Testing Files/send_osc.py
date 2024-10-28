# This is the central control hub for this project
# This script will read Serial Data from Arduino Input
# Then based on those inputs it sends OSC Messages:
    # - To SuperCollider for sound synthesis
    # - To Processing for visual feedback
# import PyDMX as dmx             # For much later DMX control implementation
# import PyDMX as dmx             # For much later DMX control implementation

from pythonosc import udp_client
import time
import random
import serial  # For Arduino communication

def main():
    # Create OSC clients for both SuperCollider and Processing
    sc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)    # SuperCollider port
    processing_client = udp_client.SimpleUDPClient("127.0.0.1", 12000)  # Processing port
    
    # Initialize Serial communication with Arduino
    # You might need to change 'COM3' to your Arduino's port
    # On Mac/Linux it might be something like '/dev/ttyUSB0' or '/dev/ttyACM0'
    
    # List all available ports
    ports = list(serial.tools.list_ports.comports())
    print("\nAvailable ports:")
    for p in ports:
        print(f"- {p}")

    try:
        arduino = serial.Serial('COM3', 9600, timeout=1)
        print("Connected to Arduino on COM3")
    except:
        print("Failed to connect to Arduino. Check port and connection.")
        return

    print("Starting OSC transmission to SuperCollider and Processing...")
    
    while True:
        if arduino.in_waiting > 0:
            # Read the line from Arduino
            line = arduino.readline().decode('utf-8').strip()
            
           # Check if button was pressed
           if line == "Button pressed":
                # Generate effects when button is pressed
                frequency = random.randint(440, 880)
                num_fireballs = random.randint(1, 3)
                        
                        # Send messages to both applications
                sc_client.send_message("/test", frequency)
                processing_client.send_message("/fireball", [num_fireballs])
                        
                print(f"Triggered {num_fireballs} fireballs and Synth with frequency: {frequency:.2f} Hz")
                
                # Small delay to prevent CPU overload
                time.sleep(0.5)

if __name__ == "__main__":
    main()