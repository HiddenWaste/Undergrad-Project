import serial
import serial.tools.list_ports
import time
from typing import Optional

class TeensyDebugger:
    def __init__(self):
        self.teensy = None
        
    def find_teensy_port(self) -> Optional[str]:
        ports = serial.tools.list_ports.comports()
        
        for port in ports:
            if "Teensy" in port.description:
                return port.device
                
        return None
        
    def connect_teensy(self, port: Optional[str] = None) -> bool:
        if not port:
            port = self.find_teensy_port()
            if not port:
                print("No Teensy found automatically.")
                self.list_available_ports()
                return False
                
        try:
            self.teensy = serial.Serial(port, 115200, timeout=1)
            print(f"Successfully connected to Teensy on {port}")
            time.sleep(2)  # Give Teensy time to reset
            return True
        except serial.SerialException as e:
            print(f"Error connecting to Teensy: {str(e)}")
            return False
            
    def list_available_ports(self):
        ports = serial.tools.list_ports.comports()
        print("\nAvailable ports:")
        for p in ports:
            print(f"- {p.device}: {p.description}")
            
    def read_potentiometer(self):
        if not self.teensy:
            print("Teensy not connected. Please connect first.")
            return
            
        print("Reading potentiometer values. Press Ctrl+C to exit.")
        print("Format: Raw Value (0-1023) | Percentage")
        print("-" * 40)
        
        try:
            while True:
                if self.teensy.in_waiting > 0:
                    try:
                        value = self.teensy.readline().decode('utf-8').strip()
                        if value.isdigit():
                            raw_value = int(value)
                            percentage = (raw_value / 1023) * 100
                            print(f"\rValue: {raw_value:4d} | {percentage:6.2f}%", end="")
                    except (ValueError, serial.SerialException) as e:
                        print(f"\nError reading value: {e}")
                        continue
                        
                time.sleep(0.01)  # Small delay to prevent CPU hogging
                
        except KeyboardInterrupt:
            print("\nStopping potentiometer monitor...")
        finally:
            if self.teensy and self.teensy.is_open:
                self.teensy.close()

def main():
    debugger = TeensyDebugger()
    if debugger.connect_teensy():
        debugger.read_potentiometer()

if __name__ == "__main__":
    main()