#include <ADC.h>
#include <Bounce2.h>

ADC *adc = new ADC();

// Button setup
const int BUTTON1_PIN = 3;
const int BUTTON2_PIN = 4;
const int BUTTON3_PIN = 5;

// Create Bounce objects for each button
Bounce button1 = Bounce();
Bounce button2 = Bounce();
Bounce button3 = Bounce();

void setup() {
  Serial.begin(9600);
  
  // ADC setup
  adc->adc0->setAveraging(4);
  adc->adc0->setResolution(12);
  adc->adc0->setConversionSpeed(ADC_CONVERSION_SPEED::HIGH_SPEED);
  adc->adc0->setSamplingSpeed(ADC_SAMPLING_SPEED::HIGH_SPEED);
  
  // Button setup
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  pinMode(BUTTON3_PIN, INPUT_PULLUP);
  
  // Initialize the bounce instances
  button1.attach(BUTTON1_PIN);
  button2.attach(BUTTON2_PIN);
  button3.attach(BUTTON3_PIN);
  
  // Set bounce intervals (in milliseconds)
  button1.interval(5);
  button2.interval(5);
  button3.interval(5);
}

void loop() {
  // Update button states
  button1.update();
  button2.update();
  button3.update();
  
  // Read analog values
  int potValue = adc->adc0->analogRead(A0);
  int pot2Value = adc->adc0->analogRead(A1);
  int pot3Value = adc->adc0->analogRead(A2);

  // Send potentiometer values
  Serial.print(potValue);
  Serial.print(",");
  Serial.print(pot2Value);
  Serial.print(",");
  Serial.print(pot3Value);
  
  // Send button states (1 for pressed, 0 for not pressed)
  // Note: INPUT_PULLUP means buttons are active LOW
  Serial.print(",");
  Serial.print(!button1.read());
  Serial.print(",");
  Serial.print(!button2.read());
  Serial.print(",");
  Serial.println(!button3.read());
  
  delay(10); // Reduced delay for better button responsiveness
}