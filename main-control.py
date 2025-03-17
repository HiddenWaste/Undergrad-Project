import serial
import serial.tools.list_ports
import time
import os
import sys
import yaml
from typing import Optional, Dict, List
from threading import Lock
from processing_manager import ProcessingManager
from supercollider_manager import SuperColliderManager
from pythonosc import udp_client

class MainController:
    def __init__(self):
        # Load config
        try:
            with open('config.yml', 'r') as file:
                self.config = yaml.safe_load(file)
        except Exception as e:
            print(f"Error loading config file: {e}")
            sys.exit(1)
        
        # Initialize state
        self.running = True
        self.pot_values = [0, 0, 0]
        self.pot_lock = Lock()
        self.direct_button_states = [0] * 7
        self.matrix_button_states = [0] * 16  # 4x4 matrix
        self.connected = False
        
        # Mode management
        self.available_modes = list(self.config['modes'].keys())
        if not self.available_modes:
            print("No modes found in configuration file!")
            sys.exit(1)
            
        self.current_mode = self.config['system']['defaults']['initial_mode']
        if self.current_mode not in self.available_modes:
            print(f"Initial mode '{self.current_mode}' not found in configuration")
            self.current_mode = self.available_modes[0]
            print(f"Using '{self.current_mode}' as fallback initial mode")
            
        self.current_mode_index = self.available_modes.index(self.current_mode)
        self.mode_config = self.config['modes'][self.current_mode]
        print(f"Available modes: {', '.join(self.available_modes)}")
        print(f"Starting in mode: {self.current_mode}")

        # Try to connect to Teensy
        try:
            port = self.config['system']['ports']['teensy']
            baud = self.config['system']['defaults']['baud_rate']
            
            # List available serial ports
            ports = list(serial.tools.list_ports.comports())
            available_ports = [p.device for p in ports]
            print(f"Available serial ports: {', '.join(available_ports)}")
            
            if not available_ports:
                print("No serial ports detected. Will run without hardware input.")
                self.connected = False
            elif port not in available_ports:
                print(f"Configured port {port} not found in available ports.")
                print(f"Using first available port instead: {available_ports[0]}")
                port = available_ports[0]
                self.connected = True
            else:
                self.connected = True
                
            if self.connected:
                print(f"Connecting to Teensy on {port} at {baud} baud...")
                self.serial = serial.Serial(port, baud, timeout=1)
                time.sleep(2)
                print("Successfully connected to Teensy\n")
        except serial.SerialException as e:
            print(f"Error connecting to Teensy: {e}")
            print("Will run without hardware input.")
            self.connected = False
        
        # Initialize OSC clients
        self.sc_client = udp_client.SimpleUDPClient(
            "127.0.0.1", 
            self.config['system']['ports']['supercollider']
        )
        self.processing_client = udp_client.SimpleUDPClient(
            "127.0.0.1", 
            self.config['system']['ports']['processing']
        )

        # Initialize managers
        print("Initializing Processing...")
        self.processing = ProcessingManager(self.config)
        
        print("Initializing SuperCollider...")
        self.supercollider = SuperColliderManager(self.config)
        
        print("Setup complete! Running controller...")

    def switch_to_next_mode(self):
        """Switch to the next available mode in the configuration."""
        try:
            if not self.available_modes:
                print("No available modes found in configuration")
                return False
            
            self.current_mode_index = (self.current_mode_index + 1) % len(self.available_modes)
            new_mode = self.available_modes[self.current_mode_index]
            
            print(f"\nSwitching to mode: {new_mode}")
            self.current_mode = new_mode
            
            # Update mode config
            if new_mode in self.config['modes']:
                self.mode_config = self.config['modes'][new_mode]
            else:
                print(f"Error: Mode {new_mode} not found in configuration")
                return False
            
            # Update Processing sketch if needed
            if 'processing' in self.mode_config and 'sketch' in self.mode_config['processing']:
                new_sketch = self.mode_config['processing']['sketch']
                if new_sketch:
                    result = self.processing.start_sketch(new_sketch)
                    if not result:
                        print(f"Warning: Failed to start Processing sketch for mode {new_mode}")
            else:
                print(f"No Processing sketch defined for mode {new_mode}")
            
            # Update SuperCollider script if needed
            if hasattr(self.supercollider, 'set_current_mode'):
                self.supercollider.set_current_mode(new_mode)
            
            result = self.supercollider.start_supercollider()
            if not result:
                print(f"Warning: Failed to start SuperCollider for mode {new_mode}")
                
            print(f"Mode switch to {new_mode} completed")
            return True
            
        except Exception as e:
            print(f"Error switching modes: {e}")
            return False

    def handle_button_action(self, btn_name: str):
        """Process configured actions for a button."""
        # Check if the button configuration exists in the current mode
        if not self.mode_config:
            print(f"No active mode configuration for button {btn_name}")
            return
            
        buttons = self.mode_config.get('controls', {}).get('buttons', {})
        if not buttons:
            print(f"No button controls defined in mode {self.current_mode}")
            return
            
        btn_config = buttons.get(btn_name)
        if not btn_config:
            print(f"Button {btn_name} not configured in mode {self.current_mode}")
            return
        
        # Check if actions are defined for this button
        if 'actions' not in btn_config:
            print(f"No actions defined for button {btn_name}")
            return
            
        for action in btn_config['actions']:
            target = action.get('target')
            if not target:
                print(f"No target defined for action in button {btn_name}")
                continue
                
            command = action.get('command')
            if not command:
                print(f"No command defined for action in button {btn_name}")
                continue
                
            params = action.get('params', [])
            
            try:
                if target == 'supercollider':
                    self.sc_client.send_message(command, params)
                    print(f"Sent to SC: {command} {params}")
                elif target == 'processing':
                    self.processing_client.send_message(command, params)
                    print(f"Sent to Processing: {command} {params}")
                else:
                    print(f"Unknown target: {target}")
            except Exception as e:
                print(f"Error sending OSC message: {e}")

    def handle_pot_control(self, pot_name: str, raw_value: int):
        """Process configured control for a pot."""
        # Check if the pot configuration exists in the current mode
        if not self.mode_config:
            print(f"No active mode configuration for pot {pot_name}")
            return
            
        pots = self.mode_config.get('controls', {}).get('pots', {})
        if not pots:
            print(f"No pot controls defined in mode {self.current_mode}")
            return
            
        pot_config = pots.get(pot_name)
        if not pot_config:
            print(f"Pot {pot_name} not configured in mode {self.current_mode}")
            return
        
        # Check if command is defined for this pot
        if 'command' not in pot_config:
            print(f"No command defined for pot {pot_name}")
            return
            
        if 'target' not in pot_config:
            print(f"No target defined for pot {pot_name}")
            return
            
        mapped_value = self.map_value(raw_value)
        target = pot_config['target']
        command = pot_config['command']
        params = pot_config.get('params', [])
        message = params + [mapped_value]
        
        try:
            if target == 'supercollider':
                self.sc_client.send_message(command, message)
                print(f"Sent to SC: {command} {message}")
            elif target == 'processing':
                self.processing_client.send_message(command, message)
                print(f"Sent to Processing: {command} {message}")
            else:
                print(f"Unknown target: {target}")
        except Exception as e:
            print(f"Error sending OSC message: {e}")

    def map_value(self, value: int, in_min: int = 0, in_max: int = 4095, 
                  out_min: float = 0, out_max: float = 1.0) -> float:
        """Map input value from one range to another."""
        return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min

    def parse_teensy_data(self, line: str):
        """Parse data from Teensy in the new format."""
        try:
            line = line.strip()
            # Direct buttons
            if line.startswith("btn"):
                try:
                    btn_id = int(line[3:])
                    if 0 <= btn_id < 7:
                        btn_name = f"btn{btn_id+1}"  # 1-indexed for user interface
                        print(f"Direct button press: {btn_name}")
                        
                        # Check if it's our mode switch button (typically btn3 in old code)
                        if btn_id == 2:  # btn3 was our mode switch button
                            self.switch_to_next_mode()
                        else:
                            self.handle_button_action(btn_name)
                except ValueError:
                    print(f"Invalid button format: {line}")
            
            # Matrix buttons
            elif line.startswith("mbtn_"):
                try:
                    mbtn_id = int(line[5:])
                    if 0 <= mbtn_id < 16:
                        mbtn_name = f"mbtn{mbtn_id+1}"  # 1-indexed for user interface
                        print(f"Matrix button press: {mbtn_name}")
                        self.handle_button_action(mbtn_name)
                except ValueError:
                    print(f"Invalid matrix button format: {line}")
            
            # Potentiometers
            elif line.startswith("pot"):
                try:
                    colon_pos = line.find(":")
                    if colon_pos > 0:
                        pot_id = int(line[3:colon_pos])
                        value = int(line[colon_pos+1:])
                        
                        if 1 <= pot_id <= 3:  # pot1, pot2, pot3
                            pot_name = f"pot{pot_id}"
                            print(f"{pot_name}: {value}")
                            self.handle_pot_control(pot_name, value)
                except ValueError:
                    print(f"Invalid pot format: {line}")
            else:
                print(f"Unknown data format: {line}")
                        
        except ValueError as e:
            print(f"Error parsing data: {e}, line: {line}")
        except Exception as e:
            print(f"Error processing data: {e}, line: {line}")

    def run(self):
        """Main run loop."""
        try:
            print("Running main loop...")
            while self.running:
                if self.connected and self.serial.in_waiting:
                    line = self.serial.readline().decode().strip()
                    self.parse_teensy_data(line)
                time.sleep(0.001)
                    
        except KeyboardInterrupt:
            print("\nShutting down...")
        except Exception as e:
            print(f"\nUnexpected error: {e}")
        finally:
            self.running = False
            self.cleanup()

    def cleanup(self):
        """Clean up all resources."""
        print("\nCleaning up...")
        
        # Clean up managers first
        if hasattr(self, 'processing'):
            self.processing.cleanup()
        if hasattr(self, 'supercollider'):
            self.supercollider.cleanup()
        
        # Clean up serial connection
        if self.connected and hasattr(self, 'serial'):
            try:
                if self.serial.is_open:
                    self.serial.close()
                    print("Closed serial connection")
            except Exception as e:
                print(f"Error closing serial connection: {e}")
        
        print("Cleanup complete!")

if __name__ == "__main__":
    controller = MainController()
    controller.run()