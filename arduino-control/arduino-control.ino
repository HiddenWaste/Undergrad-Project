const int dbtn = 3;    // Continuous button
int dbtn_state = 0;
int dbtn_Lstate = 0;

const int pbtn3 = 6;   // Single press buttons
int pbtn3_state = 0;
int pbtn3_Lstate = 0;

const int pbtn4 = 7;   // Single press buttons
int pbtn4_state = 0;
int pbtn4_Lstate = 0;

const int dled = 12;

void setup() {
    pinMode(pbtn3, INPUT_PULLUP);
    pinMode(pbtn4, INPUT_PULLUP);
    pinMode(dbtn, INPUT_PULLUP);
    pinMode(dled, OUTPUT);
    
    Serial.begin(9600);
    Serial.println("Serial Data System started");
}

void loop() {
    // Read all button states at start of loop
    dbtn_state = digitalRead(dbtn);
    pbtn3_state = digitalRead(pbtn3);
    pbtn4_state = digitalRead(pbtn4);

    // Continuous button - sends while held
    if (dbtn_state == LOW) {  // Button is being held
        Serial.println("dbtn");
        digitalWrite(dled, LOW);
    } else if (dbtn_state != dbtn_Lstate) {  // Button released
        Serial.println(".");
        digitalWrite(dled, HIGH);
    }
    dbtn_Lstate = dbtn_state;

    // Single press buttons - only send on press
    if (pbtn3_state != pbtn3_Lstate) {
        if (pbtn3_state == LOW) {
            Serial.println("pbtn3");
            digitalWrite(dled, LOW);
        } else {
            Serial.println(".");
            digitalWrite(dled, HIGH);
        }
        pbtn3_Lstate = pbtn3_state;
    }

    if (pbtn4_state != pbtn4_Lstate) {
        if (pbtn4_state == LOW) {
            Serial.println("pbtn4");
            digitalWrite(dled, LOW);
        } else {
            Serial.println(".");
            digitalWrite(dled, HIGH);
        }
        pbtn4_Lstate = pbtn4_state;
    }

    delay(50);  // Debounce delay
}