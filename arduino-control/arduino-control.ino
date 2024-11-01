const int dbtn = 3; // Button for Debug LED
int dbtn_state = 0;
int dbtn_Lstate = 0;  // To detect changes

// 4 Buttons, currently for simply incorporating more buttons
const int pbtn3 = 6;
int pbtn3_state = 0;
int pbtn3_Lstate = 0;


const int pbtn4 = 7; // 'Play Button 4'
int pbtn4_state = 0;
int pbtn4_Lstate = 0;

// 2 LED's, One to Simulate Tempo, and the Debug one
const int dled = 12;  // Aforementioned debug LED
//const int tled = 11; // Tempo LED (CURRENTLY NOT IN USE)

void setup() {
    
    // Static Buttons
    pinMode(pbtn3, INPUT_PULLUP);
    pinMode(pbtn4, INPUT_PULLUP);

    // Debug Stuff
    pinMode(dbtn, INPUT_PULLUP);  // Use internal pull-up
    pinMode(dled, OUTPUT);

    Serial.begin(9600);
    Serial.println("Serial Data System started");  // Confirm serial is working
}

void loop() {
    // Read the button state
    dbtn_state = digitalRead(dbtn);

    pbtn3_state = digitalRead(pbtn3);
    pbtn4_state = digitalRead(pbtn4);

    // Only print when the state changes to reduce overhead processing

    // First check is for debug LED
    if (dbtn_state != dbtn_Lstate) {
        if (dbtn_state == LOW) {  // Button pressed (LOW with pull-up)
            Serial.println("dbtn");
            digitalWrite(dled, LOW);
        } else {
            Serial.println(".");
            digitalWrite(dled, HIGH);
        }
    }
    // Actual Instrument Portion

    // Check the static buttons (pbtn)
    if (pbtn3_state != pbtn3_Lstate) {
        if (pbtn3_state == LOW) {  // Button pressed (LOW with pull-up)
            Serial.println("pbtn3");
            digitalWrite(dled, LOW);
        } else {
            Serial.println(".");
            digitalWrite(dled, HIGH);
        }

        // Update States
        dbtn_Lstate = dbtn_state;
        pbtn3_Lstate = pbtn3_state;
    }


    if (pbtn4_state != pbtn4_Lstate) {
        if (pbtn4_state == LOW) {  // Button pressed (LOW with pull-up)
            Serial.println("pbtn4");
            digitalWrite(dled, LOW);
        } else {
            Serial.println(".");
            digitalWrite(dled, HIGH);
        }

        // Update States
        dbtn_Lstate = dbtn_state;
        pbtn4_Lstate = pbtn4_state;

    }

    

    //Serial.println("-");
    delay(50);  // Debounce delay
}