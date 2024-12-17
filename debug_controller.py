# debug_controller.py
import keyboard
from threading import Lock
from typing import Dict, List, Tuple
import  time

class DebugController:
    def __init__(self):
        # Track input states
        self.pot_values = [0, 0, 0]  # Range 0-4095 like real pots
        self.button_states = [0, 0, 0]
        self.pot_lock = Lock()
        
        # Configure keyboard mappings
        self.setup_keyboard_controls()
        print("Debug controller initialized. Use keyboard controls:")
        print("Space/Z/X: Buttons | Q/W/E + Up/Down: Pots")

    def setup_keyboard_controls(self):
        """Set up keyboard listeners."""
        # Button controls
        keyboard.on_press_key('space', lambda _: self.set_button(0, 1))
        keyboard.on_release_key('space', lambda _: self.set_button(0, 0))
        
        keyboard.on_press_key('z', lambda _: self.set_button(1, 1))
        keyboard.on_release_key('z', lambda _: self.set_button(1, 0))
        
        keyboard.on_press_key('x', lambda _: self.set_button(2, 1))
        keyboard.on_release_key('x', lambda _: self.set_button(2, 0))
        
        # Pot controls
        def make_pot_handler(pot_idx: int, increment: bool):
            def handler(e):
                modifier_keys = ['q', 'w', 'e']
                if keyboard.is_pressed(modifier_keys[pot_idx]):
                    self.adjust_pot(pot_idx, increment)
            return handler
            
        # Set up handlers for each pot
        for i in range(3):
            keyboard.on_press_key('up', make_pot_handler(i, True))
            keyboard.on_press_key('down', make_pot_handler(i, False))

    def set_button(self, index: int, state: int):
        """Set button state."""
        self.button_states[index] = state

    def adjust_pot(self, index: int, increment: bool):
        """Adjust pot value."""
        with self.pot_lock:
            change = 205 if increment else -205  # About 5% of 4095
            new_value = self.pot_values[index] + change
            self.pot_values[index] = max(0, min(4095, new_value))
            print(f"Pot {index + 1}: {self.pot_values[index]}")

    def get_inputs(self) -> Tuple[List[int], List[int]]:
        """Get current input states."""
        with self.pot_lock:
            return (
                self.pot_values.copy(),
                self.button_states.copy()
            )

    def cleanup(self):
        """Clean up keyboard handlers."""
        keyboard.unhook_all()