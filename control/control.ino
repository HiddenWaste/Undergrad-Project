const int buttonPin = 2;
const int ledPin = 12;
int buttonState = 0;
int lastButtonState = 0;  // To detect changes

void setup() {
    pinMode(buttonPin, INPUT_PULLUP);  // Use internal pull-up
    pinMode(ledPin, OUTPUT);
    Serial.begin(9600);
    Serial.println("Serial Data System started");  // Confirm serial is working
}

void loop() {
    // Read the button state
    buttonState = digitalRead(buttonPin);

    // Only print when the state changes
    if (buttonState != lastButtonState) {
        if (buttonState == LOW) {  // Button pressed (LOW with pull-up)
            Serial.println("Button pressed");
            digitalWrite(ledPin, LOW);
        } else {
            Serial.println(".");
            digitalWrite(ledPin, HIGH);
        }
        lastButtonState = buttonState;
    }

    delay(50);  // Debounce delay
}