from pythonosc import udp_client
import serial
import serial.tools.list_ports
import time
import os
import sys
import yaml
from typing import Optional, List, Dict
import keyboard
from threading import Lock
from processing_manager import ProcessingManager
from supercollider_manager import SuperColliderManager

class TeensyController:
    def __init__(self):
        # Load config
        try:
            with open('config.yml', 'r') as file:
                self.config = yaml.safe_load(file)
        except Exception as e:
            print(f"Error loading config file: {e}")
            sys.exit(1)
        
        # Initialize state
        self.debug_mode = False
        self.running = True
        self.pot_values = [0, 0, 0]
        self.pot_lock = Lock()
        self.pot_increment = 0.05
        self.prev_btn_states = [0, 0, 0]
        
        # Mode management
        self.available_modes = list(self.config['modes'].keys())
        self.current_mode = self.config['system']['defaults']['initial_mode']
        self.current_mode_index = self.available_modes.index(self.current_mode)
        self.mode_config = self.config['modes'][self.current_mode]
        print(f"Available modes: {', '.join(self.available_modes)}")
        print(f"Starting in mode: {self.current_mode}")

        # Try to connect to Teensy
        try:
            port = self.config['system']['ports']['teensy']
            baud = self.config['system']['defaults']['baud_rate']
            print(f"Connecting to Teensy on {port}...")
            self.serial = serial.Serial(port, baud)
            time.sleep(2)
            print("Successfully connected to Teensy\n")
        except serial.SerialException as e:
            print(f"Teensy not found: {e}")
            print("Entering debug mode")
            self.debug_mode = True
        
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
        sc_script = self.mode_config['supercollider']['script']
        self.supercollider = SuperColliderManager(self.config, sc_script)
        
        # Set up debug controls if needed
        if self.debug_mode:
            self.setup_debug_controls()
        
        print("Setup complete! Running controller...")

    def switch_to_next_mode(self):
        """Switch to the next available mode in the configuration."""
        self.current_mode_index = (self.current_mode_index + 1) % len(self.available_modes)
        new_mode = self.available_modes[self.current_mode_index]
        
        print(f"\nSwitching to mode: {new_mode}")
        self.current_mode = new_mode
        self.mode_config = self.config['modes'][new_mode]
        
        # Update Processing sketch if needed
        new_sketch = self.mode_config.get('processing', {}).get('sketch')
        if new_sketch:
            self.processing.start_sketch(new_sketch)
        
        # Update SuperCollider script if needed
        new_script = self.mode_config['supercollider']['script']
        self.supercollider = SuperColliderManager(self.config, new_script)

    def setup_debug_controls(self):
        """Set up keyboard controls for debug mode."""
        try:
            debug_config = self.config['debug']['keyboard_mappings']
            
            # Set up button mappings
            for key, btn in debug_config['buttons'].items():
                keyboard.on_press_key(key, lambda e, btn=btn: self.handle_debug_button(btn))
            
            # Set up pot control mappings
            for modifier_key, pot_config in debug_config['pots'].items():
                pot_type = pot_config['type']
                inc_key = pot_config['increment_key']
                dec_key = pot_config['decrement_key']
                
                def make_pot_handler(pot_idx: int, increment: bool):
                    def handler(e):
                        if keyboard.is_pressed(modifier_key):
                            self.adjust_debug_pot(pot_idx, increment)
                    return handler
                
                pot_idx = int(pot_type[-1]) - 1
                keyboard.on_press_key(inc_key, make_pot_handler(pot_idx, True))
                keyboard.on_press_key(dec_key, make_pot_handler(pot_idx, False))
                
            print("Debug controls initialized. Use keyboard mappings:")
            print(f"Buttons: {debug_config['buttons']}")
            print(f"Pots: Hold modifier key and use arrows: {[k for k in debug_config['pots'].keys()]}")
                
        except KeyError as e:
            print(f"Error in debug configuration: {e}")
            print("Please check your config.yml has the correct debug section")
            sys.exit(1)

    def adjust_debug_pot(self, pot_idx: int, increment: bool):
        """Adjust pot value in debug mode."""
        with self.pot_lock:
            if increment:
                self.pot_values[pot_idx] = min(1.0, self.pot_values[pot_idx] + self.pot_increment)
            else:
                self.pot_values[pot_idx] = max(0.0, self.pot_values[pot_idx] - self.pot_increment)
            
            # Changed to match 10-bit ADC range
            raw_value = int(self.pot_values[pot_idx] * 1023)
            self.handle_pot_control(f'pot{pot_idx + 1}', raw_value)
            print(f"Pot {pot_idx + 1}: {self.pot_values[pot_idx]:.2f}")

    def handle_debug_button(self, btn_name: str):
        """Handle button press in debug mode."""
        print(f"Debug button press: {btn_name}")
        if btn_name == 'btn3':  # btn3 is our mode switch button
            self.switch_to_next_mode()
        else:
            self.handle_button_action(btn_name)

    def handle_button_action(self, btn_name: str):
        """Process configured actions for a button."""
        if not (self.mode_config.get('controls', {}).get('buttons', {}).get(btn_name)):
            return
            
        btn_config = self.mode_config['controls']['buttons'][btn_name]
        
        if 'actions' not in btn_config:
            return
            
        for action in btn_config['actions']:
            target = action['target']
            command = action['command']
            params = action.get('params', [])
            
            try:
                if target == 'supercollider':
                    self.sc_client.send_message(command, params)
                    print(f"Sent to SC: {command} {params}")
                elif target == 'processing':
                    self.processing_client.send_message(command, params)
                    print(f"Sent to Processing: {command} {params}")
            except Exception as e:
                print(f"Error sending OSC message: {e}")

    def handle_buttons(self, btn1: int, btn2: int, btn3: int):
        """Handle button state changes."""
        buttons = [btn1, btn2, btn3]
        button_names = ['btn1', 'btn2', 'btn3']
        
        for btn_idx, (btn_current, btn_prev, btn_name) in enumerate(
            zip(buttons, self.prev_btn_states, button_names)):
            
            if btn_current > btn_prev:
                if btn_name == 'btn3':  # btn3 is our mode switch button
                    self.switch_to_next_mode()
                else:
                    self.handle_button_action(btn_name)
                
        self.prev_btn_states = buttons

    def handle_pot_control(self, pot_name: str, raw_value: int):
        """Process configured control for a pot."""
        if not (self.mode_config.get('controls', {}).get('pots', {}).get(pot_name)):
            return
            
        pot_config = self.mode_config['controls']['pots'][pot_name]
        
        if 'command' not in pot_config:
            return
            
        mapped_value = self.map_value(raw_value)
        target = pot_config['target']
        command = pot_config['command']
        params = pot_config.get('params', [])
        message = params + [mapped_value]
        
        try:
            if target == 'supercollider':
                self.sc_client.send_message(command, message)
            elif target == 'processing':
                self.processing_client.send_message(command, message)
        except Exception as e:
            print(f"Error sending OSC message: {e}")

    def handle_pots(self, pot1: int, pot2: int, pot3: int):
        """Handle potentiometer values."""
        pot_values = [pot1, pot2, pot3]
        pot_names = ['pot1', 'pot2', 'pot3']
        
        for pot_name, raw_value in zip(pot_names, pot_values):
            self.handle_pot_control(pot_name, raw_value)

    def map_value(self, value: int, in_min: int = 0, in_max: int = 1023,  # Changed to 10-bit range
                  out_min: float = 0, out_max: float = 1.0) -> float:
        """Map input value from one range to another."""
        return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min

    def run(self):
        """Main run loop."""
        try:
            if self.debug_mode:
                print("Debug mode active. Running main loop...")
                while self.running:
                    time.sleep(0.1)
            else:
                while self.running:
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
        
        # Clean up debug mode
        if self.debug_mode:
            try:
                keyboard.unhook_all()
                print("Cleaned up keyboard hooks")
            except Exception as e:
                print(f"Error cleaning up keyboard: {e}")
        
        # Clean up serial connection
        if not self.debug_mode and hasattr(self, 'serial'):
            try:
                if self.serial.is_open:
                    self.serial.close()
                    print("Closed serial connection")
            except Exception as e:
                print(f"Error closing serial connection: {e}")
        
        print("Cleanup complete!")

if __name__ == "__main__":
    controller = TeensyController()
    controller.run()