from pythonosc import udp_client
import time

def main():
    # Initialize OSC client to send messages to SuperCollider
    sc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)
    
    print("OSC Control for Granular Synth")
    print("Press Enter to toggle synth on/off")
    print("Press 'q' to quit")
    
    while True:
        cmd = input("> ")
        
        if cmd.lower() == 'q':
            break
        else:
            # Toggle the granular synth
            sc_client.send_message("/granular", ["toggle"])
            time.sleep(0.1)  # Small delay to prevent message flooding

if __name__ == "__main__":
    main()