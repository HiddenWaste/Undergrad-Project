from pythonosc import udp_client # Baseline for OSC Messaging
import serial                    # Serial Data Arduino Interaction
import serial.tools.list_ports   # ' '  '
import time
import subprocess               # To handle running sketches and switching between them
import random
import os
import sys
from typing import Optional

class ProcessingManager:
    def __init__(self, port: int = 12000):
        self.client = udp_client.SimpleUDPClient("127.0.0.1", port)
        self.current_sketch = None
        self.sketch_process = None
        self.available_sketches = self.find_sketches()
        print(f"Available Sketches: {self.available_sketches}")
        
        # Add path to Processing command-line interface
        if sys.platform == "win32":
            self.processing_path = "C:\\Users\\carte\\Downloads\\processing-4.3-windows-x64\\processing-4.3\\processing-java.exe"
        elif sys.platform == "darwin":  # macOS
            self.processing_path = "/Applications/Processing.app/Contents/MacOS/processing-java"
        else:  # Linux
            self.processing_path = "processing-java"

        self.switch_sketch(None)  # Added call to switch_sketch
        
    def find_sketches(self) -> list[str]:
        sketches = []
        sketch_dir = "sketches"
        if os.path.exists(sketch_dir):
            for folder in os.listdir(sketch_dir):
                if os.path.exists(os.path.join(sketch_dir, folder, f"{folder}.pde")):
                    sketches.append(folder)
        return sketches
        
    def switch_sketch(self, sketch_name: str):
        def kill_processing():
            """Helper function to kill all Processing instances"""
            try:
                # Kill any existing sketch process we know about
                if self.sketch_process:
                    self.sketch_process.terminate()
                    time.sleep(0.5)
                    if self.sketch_process.poll() is None:
                        self.sketch_process.kill()
                        time.sleep(0.5)
                
                # Force kill any remaining Processing instances
                if sys.platform == "win32":
                    # Kill processing-java.exe and any associated java processes
                    os.system('taskkill /F /IM processing-java.exe 2>nul')
                    os.system('taskkill /F /IM java.exe 2>nul')
                    time.sleep(1)  # Give Windows time to clean up
            except Exception as e:
                print(f"Error during process cleanup: {str(e)}")

        # First, kill any running Processing instances
        kill_processing()

        # If no sketch specified and we have available sketches, use the default
        if not sketch_name and self.available_sketches:
            sketch_name = "Spellslinging"  # Wizard mode is default :P
            
        if sketch_name not in self.available_sketches:
            print(f"Sketch {sketch_name} not found")
            if self.available_sketches:
                print(f"Available sketches: {', '.join(self.available_sketches)}")
            return False
            
        # Get absolute path to sketch
        sketch_path = os.path.abspath(os.path.join("sketches", sketch_name))
        
        try:
            # Launch new sketch using Processing CLI
            cmd = [
                self.processing_path,
                "--force",  # Forces Processing to use this sketch
                "--sketch=" + sketch_path,
                "--present"  # Runs the sketch in present mode (fullscreen)
            ]
            
            print(f"Launching sketch: {sketch_name}")
            
            # Launch sketch in a new console window
            if sys.platform == "win32":
                self.sketch_process = subprocess.Popen(
                    cmd,
                    creationflags=subprocess.CREATE_NEW_CONSOLE
                )
            else:
                self.sketch_process = subprocess.Popen(cmd)
            
            # Brief pause to let the sketch start
            time.sleep(1)
            
            # Check if process started successfully
            if self.sketch_process.poll() is not None:
                print("Sketch failed to start")
                return False
                
            self.current_sketch = sketch_name
            print(f"Successfully launched sketch: {sketch_name}\n")
            return True
            
        except Exception as e:
            print(f"Error launching sketch: {str(e)}")
            print(f"Working directory: {os.getcwd()}")
            print(f"Sketch path: {sketch_path}")
            print(f"Processing path: {self.processing_path}")
            return False
        
    def send_message(self, address: str, data):
        self.client.send_message(address, data)
        
    def cleanup(self):
        try:
            if self.sketch_process:
                # Try graceful termination first
                self.sketch_process.terminate()
                time.sleep(0.5)  # Give it a moment to close
            
                # If still running, force kill
                if self.sketch_process.poll() is None:
                    self.sketch_process.kill()
                    
            # On Windows, ensure all processing-java instances are killed
            if sys.platform == "win32":
                os.system('taskkill /F /IM processing-java.exe 2>nul')
                os.system('taskkill /F /IM java.exe 2>nul')  # Kill any leftover Java processes
        except Exception as e:
            print(f"Error during cleanup: {str(e)}")


class SuperColliderManager:
    def __init__(self, port: int = 57120):
        self.client = udp_client.SimpleUDPClient("127.0.0.1", port)
        self.current_synth = None
        
    def send_message(self, address: str, data):
        self.client.send_message(address, data)
        
    def cleanup(self):
        pass

class ArduinoManager:
    def __init__(self):
        self.arduino = None
        
    def find_arduino_port(self) -> Optional[str]:
        ports = serial.tools.list_ports.comports()
        
        for port in ports:
            if "Arduino" in port.description or "CH340" in port.description:
                return port.device
                
        return None
        
    def connect_arduino(self, port: Optional[str] = None) -> bool:
        if not port:
            port = self.find_arduino_port()
            if not port:
                print("No Arduino found automatically.")
                self.list_available_ports()
                return False
                
        try:
            self.arduino = serial.Serial(port, 9600, timeout=1)
            print(f"Successfully connected to Arduino on {port}")
            time.sleep(2)
            return True
        except serial.SerialException as e:
            print(f"Error connecting to Arduino: {str(e)}")
            return False
            
    def list_available_ports(self):
        ports = serial.tools.list_ports.comports()
        print("\nAvailable ports:")
        for p in ports:
            print(f"- {p.device}: {p.description}")

class OSCControlHub:
    def __init__(self):
        print("Initializing Processing....")
        self.processing = ProcessingManager()
        self.supercollider = SuperColliderManager()
        print("You may launch SuperCollider Server whenever....")
        self.arduino = ArduinoManager()
        self.arduino.connect_arduino()  # Added connection call
        self.sketch_index = 0
        
    def generate_effects(self, effect):
        match effect:
            case 1:
                frequency = random.randint(440, 880)
                num_missiles = random.randint(1, 3)
                self.supercollider.send_message("/test", frequency)  # Fixed: removed curly braces
                self.processing.send_message("/missile", num_missiles)
                
            case 5:
                num_fireballs = random.randint(4, 9)
                self.supercollider.send_message("/kick", 300)
                self.processing.send_message("/fireball", num_fireballs)

            case 7:
                if self.processing.available_sketches:  # Added check for empty list
                    print(f"Sketch index {self.sketch_index}")
                    if self.sketch_index == len(self.processing.available_sketches):
                        self.sketch_index = 0
                    else:
                        self.sketch_index = self.sketch_index + 1
                    self.processing.switch_sketch(self.processing.available_sketches[self.sketch_index])
                    

    def run(self):
        if not self.arduino.arduino:  # Fixed: check arduino attribute
            print("Arduino not connected. Please connect Arduino first.")
            return
            
        print("Starting OSC transmission to SuperCollider and Processing...")
        print("Press Ctrl+C to exit...")
        
        try:
            while True:
                if self.arduino.arduino.in_waiting > 0:
                    try:
                        line = self.arduino.arduino.readline().decode('utf-8').strip()
                        
                        match line:
                            case "dbtn":
                                self.generate_effects(1)
                            case "pbtn1":
                                pass
                            case "pbtn3":
                                self.generate_effects(7)
                                print("Sketch index: ", self.sketch_index)
                            case "pbtn4":
                                self.generate_effects(5)
                                
                    except serial.SerialException as e:
                        print(f"Error reading serial: {e}")
                        continue
                    
                time.sleep(0.001)
                        
        except KeyboardInterrupt:
            print("\nShutting down...")
        except serial.SerialException as e:
            print(f"\nSerial communication error: {str(e)}")
        except Exception as e:
            print(f"\nUnexpected error: {str(e)}")
        finally:
            self.cleanup()
                
    def cleanup(self):
        self.processing.cleanup()
        self.supercollider.cleanup()
        if self.arduino.arduino and self.arduino.arduino.is_open:  # Fixed: check arduino attribute
            self.arduino.arduino.close()

def main():
    hub = OSCControlHub()
    try:
        hub.run()
    except KeyboardInterrupt:
        print("\nShutting down gracefully...")
    finally:
        hub.cleanup()

if __name__ == "__main__":
    main()