import serial
import serial.tools.list_ports
import time

def find_arduino_port():
    """Scan for available ports and return the first Arduino port found."""
    ports = serial.tools.list_ports.comports()
    
    for port in ports:
        # Arduino boards often have "Arduino" or "CH340" in their description
        if "Arduino" in port.description or "CH340" in port.description:
            return port.device
    return None

def test_arduino_connection(port, baudrate=9600, timeout=1):
    """Test connection to Arduino on specified port."""
    try:
        # Attempt to open serial connection
        ser = serial.Serial(port, baudrate=baudrate, timeout=timeout)
        print(f"Successfully connected to Arduino on {port}")
        
        # Wait for Arduino to reset
        time.sleep(2)
        
        # Try to read data (optional)
        if ser.in_waiting:
            data = ser.readline().decode().strip()
            print(f"Received data: {data}")
            
        ser.close()
        return True
        
    except serial.SerialException as e:
        print(f"Error connecting to Arduino: {str(e)}")
        return False

def main():
    # First, try to find Arduino port automatically
    print("Scanning for Arduino...")
    arduino_port = find_arduino_port()
    
    if arduino_port:
        print(f"Arduino found on port: {arduino_port}")
        test_arduino_connection(arduino_port)
    else:
        print("No Arduino found automatically. Available ports:")
        # List all available ports
        ports = serial.tools.list_ports.comports()
        for port in ports:
            print(f"Port: {port.device} - {port.description}")
        
        # Ask user to specify port manually
        manual_port = input("Enter COM port manually (e.g., COM3): ")
        if manual_port:
            test_arduino_connection(manual_port)

if __name__ == "__main__":
    main()