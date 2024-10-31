class TanWaveScene extends Scene {
  private OscP5 oscP5;
  private NetAddress myRemoteLocation;
  private float t = 0;
  private float n = 0;
  private boolean increasing = true;
  private float currentPower = 1;
  private PGraphics vhsBuffer;
  
  // Effect control variables
  private boolean line1Flipped = false;
  private float boundaryScale = 1.0;
  private boolean isExpanding = false;
  private boolean isContracting = false;
  private float expansionSpeed = 0.05;
  
  // Keyboard control state
  private boolean[] effectsActive = new boolean[10];
  private String keyboardControls = "";
  
  void setup() {
    vhsBuffer = createGraphics(width, height);
    
     //Initialize OSC
    oscP5 = new OscP5(this, 12000);
    myRemoteLocation = new NetAddress("127.0.0.1", 12000);
    
    // Update keyboard controls help text for new mapping
    keyboardControls = 
      "Keyboard Controls:\n" +
      "q: Toggle Cyan Line Flip\n" +
      "w: Start Expanding Magenta Bounds\n" +
      "e: Start Contracting Magenta Bounds\n" +
      "h: Show/Hide Controls\n" +
      "Space: Reset All Effects";
  }
  
  void update() {
    // Update boundary scale
    if (isExpanding) {
      boundaryScale = min(boundaryScale + 0.01, 2.0);
    } else if (isContracting) {
      boundaryScale = max(boundaryScale - 0.01, 0.5);
    }
    
    // Update variables
    t += 0.02;
    n = sin(t) * 2;
    
    // Update power
    if (increasing) {
      currentPower = lerp(currentPower, 3, 0.01);
      if (currentPower >= 2.95) increasing = false;
    } else {
      currentPower = lerp(currentPower, 1, 0.01);
      if (currentPower <= 1.05) increasing = true;
    }
  }
  
  // Scene-specific key handling
  void handleKey(char k) {
    switch(k) {
      case 'q':
        handleEffect(1);
        break;
      case 'w':
        handleEffect(2);
        break;
      case 'e':
        handleEffect(3);
        break;
      case 'h':
        effectsActive[9] = !effectsActive[9];
        break;
      case ' ':
        resetEffects();
        break;
    }
  }
  
  void oscEvent(OscMessage msg) {
    if (msg.checkAddrPattern("/effect")) {
      handleEffect(msg.get(0).intValue());
    }
  }
  
  private void handleEffect(int effectNumber) {
    switch(effectNumber) {
      case 1:
        line1Flipped = !line1Flipped;
        effectsActive[0] = line1Flipped;
        break;
      case 2:
        isExpanding = !isExpanding;
        isContracting = false;
        effectsActive[1] = isExpanding;
        effectsActive[2] = false;
        break;
      case 3:
        isContracting = !isContracting;
        isExpanding = false;
        effectsActive[2] = isContracting;
        effectsActive[1] = false;
        break;
    }
  }
  
  private void resetEffects() {
    line1Flipped = false;
    isExpanding = false;
    isContracting = false;
    boundaryScale = 1.0;
    for (int i = 0; i < effectsActive.length; i++) {
      effectsActive[i] = false;
    }
  }

  void draw() {
    buffer.beginDraw();
    // Update boundary scale
    if (isExpanding) {
      boundaryScale = min(boundaryScale + 0.01, 2.0);  // Gradually increase up to 2x
    } else if (isContracting) {
      boundaryScale = max(boundaryScale - 0.01, 0.5);  // Gradually decrease down to 0.5x
    }
    
    // Create slight trail effect
    buffer.fill(0, 20);
    buffer.rect(0, 0, width, height);
    
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
    
    buffer.endDraw();
  }
  
  void cleanup() {
    if (vhsBuffer != null) {
      vhsBuffer.dispose();
    }
    if (oscP5 != null) {
      oscP5.stop();
    }
  }
}
