import asyncio
from pythonosc import udp_client
import serial_asyncio
import serial                    # Serial Data Arduino Interaction
import serial.tools.list_ports   # ' '  '
import subprocess
import os
import sys
import random
import time
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

        self._switch_sketch_sync(None)  # Added call to switch_sketch

    def find_sketches(self) -> list[str]:
        sketches = []
        sketch_dir = "sketches"
        if os.path.exists(sketch_dir):
            for folder in os.listdir(sketch_dir):
                if os.path.exists(os.path.join(sketch_dir, folder, f"{folder}.pde")):
                    sketches.append(folder)
        return sketches

    async def send_message(self, address: str, data):
        """Async wrapper for sending OSC messages"""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.client.send_message, address, data)

    async def switch_sketch(self, sketch_name: str):
        """Async version of sketch switching"""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._switch_sketch_sync, sketch_name)

    def _switch_sketch_sync(self, sketch_name: str):
        """Synchronous implementation of sketch switching"""
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
        pass

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
        self.sclang_process = None
        
        # Paths for both sclang and scsynth
        self.sclang_path = "C:\\Program Files\\SuperCollider-3.13.0\\sclang.exe"
        self.scsynth_path = "C:\\Program Files\\SuperCollider-3.13.0\\scsynth.exe"
        
        # Check both executables exist
        if not os.path.exists(self.sclang_path):
            print(f"sclang not found at {self.sclang_path}")
            return
        if not os.path.exists(self.scsynth_path):
            print(f"scsynth not found at {self.scsynth_path}")
            return
            
        # Add SuperCollider directory to PATH temporarily
        os.environ['PATH'] = os.environ['PATH'] + ";" + "C:\\Program Files\\SuperCollider"
        
        self.start_supercollider()


    async def send_message(self, address: str, data):
        """Async wrapper for sending OSC messages"""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.client.send_message, address, data)

    def start_supercollider(self):
        try:
            if self.sclang_process:
                self.sclang_process.terminate()
                self.sclang_process.wait()
            
            sc_dir = os.path.abspath("SuperCollider")
            main_scd = os.path.join(sc_dir, "main.scd")
            
            if not os.path.exists(main_scd):
                print(f"main.scd not found at {main_scd}")
                return False
                
            self.sclang_process = subprocess.Popen(
                [self.sclang_path, main_scd],
                cwd=sc_dir
            )
            print(f"Started SuperCollider with {main_scd}")
            time.sleep(2)  # Give SC time to boot
            return True
            
        except Exception as e:
            print(f"Error starting SuperCollider: {e}")
            print(f"Command attempted: {self.sclang_path} with {main_scd}")
            return False

    def cleanup(self):
    # """Clean up SuperCollider process and resources."""
        try:
            if self.sclang_process:
                # Send quit message to SC server first
                self.client.send_message("/quit", 1)
                time.sleep(0.5)  # Give SC a moment to quit properly
                
                # Then terminate the process
                self.sclang_process.terminate()
                self.sclang_process.wait(timeout=5)  # Wait up to 5 seconds
                print("SuperCollider process terminated")
                
            # On Windows, ensure all SC instances are killed
            if sys.platform == "win32":
                os.system('taskkill /F /IM sclang.exe 2>nul')
                os.system('taskkill /F /IM scsynth.exe 2>nul')
                
        except Exception as e:
            print(f"Error during SuperCollider cleanup: {e}")
            # Force kill if normal termination fails
            if self.sclang_process:
                self.sclang_process.kill()
                print("SuperCollider process force killed")

class ArduinoManager:
    def __init__(self):
        self.arduino = None
        self.message_queue = asyncio.Queue()

    def find_arduino_port(self) -> Optional[str]:
        ports = serial.tools.list_ports.comports()
        
        for port in ports:
            if "Arduino" in port.description or "CH340" in port.description:
                return port.device
                
        return None
    
    def list_available_ports(self):
        ports = serial.tools.list_ports.comports()
        print("\nAvailable ports:")
        for p in ports:
            print(f"- {p.device}: {p.description}")

    async def connect_arduino(self, port: Optional[str] = None) -> bool:
        """Async Arduino connection"""
        if not port:
            port = self.find_arduino_port()
            if not port:
                print("No Arduino found automatically.")
                self.list_available_ports()
                return False

        try:
            self.arduino, _ = await serial_asyncio.create_serial_connection(
                asyncio.get_event_loop(),
                lambda: ArduinoProtocol(self.message_queue),
                port,
                baudrate=9600
            )
            print(f"Successfully connected to Arduino on {port}")
            await asyncio.sleep(2)  # Allow time for Arduino reset
            return True
        except Exception as e:
            print(f"Error connecting to Arduino: {str(e)}")
            return False

class ArduinoProtocol(asyncio.Protocol):
    def __init__(self, message_queue: asyncio.Queue):
        self.message_queue = message_queue
        self.transport = None

    def connection_made(self, transport):
        self.transport = transport

    def data_received(self, data):
        """Handle incoming Arduino data"""
        try:
            message = data.decode().strip()
            if message:
                asyncio.create_task(self.message_queue.put(message))
        except Exception as e:
            print(f"Error receiving data: {e}")

class AsyncOSCControlHub:
    def __init__(self):
        self.processing = ProcessingManager()
        self.supercollider = SuperColliderManager()
        self.arduino = ArduinoManager()
        self.sketch_index = 0
        self.running = False

    async def generate_effects(self, effect):
        """Async version of effect generation"""
        match effect:
            case 1:
                frequency = random.randint(440, 880)
                num_missiles = random.randint(1, 3)
                # Send messages concurrently
                await asyncio.gather(
                    self.supercollider.send_message("/sine_t", frequency),
                    self.processing.send_message("/missile", num_missiles)
                )
            case 5:
                num_fireballs = random.randint(4, 9)
                await asyncio.gather(
                    self.supercollider.send_message("/kick", 300),
                    self.processing.send_message("/fireball", num_fireballs)
                )
            case 7:
                if self.processing.available_sketches:
                    if self.sketch_index == len(self.processing.available_sketches) - 1:
                        self.sketch_index = 0
                    else:
                        self.sketch_index += 1
                    await self.processing.switch_sketch(
                        self.processing.available_sketches[self.sketch_index]
                    )

    async def process_messages(self):
        """Process incoming Arduino messages"""
        while self.running:
            try:
                message = await self.arduino.message_queue.get()
                match message:
                    case "dbtn":
                        await self.generate_effects(1)
                    case "pbtn1":
                        pass
                    case "pbtn3":
                        await self.generate_effects(7)
                    case "pbtn4":
                        await self.generate_effects(5)
            except Exception as e:
                print(f"Error processing message: {e}")

    async def run(self):
        """Main async run loop"""
        if not await self.arduino.connect_arduino():
            print("Arduino not connected. Please connect Arduino first.")
            return

        print("Running async control hub...")
        self.running = True
        
        try:
            # Start message processing
            processor = asyncio.create_task(self.process_messages())
            
            # Keep the main loop running
            while self.running:
                await asyncio.sleep(0.001)
                
        except KeyboardInterrupt:
            print("\nShutting down...")
        except Exception as e:
            print(f"Unexpected error: {e}")
        finally:
            self.running = False
            await self.cleanup()

    async def cleanup(self):
        """Async cleanup"""
        loop = asyncio.get_event_loop()
        await asyncio.gather(
            loop.run_in_executor(None, self.processing.cleanup),
            loop.run_in_executor(None, self.supercollider.cleanup)
        )

async def main():
    """Async main entry point"""
    hub = AsyncOSCControlHub()
    try:
        await hub.run()
    except KeyboardInterrupt:
        print("\nShutting down gracefully...")
    finally:
        await hub.cleanup()

if __name__ == "__main__":
    asyncio.run(main())