from pythonosc import udp_client
import time
import random

def main():
    # Create OSC clients for both SuperCollider and Processing
    sc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)    # SuperCollider port
    processing_client = udp_client.SimpleUDPClient("127.0.0.1", 12000)  # Processing port

    print("Starting OSC transmission to SuperCollider and Processing...")
    
    while True:
        # Generate a random frequency for the sound
        frequency = random.uniform(440, 880)
        num_fireballs = random.randint(1, 10)
        
        # Send to SuperCollider
        sc_client.send_message("/trigger", [frequency])
        
        # Send to Processing
        processing_client.send_message("/fireball", [num_fireballs])  # Simple trigger message
        
        print(f"Triggered fireball and Synth with frequency: {frequency:.2f} Hz")
        time.sleep(0.5)  # Trigger every half second

if __name__ == "__main__":
    main()