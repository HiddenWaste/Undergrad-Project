# teensy_controller.py
from pythonosc import udp_client
import serial
import serial.tools.list_ports
import time
import os
import sys
import yaml
from typing import Optional, List
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

        # Initialize managers
        print("Initializing Processing...")
        self.processing = ProcessingManager(self.config)
        
        print("Initializing SuperCollider...")
        self.supercollider = SuperColliderManager(self.config)
        
        # Connect to Teensy
        port = self.config['system']['ports']['teensy']
        baud = self.config['system']['defaults']['baud_rate']
        
        print(f"Connecting to Teensy on {port}...")
        try:
            self.serial = serial.Serial(port, baud)
            time.sleep(2)
            print("Successfully connected to Teensy")
        except serial.SerialException as e:
            print(f"Error connecting to Teensy: {e}")
            available_ports = self.list_ports()
            if available_ports:
                print("Available ports:", ', '.join(available_ports))
            sys.exit(1)
        
        # Initialize OSC clients
        self.sc_client = udp_client.SimpleUDPClient(
            "127.0.0.1", 
            self.config['system']['ports']['supercollider']
        )
        self.processing_client = udp_client.SimpleUDPClient(
            "127.0.0.1", 
            self.config['system']['ports']['processing']
        )
        
        # Mode management
        self.current_mode = self.config['system']['defaults']['initial_mode']
        self.mode_config = self.config['modes'][self.current_mode]
        print(f"Starting in mode: {self.current_mode}")
        
        # Button state tracking
        self.prev_btn_states = [0, 0, 0]
        
        print("Setup complete! Running controller...")

    def list_ports(self) -> List[str]:
        """List all available serial ports."""
        return [port.device for port in serial.tools.list_ports.comports()]

    def map_value(self, value: int, in_min: int = 0, in_max: int = 4095, 
                  out_min: float = 0, out_max: float = 1.0) -> float:
        """Map input value from one range to another."""
        return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min

    def handle_button_action(self, btn_name: str):
        """Process configured actions for a button."""
        # Get button config for current mode
        if not (self.mode_config.get('controls', {}).get('buttons', {}).get(btn_name)):
            return
            
        btn_config = self.mode_config['controls']['buttons'][btn_name]
        
        # Skip if no actions configured
        if 'actions' not in btn_config:
            return
            
        # Process each configured action
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
        """Handle button state changes based on current mode."""
        buttons = [btn1, btn2, btn3]
        button_names = ['dbtn', 'pbtn1', 'pbtn4']
        
        for btn_idx, (btn_current, btn_prev, btn_name) in enumerate(
            zip(buttons, self.prev_btn_states, button_names)):
            
            # Check for button press (0 to 1 transition)
            if btn_current > btn_prev:
                self.handle_button_action(btn_name)
                print(f"Button pressed: {btn_name}")
                
        self.prev_btn_states = buttons

    def handle_pot_control(self, pot_name: str, raw_value: int):
        """Process configured control for a pot."""
        if not (self.mode_config.get('controls', {}).get('pots', {}).get(pot_name)):
            return
            
        pot_config = self.mode_config['controls']['pots'][pot_name]
        
        # Skip if no command configured
        if 'command' not in pot_config:
            return
            
        mapped_value = self.map_value(raw_value)
        target = pot_config['target']
        command = pot_config['command']
        params = pot_config.get('params', [])
        
        # Combine params with mapped value
        message = params + [mapped_value]
        
        try:
            if target == 'supercollider':
                self.sc_client.send_message(command, message)
            elif target == 'processing':
                self.processing_client.send_message(command, message)
        except Exception as e:
            print(f"Error sending OSC message: {e}")

    def handle_pots(self, pot1: int, pot2: int, pot3: int):
        """Handle potentiometer values based on current mode."""
        pot_values = [pot1, pot2, pot3]
        pot_names = ['pot1', 'pot2', 'pot3']
        
        for pot_name, raw_value in zip(pot_names, pot_values):
            self.handle_pot_control(pot_name, raw_value)

    def switch_mode(self, new_mode: str) -> bool:
        """Switch to a different mode."""
        if new_mode not in self.config['modes']:
            print(f"Mode {new_mode} not found")
            return False
            
        print(f"Switching to mode: {new_mode}")
        self.current_mode = new_mode
        self.mode_config = self.config['modes'][new_mode]
        
        # Load mode-specific sketches and scripts
        if 'processing' in self.mode_config:
            sketch = self.mode_config['processing']['sketch']
            self.processing.start_sketch(sketch)
            
        if 'supercollider' in self.mode_config:
            script = self.mode_config['supercollider']['script']
            self.supercollider.start_supercollider(script)
            
        return True

    def run(self):
        """Main run loop."""
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
        """Clean up all resources."""
        print("Cleaning up...")
        self.processing.cleanup()
        self.supercollider.cleanup()
        if hasattr(self, 'serial') and self.serial.is_open:
            self.serial.close()
        print("Cleanup complete!")

if __name__ == "__main__":
    controller = TeensyController()
    controller.run()