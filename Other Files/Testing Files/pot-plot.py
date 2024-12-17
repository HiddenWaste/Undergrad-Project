import serial
import time
from typing import Optional, Tuple

class SerialMonitor:
    def __init__(self):
        self.serial = None
        self.running = True
    
    def connect(self, baud_rate: int = 9600) -> bool:
        try:
            if self.serial and self.serial.is_open:
                self.serial.close()
                time.sleep(0.1)
            
            self.serial = serial.Serial('COM6', baud_rate, timeout=0.1)
            print(f"Connected to COM6 at {baud_rate} baud")
            time.sleep(1)
            return True
        except serial.SerialException as e:
            print(f"Connection failed: {str(e)}")
            return False
    
    def read_values(self) -> Optional[Tuple[int, int]]:
        try:
            if self.serial and self.serial.in_waiting > 0:
                raw_data = self.serial.readline().decode().strip()
                try:
                    pot1, pot2 = map(int, raw_data.split(','))
                    return pot1, pot2
                except (ValueError, IndexError):
                    return None
        except serial.SerialException:
            self.reconnect()
        return None
    
    def reconnect(self):
        print("\nLost connection, attempting to reconnect...")
        self.connect()
    
    def format_value_display(self, value: int, label: str) -> str:
        bar_length = int((value / 1023) * 30)  # Reduced bar length to fit both
        bar = '█' * bar_length + '░' * (30 - bar_length)
        percentage = (value / 1023) * 100
        return f"{label}: {value:4d} ({percentage:6.2f}%) |{bar}|"
    
    def run(self):
        print("Monitoring potentiometer values. Press Ctrl+C to exit.")
        print("-" * 70)
        
        consecutive_errors = 0
        while self.running:
            try:
                values = self.read_values()
                if values is not None:
                    pot1, pot2 = values
                    if 0 <= pot1 <= 1023 and 0 <= pot2 <= 1023:
                        display = (
                            self.format_value_display(pot1, "Pot1") + 
                            " | " +
                            self.format_value_display(pot2, "Pot2")
                        )
                        print(f"\r{display}", end='', flush=True)
                        consecutive_errors = 0
                
                if consecutive_errors > 10:
                    self.reconnect()
                    consecutive_errors = 0
                    
            except KeyboardInterrupt:
                print("\n\nStopping...")
                break
            except Exception as e:
                print(f"\nError: {str(e)}")
                consecutive_errors += 1
                time.sleep(0.1)
    
    def cleanup(self):
        if self.serial and self.serial.is_open:
            try:
                self.serial.close()
            except Exception as e:
                print(f"Error during cleanup: {str(e)}")

def main():
    monitor = SerialMonitor()
    try:
        if monitor.connect():
            monitor.run()
        else:
            print("Failed to connect to COM6")
    except Exception as e:
        print(f"Error: {str(e)}")
    finally:
        monitor.cleanup()

if __name__ == "__main__":
    main()