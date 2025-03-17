import sys
import os
import time
import subprocess

class SuperColliderManager:
    def __init__(self, config):
        self.config = config
        self.sclang_process = None
        self.current_mode = config['system']['defaults']['initial_mode']
        
        if sys.platform == "win32":
            self.sclang_path = self.config['system']['paths']['supercollider_win']
        else:
            self.sclang_path = "sclang"
            
        self.start_supercollider()
        
    def set_current_mode(self, mode_name):
        """Update current mode"""
        self.current_mode = mode_name
        
    def start_supercollider(self) -> bool:
        try:
            if self.sclang_process:
                self.sclang_process.terminate()
                self.sclang_process.wait()
                
            # Get the script name from the current mode
            sc_script_name = self.config['modes'][self.current_mode]['supercollider']['script']
            
            # Check if the script has a file extension, add .scd if not
            if not sc_script_name.endswith('.scd'):
                sc_script_name += '.scd'
                
            # Find the script in the modes folder structure
            mode_dir = os.path.abspath(f"modes/{self.current_mode}")
            sc_script = os.path.join(mode_dir, sc_script_name)
            
            if not os.path.exists(sc_script):
                print(f"SuperCollider script not found at {sc_script}")
                return False
                
            print(f"Starting SuperCollider with script: {sc_script}")
            self.sclang_process = subprocess.Popen(
                [self.sclang_path, sc_script],
                cwd=mode_dir
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