from pythonosc import udp_client
import serial
import time
import os
import sys
import subprocess
from typing import Optional

class ProcessingManager:
    def __init__(self):
        self.sketch_process = None
        self.current_sketch = None
        self.available_sketches = self.find_sketches()
        print(f"Available Sketches: {self.available_sketches}")
        
        # Set up Processing paths based on OS
        if sys.platform == "win32":
            self.processing_path = "C:\\Users\\carte\\Downloads\\processing-4.3-windows-x64\\processing-4.3\\processing-java.exe"
            if not os.path.exists(self.processing_path):
                print(f"Warning: Processing not found at {self.processing_path}")
                alternative_path = "C:\\Program Files\\processing-4.3\\processing-java.exe"
                if os.path.exists(alternative_path):
                    self.processing_path = alternative_path
                    print(f"Using alternative path: {self.processing_path}")
        elif sys.platform == "darwin":
            self.processing_path = "/Applications/Processing.app/Contents/MacOS/processing-java"
        else:
            self.processing_path = "processing-java"
            
        initial_sketch = "secpnd_teensy_vis" if "second_teensy_vis" in self.available_sketches else None
        self.start_sketch(initial_sketch)
        
    def find_sketches(self) -> list[str]:
        sketches = []
        sketch_dir = "sketches"
        if os.path.exists(sketch_dir):
            for folder in os.listdir(sketch_dir):
                sketch_path = os.path.join(sketch_dir, folder)
                if (os.path.isdir(sketch_path) and 
                    os.path.exists(os.path.join(sketch_path, f"{folder}.pde"))):
                    sketches.append(folder)
        return sketches
        
    def start_sketch(self, sketch_name: str) -> bool:
        if not sketch_name:
            print("No sketch name provided and no default available")
            return False
            
        if sketch_name not in self.available_sketches:
            print(f"Sketch '{sketch_name}' not found. Available sketches: {', '.join(self.available_sketches)}")
            return False
            
        try:
            # Kill any existing Processing instances
            if self.sketch_process:
                self.sketch_process.terminate()
                time.sleep(0.5)
                if self.sketch_process.poll() is None:
                    self.sketch_process.kill()
                    
            if sys.platform == "win32":
                os.system('taskkill /F /IM processing-java.exe 2>nul')
                os.system('taskkill /F /IM java.exe 2>nul')
                time.sleep(1)
                
            sketch_path = os.path.abspath(os.path.join("sketches", sketch_name))
            
            # Modified command to run in regular window mode
            cmd = [
                self.processing_path,
                "--force",
                "--sketch=" + sketch_path,
                "--output=" + os.path.join(sketch_path, "output"),
                "--run"  # Changed from --present to --run
            ]
            
            print(f"Launching Processing sketch: {sketch_name}")
            print(f"Command: {' '.join(cmd)}")  # Debug print
            
            if sys.platform == "win32":
                self.sketch_process = subprocess.Popen(cmd)  # Removed CREATE_NEW_CONSOLE
            else:
                self.sketch_process = subprocess.Popen(cmd)
                
            time.sleep(1)
            
            if self.sketch_process.poll() is not None:
                print("Sketch failed to start")
                return False
                
            self.current_sketch = sketch_name
            print(f"Successfully launched sketch: {sketch_name}\n")
            return True
            
        except Exception as e:
            print(f"Error launching Processing sketch: {e}")
            print(f"Working directory: {os.getcwd()}")
            print(f"Sketch path: {sketch_path}")
            print(f"Processing path: {self.processing_path}")
            return False

    def cleanup(self):
        try:
            if self.sketch_process:
                self.sketch_process.terminate()
                time.sleep(0.5)
                if self.sketch_process.poll() is None:
                    self.sketch_process.kill()
                    
            if sys.platform == "win32":
                os.system('taskkill /F /IM processing-java.exe 2>nul')
                os.system('taskkill /F /IM java.exe 2>nul')
        except Exception as e:
            print(f"Error cleaning up Processing: {e}")

class SuperColliderManager:
    def __init__(self):
        self.sclang_process = None
        
        # Set up SC paths based on OS
        if sys.platform == "win32":
            self.sclang_path = "C:\\Program Files\\SuperCollider-3.13.0\\sclang.exe"
        else:
            self.sclang_path = "sclang"  # Assuming it's in PATH on Unix systems
            
        self.start_supercollider()
        
    def start_supercollider(self) -> bool:
        try:
            if self.sclang_process:
                self.sclang_process.terminate()
                self.sclang_process.wait()
                
            sc_dir = os.path.abspath("SuperCollider")
            sc_script = os.path.join(sc_dir, "so-close.scd")  # Updated script name
            
            if not os.path.exists(sc_script):
                print(f"SuperCollider script not found at {sc_script}")
                return False
                
            print("Starting SuperCollider...")
            self.sclang_process = subprocess.Popen(
                [self.sclang_path, sc_script],
                cwd=sc_dir
            )
            time.sleep(2)  # Give SC time to boot
            return True
            
        except Exception as e:
            print(f"Error starting SuperCollider: {e}")
            return False
            
    def cleanup(self):
        try:
            if self.sclang_process:
                self.sclang_process.terminate()
                self.sclang_process.wait(timeout=5)
                
            if sys.platform == "win32":
                os.system('taskkill /F /IM sclang.exe 2>nul')
                os.system('taskkill /F /IM scsynth.exe 2>nul')
        except Exception as e:
            print(f"Error cleaning up SuperCollider: {e}")

class TeensyController:
    def __init__(self, port='COM6', baud=9600):
        print("Initializing Processing...")
        self.processing = ProcessingManager()
        
        print("Initializing SuperCollider...")
        self.supercollider = SuperColliderManager()
        
        print("Connecting to Teensy...")
        try:
            self.serial = serial.Serial(port, baud)
            time.sleep(2)
            print(f"Successfully connected to Teensy on {port}")
        except serial.SerialException as e:
            print(f"Error connecting to Teensy: {e}")
            available_ports = self.list_ports()
            if available_ports:
                print("Available ports:", ', '.join(available_ports))
            sys.exit(1)
        
        # Initialize OSC clients
        self.sc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)
        self.processing_client = udp_client.SimpleUDPClient("127.0.0.1", 12000)
        
        # Track current pattern selection (0: bells, 1: pulse, 2: pads)
        self.current_pattern = 0
        self.prev_btn_states = [0, 0, 0]
        
        print("Setup complete! Running controller...")

    def list_ports(self):
        import serial.tools.list_ports
        return [port.device for port in serial.tools.list_ports.comports()]

    def map_value(self, value, in_min=0, in_max=4095, out_min=0, out_max=1.0):
        return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min

    def handle_buttons(self, btn1, btn2, btn3):
        buttons = [btn1, btn2, btn3]
        
        # Button 1: Next pattern
        if btn1 > self.prev_btn_states[0]:
            self.current_pattern = (self.current_pattern + 1) % 3
            self.sc_client.send_message("/selectPattern", self.current_pattern)
            print(f"Selected pattern: {self.current_pattern}")
            
        # Button 2: Previous pattern
        elif btn2 > self.prev_btn_states[1]:
            self.current_pattern = (self.current_pattern - 1) % 3
            self.sc_client.send_message("/selectPattern", self.current_pattern)
            print(f"Selected pattern: {self.current_pattern}")
            
        self.prev_btn_states = buttons

    def handle_pots(self, pot1, pot2, pot3):
        # Map potentiometer values to 0-1 range
        val1 = self.map_value(pot1)
        val2 = self.map_value(pot2)
        val3 = self.map_value(pot3)
        
        # Send pot values with current pattern selection
        self.sc_client.send_message("/potControl", [0, val1])  # Pot 1 (freq)
        self.sc_client.send_message("/potControl", [1, val2])  # Pot 2 (amp)
        self.sc_client.send_message("/potControl", [2, val3])  # Pot 3 (mod)

    def run(self):
        try:
            while True:
                if self.serial.in_waiting:
                    line = self.serial.readline().decode().strip()
                    try:
                        values = list(map(int, line.split(',')))
                        if len(values) == 6:
                            pot1, pot2, pot3 = values[0:3]
                            btn1, btn2, btn3 = values[3:6]
                            
                            self.handle_buttons(btn1, btn2, btn3)
                            self.handle_pots(pot1, pot2, pot3)
                        else:
                            print(f"Invalid data length: {len(values)}")
                            
                    except ValueError as e:
                        print(f"Error parsing data: {e}")
                    except Exception as e:
                        print(f"Error processing data: {e}")
                        
                time.sleep(0.001)
                
        except KeyboardInterrupt:
            print("\nShutting down...")
        except Exception as e:
            print(f"\nUnexpected error: {e}")
        finally:
            self.cleanup()
            
    def cleanup(self):
        print("Cleaning up...")
        self.processing.cleanup()
        self.supercollider.cleanup()
        if hasattr(self, 'serial') and self.serial.is_open:
            self.serial.close()
        print("Cleanup complete!")

if __name__ == "__main__":
    controller = TeensyController()
    controller.run()