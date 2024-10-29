import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress myRemoteLocation;

float t = 0;  // Time variable for animation
float n = 0;  // Variable for the tan equation
boolean increasing = true;  // Controls the power transition
float currentPower = 1;    // Power for the first equation
PGraphics vhsBuffer;       // For VHS effect

// Effect control variables
boolean line1Flipped = false;  // Now for cyan line
float boundaryScale = 1.0;     // For magenta line boundaries
boolean isExpanding = false;
boolean isContracting = false;
float expansionSpeed = 0.05;

// Keyboard control state
boolean[] effectsActive = new boolean[10];  // Array to store effect states
String keyboardControls = ""; // For displaying controls

void setup() {
  size(800, 600);
  vhsBuffer = createGraphics(width, height);
  background(0);
  
  // Initialize OSC
  oscP5 = new OscP5(this, 12000);  // Listening on port 12000
  myRemoteLocation = new NetAddress("127.0.0.1", 12000);
  
  // Initialize keyboard controls help text
  keyboardControls = 
    "Keyboard Controls:\n" +
    "1: Toggle Cyan Line Flip\n" +
    "2: Start Expanding Magenta Bounds\n" +
    "3: Start Contracting Magenta Bounds\n" +
    "h: Show/Hide Controls\n" +
    "Space: Reset All Effects";
}

// Keyboard input handling
void keyPressed() {
  switch(key) {
    case '1':
      handleEffect(1);
      println("Effect 1 (Cyan Line Flip): " + (line1Flipped ? "ON" : "OFF"));
      break;
    case '2':
      handleEffect(2);
      println("Effect 2 (Magenta Expansion): " + (isExpanding ? "ON" : "OFF"));
      break;
    case '3':
      handleEffect(3);
      println("Effect 3 (Magenta Contraction): " + (isContracting ? "ON" : "OFF"));
      break;
    case 'h':
      effectsActive[9] = !effectsActive[9];  // Toggle help display
      break;
    case ' ':
      resetEffects();
      println("All effects reset");
      break;
  }
}

void resetEffects() {
  line1Flipped = false;
  isExpanding = false;
  isContracting = false;
  boundaryScale = 1.0;
  for (int i = 0; i < effectsActive.length; i++) {
    effectsActive[i] = false;
  }
}

// OSC message handling
void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/effect")) {
    int effectNumber = msg.get(0).intValue();
    handleEffect(effectNumber);
  }
}

void handleEffect(int effectNumber) {
  switch(effectNumber) {
    case 1:
      line1Flipped = !line1Flipped;
      effectsActive[0] = line1Flipped;
      break;
    case 2:
      isExpanding = !isExpanding;
      isContracting = false;  // Stop contracting if expanding
      effectsActive[1] = isExpanding;
      effectsActive[2] = false;
      break;
    case 3:
      isContracting = !isContracting;
      isExpanding = false;  // Stop expanding if contracting
      effectsActive[2] = isContracting;
      effectsActive[1] = false;
      break;
  }
}

void draw() {
  // Update boundary scale
  if (isExpanding) {
    boundaryScale = min(boundaryScale + 0.01, 2.0);  // Gradually increase up to 2x
  } else if (isContracting) {
    boundaryScale = max(boundaryScale - 0.01, 0.5);  // Gradually decrease down to 0.5x
  }
  
  // Create slight trail effect
  fill(0, 20);
  rect(0, 0, width, height);
  
  // Update variables
  t += 0.02;
  n = sin(t) * 2;
  
  // Update power for first equation
  if (increasing) {
    currentPower = lerp(currentPower, 3, 0.01);
    if (currentPower >= 2.95) increasing = false;
  } else {
    currentPower = lerp(currentPower, 1, 0.01);
    if (currentPower <= 1.05) increasing = true;
  }
  
  // Draw to VHS buffer
  vhsBuffer.beginDraw();
  vhsBuffer.background(0, 0);
  
  // Draw first equation (Cyan)
  vhsBuffer.stroke(0, 255, 255, 200);
  vhsBuffer.strokeWeight(2);
  float prevY1 = 0;
  for (float x = -width/2; x < width/2; x += 1) {
    float scaledX = x/100.0;
    float y = sin(scaledX) * cos(scaledX) * pow(abs(scaledX), currentPower) * 100;
    
    // Apply flip effect to cyan line
    if (line1Flipped) {
      y = -y;
    }
    
    y = constrain(y, -height/2 + 20, height/2 - 20);
    
    if (x > -width/2) {
      vhsBuffer.line(x + width/2, height/2 - prevY1, x + 1 + width/2, height/2 - y);
    }
    prevY1 = y;
  }
  
  // Draw second equation (Magenta) with boundary scaling
  vhsBuffer.stroke(255, 0, 255, 200);
  vhsBuffer.strokeWeight(2);
  float prevY2 = 0;
  boolean firstPoint = true;
  for (float x = -width/2; x < width/2; x += 1) {
    float scaledX = x/100.0;
    float y = tan(scaledX - n) * cos(scaledX) * 50;
    
    // Scale the boundaries
    y *= boundaryScale;
    
    // Improved wrapping logic with scaled boundaries
    float wrapHeight = (height/2) * boundaryScale;
    y = ((y % wrapHeight) + wrapHeight) % wrapHeight;
    y -= wrapHeight/2;
    
    if (!firstPoint) {
      if (abs(y - prevY2) < height/4) {
        vhsBuffer.line(x + width/2, height/2 - prevY2, x + 1 + width/2, height/2 - y);
      }
    }
    prevY2 = y;
    firstPoint = false;
  }
  
  vhsBuffer.endDraw();
  
  // Apply VHS effects
  pushMatrix();
  translate(width/2, height/2);
  
  float displacement = random(-3, 3);
  translate(displacement, 0);
  
  tint(255, 0, 0, 150);
  image(vhsBuffer, -width/2-2, -height/2);
  tint(0, 255, 0, 150);
  image(vhsBuffer, -width/2, -height/2);
  tint(0, 0, 255, 150);
  image(vhsBuffer, -width/2+2, -height/2);
  noTint();
  
  popMatrix();
  
  // Draw scan lines
  for (int y = 0; y < height; y += 2) {
    stroke(0, 20);
    line(0, y, width, y);
  }
  
  // Random glitch effect
  if (random(1) < 0.05) {
    int glitchY = (int)random(height);
    int glitchHeight = (int)random(5, 20);
    copy(0, glitchY, width, glitchHeight, 
         (int)random(-10, 10), glitchY, width, glitchHeight);
  }
  
  // Display controls if help is active
  if (effectsActive[9]) {
    fill(0, 200);
    rect(10, 10, 200, 100);
    fill(255);
    textAlign(LEFT);
    textSize(12);
    text(keyboardControls, 20, 30);
  }
}
