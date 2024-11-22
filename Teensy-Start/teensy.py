from pythonosc import udp_client
import serial
import time

class TeensyController:
    def __init__(self, port='COM6', baud=9600):
        # Create clients for both SC and Processing
        self.sc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)
        self.processing_client = udp_client.SimpleUDPClient("127.0.0.1", 12000)
        self.serial = serial.Serial(port, baud)
        time.sleep(1)
        
        self.global_mode = False
        self.prev_btn_states = [0, 0, 0]
        
    def map_value(self, value, in_min=0, in_max=4095, out_min=0, out_max=1000):
        return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
        
    def handle_buttons(self, btn1, btn2, btn3):
        buttons = [btn1, btn2, btn3]
        
        # Only send message on button press (transition from 0 to 1)
        if btn1 > self.prev_btn_states[0]:
            self.sc_client.send_message("/synth/select", 1)
            self.processing_client.send_message("/synth/select", 1)
        elif btn2 > self.prev_btn_states[1]:
            self.sc_client.send_message("/synth/select", -1)
            self.processing_client.send_message("/synth/select", -1)
        elif btn3 > self.prev_btn_states[2]:
            self.global_mode = not self.global_mode
            self.sc_client.send_message("/mode/global", 1 if self.global_mode else 0)
            self.processing_client.send_message("/mode/global", 1 if self.global_mode else 0)
            
        self.prev_btn_states = buttons
            
    def handle_pots(self, pot1, pot2, pot3):
        if self.global_mode:
            # Global mode mappings
            vol = self.map_value(pot1, out_min=0, out_max=100)
            reverb = self.map_value(pot2, out_min=0, out_max=1)
            tempo = self.map_value(pot3, out_min=0.5, out_max=4)
            
            # Send to both SC and Processing
            self.sc_client.send_message("/pot/1", vol)
            self.sc_client.send_message("/pot/2", reverb)
            self.sc_client.send_message("/pot/3", tempo)
            
            self.processing_client.send_message("/pot/1", vol)
            self.processing_client.send_message("/pot/2", reverb)
            self.processing_client.send_message("/pot/3", tempo)
        else:
            # Synth mode mappings
            freq = self.map_value(pot1, out_min=20, out_max=2000)
            param = self.map_value(pot2, out_min=0, out_max=1)
            room = self.map_value(pot3, out_min=0, out_max=1)
            
            # Send to both SC and Processing
            self.sc_client.send_message("/pot/1", freq)
            self.sc_client.send_message("/pot/2", param)
            self.sc_client.send_message("/pot/3", room)
            
            self.processing_client.send_message("/pot/1", freq)
            self.processing_client.send_message("/pot/2", param)
            self.processing_client.send_message("/pot/3", room)
        
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
                            
                    except (ValueError, IndexError) as e:
                        pass  # Ignore parsing errors silently
                
                time.sleep(0.001)
                
        except KeyboardInterrupt:
            print("\nClosing connection...")
            self.serial.close()

if __name__ == "__main__":
    controller = TeensyController()
    controller.run()