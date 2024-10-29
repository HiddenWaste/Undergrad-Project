from pythonosc import udp_client
import serial
import serial.tools.list_ports
import time
import random
import sys
from typing import Optional

class OSCControlHub:
    def __init__(self, sc_port: int = 57120, processing_port: int = 12000):
        """Initialize the OSC Control Hub with specified ports."""
        self.sc_client = udp_client.SimpleUDPClient("127.0.0.1", sc_port)
        self.processing_client = udp_client.SimpleUDPClient("127.0.0.1", processing_port)
        self.arduino: Optional[serial.Serial] = None
        
    def find_arduino_port(self) -> Optional[str]:
        """Scan for available ports and return the first Arduino port found."""
        ports = serial.tools.list_ports.comports()
        
        for port in ports:
            if "Arduino" in port.description or "CH340" in port.description:
                return port.device
                
        return None
        
    def connect_arduino(self, port: Optional[str] = None) -> bool:
        """Connect to Arduino on specified or auto-detected port."""
        if not port:
            port = self.find_arduino_port()
            if not port:
                print("No Arduino found automatically.")
                self.list_available_ports()
                return False
                
        try:
            self.arduino = serial.Serial(port, 9600, timeout=1)
            print(f"Successfully connected to Arduino on {port}")
            # Wait for Arduino to reset
            time.sleep(2)
            return True
        except serial.SerialException as e:
            print(f"Error connecting to Arduino: {str(e)}")
            return False
            
    def list_available_ports(self):
        """List all available serial ports."""
        ports = serial.tools.list_ports.comports()
        print("\nAvailable ports:")
        for p in ports:
            print(f"- {p.device}: {p.description}")


    # What message will be sent?           
    def generate_effects(self, effect):
        
        match effect:
            case 1:
                frequency = random.randint(440, 880)
                num_fireballs = random.randint(1, 3)
                self.sc_client.send_message("/test", frequency)
                self.processing_client.send_message("/fireball", [num_fireballs])
            case 5:
                num_fireballs = random.randint(4, 8)
                self.sc_client.send_message("/kick", 300)
                self.processing_client.send_message("/fireball", [num_fireballs]
                )
          
        # # Send messages to both applications
        # self.sc_client.send_message("/test", frequency)
        # self.processing_client.send_message("/fireball", [num_fireballs])
        
        # print(f"Triggered {num_fireballs} fireballs and Synth with frequency: {frequency:.2f} Hz")
        
    def cleanup(self):
        """Clean up resources before exiting."""
        if self.arduino and self.arduino.is_open:
            self.arduino.close()
            print("Arduino connection closed.")
            
    def run(self):
    # """Main loop for reading Arduino input and sending OSC messages."""
        if not self.arduino:
            print("Arduino not connected. Please connect Arduino first.")
            return
            
        print("Starting OSC transmission to SuperCollider and Processing...")
        print("Press Ctrl+C to exit...")
        
        try:
            while True:
                self.processing_client.send_message("effect", 1)
                time.sleep(3)
                self.processing_client.send_message("effect", 2)
                time.sleep(3)
                self.processing_client.send_message("effect", 3)
                time.sleep(5)
                if self.arduino.in_waiting > 0:
                    try:
                        line = self.arduino.readline().decode('utf-8').strip()
                        
                        # Process multiple buttons simultaneously
                        match line:
                            case "dbtn":
                                self.generate_effects(1)
                            case "pbtn4":
                                self.generate_effects(5)
                                
                    except serial.SerialException as e:
                        print(f"Error reading serial: {e}")
                        continue
                    
                time.sleep(0.001)  # 1ms delay instead of 100ms
                        
        except KeyboardInterrupt:
            print("\nShutting down...")
        except serial.SerialException as e:
            print(f"\nSerial communication error: {str(e)}")
        except Exception as e:
            print(f"\nUnexpected error: {str(e)}")
        finally:
            self.cleanup()

def main():
    """Main entry point of the program."""
    hub = OSCControlHub()
    
    # Try to connect to Arduino
    if len(sys.argv) > 1:
        # Use command line argument as port if provided
        connected = hub.connect_arduino(sys.argv[1])
    else:
        # Try automatic detection
        connected = hub.connect_arduino()
        
    if connected:
        hub.run()
    else:
        print("Failed to connect to Arduino. Check connection and try again.")
        port = input("Enter COM port manually (e.g., COM3) or press Enter to exit: ")
        if port:
            if hub.connect_arduino(port):
                hub.run()

if __name__ == "__main__":
    main()