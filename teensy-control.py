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
        elif sys.platform == "darwin":  # macOS
            self.processing_path = "/Applications/Processing.app/Contents/MacOS/processing-java"
        else:  # Linux
            self.processing_path = "processing-java"
            
        # Start with first available sketch or None
        initial_sketch = "first_teensy_vis" if "first_teensy_vis" in self.available_sketches else None
        self.start_sketch(initial_sketch)
        
    def find_sketches(self) -> list[str]:
        """Find all valid Processing sketches in the sketches directory."""
        sketches = []
        sketch_dir = "sketches"
        
        if os.path.exists(sketch_dir):
            for folder in os.listdir(sketch_dir):
                sketch_path = os.path.join(sketch_dir, folder)
                # Check if it's a directory and contains a .pde file with matching name
                if (os.path.isdir(sketch_path) and 
                    os.path.exists(os.path.join(sketch_path, f"{folder}.pde"))):
                    sketches.append(folder)
                    
        if not sketches:
            print("Warning: No valid Processing sketches found in 'sketches' directory")
        return sketches
        
    def start_sketch(self, sketch_name: str) -> bool:
        """Start a Processing sketch by name."""
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
                
            # Get absolute sketch path
            sketch_path = os.path.abspath(os.path.join("sketches", sketch_name))
            
            # Launch new sketch
            cmd = [
                self.processing_path,
                "--force",
                "--sketch=" + sketch_path,
                "--present"
            ]
            
            print(f"Launching Processing sketch: {sketch_name}")
            
            if sys.platform == "win32":
                self.sketch_process = subprocess.Popen(
                    cmd,
                    creationflags=subprocess.CREATE_NEW_CONSOLE
                )
            else:
                self.sketch_process = subprocess.Popen(cmd)
                
            time.sleep(1)
            
            # Check if process started successfully
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
            sc_script = os.path.join(sc_dir, "pot-test.scd")  # Updated script name
            
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
        self.serial = serial.Serial(port, baud)
        time.sleep(1)
        
        # Initialize OSC clients
        self.sc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)
        self.processing_client = udp_client.SimpleUDPClient("127.0.0.1", 12000)
        
        self.global_mode = False
        self.prev_btn_states = [0, 0, 0]
        
        print("Setup complete! Running controller...")

    def run(self):
        try:
            while True:
                if self.serial.in_waiting:
                    line = self.serial.readline().decode().strip()
                    # Your existing Teensy control logic here
                    
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
        if self.serial and self.serial.is_open:
            self.serial.close()
        print("Cleanup complete!")

if __name__ == "__main__":
    controller = TeensyController()
    controller.run()