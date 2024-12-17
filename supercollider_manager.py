import sys
import os
import time
import subprocess

class SuperColliderManager:
    def __init__(self, config, script_name):
        self.config = config
        self.sclang_process = None
        
        if sys.platform == "win32":
            self.sclang_path = self.config['system']['paths']['supercollider_win']
        else:
            self.sclang_path = "sclang"
            
        self.start_supercollider(script_name)
        
    def start_supercollider(self, script_name) -> bool:
        try:
            if self.sclang_process:
                self.sclang_process.terminate()
                self.sclang_process.wait()
                
            sc_dir = os.path.abspath("SuperCollider")
            sc_script = os.path.join(sc_dir, script_name)
            
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