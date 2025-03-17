# processing_manager.py
import sys
import os
import time
import subprocess
from typing import List

class ProcessingManager:
    def __init__(self, config):
        self.config = config
        self.sketch_process = None
        self.current_sketch = None
        self.available_sketches = self.find_sketches()
        print(f"Available Sketches: {self.available_sketches}")
        
        # Set up Processing paths based on OS
        if sys.platform == "win32":
            self.processing_path = self.config['system']['paths']['processing_win']
            if not os.path.exists(self.processing_path):
                alternative_path = self.config['system']['paths']['processing_alt_win']
                if os.path.exists(alternative_path):
                    self.processing_path = alternative_path
                    print(f"Using alternative path: {self.processing_path}")
        elif sys.platform == "darwin":
            self.processing_path = self.config['system']['paths']['processing_mac']
        else:
            self.processing_path = "processing-java"
            
        # Get initial sketch from the initial mode's configuration
        initial_mode = self.config['system']['defaults']['initial_mode']
        initial_sketch = self.config['modes'][initial_mode]['processing']['sketch']
        
        self.start_sketch(initial_sketch)

    def find_sketches(self) -> List[str]:
        """Find all available Processing sketches across all modes."""
        sketches = []
        
        # Check for sketches in the modes directory structure
        modes_dir = "modes"
        if os.path.exists(modes_dir):
            for mode_folder in os.listdir(modes_dir):
                mode_path = os.path.join(modes_dir, mode_folder)
                if not os.path.isdir(mode_path):
                    continue
                    
                # Check each mode folder for .pde files
                for item in os.listdir(mode_path):
                    item_path = os.path.join(mode_path, item)
                    if os.path.isdir(item_path):
                        pde_files = [f for f in os.listdir(item_path) if f.endswith('.pde')]
                        if pde_files:
                            sketches.append(item)
        
        return sketches
        
    def start_sketch(self, sketch_name: str) -> bool:
        if not sketch_name:
            print("No sketch name provided")
            return False
            
        if sketch_name not in self.available_sketches:
            print(f"Sketch '{sketch_name}' not found in available sketches.")
            print(f"Available sketches: {', '.join(self.available_sketches)}")
            print("Will check in mode directories instead...")
            
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
            
            # First, look for the sketch in the current mode folder structure
            found = False
            sketch_path = None
            
            for mode_name in self.config['modes']:
                mode_config = self.config['modes'][mode_name]
                if mode_config.get('processing', {}).get('sketch') == sketch_name:
                    mode_dir = os.path.join("modes", mode_name)
                    potential_path = os.path.join(mode_dir, sketch_name)
                    
                    if os.path.exists(potential_path) and os.path.isdir(potential_path):
                        sketch_path = os.path.abspath(potential_path)
                        found = True
                        break
            
            if not found:
                print(f"Could not find sketch {sketch_name} in any mode folder")
                return False
                
            # Modified command to run in regular window mode
            cmd = [
                self.processing_path,
                "--force",
                "--sketch=" + sketch_path,
                "--output=" + os.path.join(sketch_path, "output"),
                "--run"
            ]
            
            print(f"Launching Processing sketch: {sketch_name}")
            print(f"Command: {' '.join(cmd)}")
            
            if sys.platform == "win32":
                self.sketch_process = subprocess.Popen(cmd)
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
            if sketch_path:
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