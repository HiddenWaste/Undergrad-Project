from pythonosc import udp_client
import time
import random

def main():
    # Create OSC clients for both SuperCollider and Processing
    sc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)    # SuperCollider port
    processing_client = udp_client.SimpleUDPClient("127.0.0.1", 12000)  # Processing port

    print("Starting OSC transmission to SuperCollider and Processing...")
    i = 0
    
    while True:
        # Generate a random frequency for the sound
        frequency = random.randint(440, 880)
        num_fireballs = random.randint(1, 3)
        
        # Send to SuperCollider
        # if i % 4 == 0:
        #     {
        #         sc_client.send_message("/saw", 440)
        #     }
        # elif i % 2 == 0:
        #     {
        #         sc_client.send_message("/sine", frequency)
        #     }
        # else:
        #     {
        #         sc_client.send_message("/pulse", 440)
            # }

        sc_client.send_message("/test", frequency)  # Send frequency to SuperCollider
        
        # Send to Processing
        processing_client.send_message("/fireball", [num_fireballs])  # Simple trigger message
        
        print(f"Triggered {num_fireballs} fireballs and Synth with frequency: {frequency:.2f} Hz")
        time.sleep(1)  # Trigger every half second

if __name__ == "__main__":
    main()