// Pattern Visualizer
import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress myRemoteLocation;

// Visual parameters for each pattern
float[][] params = new float[3][3]; // [pattern][parameter]
int selectedPattern = 0;
float[] alphas = new float[3];
float[] targetAlphas = new float[3];

// Colors for each pattern
color[] patternColors = {
  color(255, 100, 100),  // Red for bells
  color(100, 255, 100),  // Green for pulse
  color(100, 100, 255)   // Blue for pads
};

void setup() {
  size(1200, 800, P3D);
  oscP5 = new OscP5(this, 12000);
  
  // Initialize parameters
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      params[i][j] = 0.5;
    }
    alphas[i] = 128;
    targetAlphas[i] = 128;
  }
}

void draw() {
  background(0);
  
  // Update alphas with smooth transition
  for (int i = 0; i < 3; i++) {
    alphas[i] = lerp(alphas[i], targetAlphas[i], 0.1);
  }
  
  // Draw three different visual systems
  pushMatrix();
  translate(width/2, height/2);
  
  // Bell Pattern Visualization - Orbital particles
  drawBellPattern(params[0][0], params[0][1], params[0][2], alphas[0]);
  
  // Pulse Pattern Visualization - Expanding rectangles
  drawPulsePattern(params[1][0], params[1][1], params[1][2], alphas[1]);
  
  // Pad Pattern Visualization - Flowing waves
  drawPadPattern(params[2][0], params[2][1], params[2][2], alphas[2]);
  
  popMatrix();
  
  // Draw selection indicator
  drawSelectionIndicator();
}

void drawBellPattern(float freq, float amp, float mod, float alpha) {
  float time = millis() * 0.001;
  int numParticles = 12;
  
  for (int i = 0; i < numParticles; i++) {
    float angle = (TWO_PI * i / numParticles) + (time * mod);
    float radius = 150 + (sin(time * freq * 0.01) * 50);
    float x = cos(angle) * radius;
    float y = sin(angle) * radius;
    float size = 10 + (amp * 20);
    
    noStroke();
    fill(patternColors[0], alpha);
    circle(x, y, size);
  }
}

void drawPulsePattern(float freq, float amp, float mod, float alpha) {
  float time = millis() * 0.001;
  int numRects = 5;
  
  for (int i = 0; i < numRects; i++) {
    float size = (200 + (i * 50)) * amp;
    float rotation = time * mod + (TWO_PI * i / numRects);
    
    pushMatrix();
    rotate(rotation);
    noFill();
    stroke(patternColors[1], alpha);
    strokeWeight(2 + (sin(time * freq) * 2));
    rect(-size/2, -size/2, size, size);
    popMatrix();
  }
}

void drawPadPattern(float freq, float amp, float mod, float alpha) {
  float time = millis() * 0.001;
  int numWaves = 3;
  
  noFill();
  stroke(patternColors[2], alpha);
  strokeWeight(2);
  
  for (int i = 0; i < numWaves; i++) {
    beginShape();
    for (float x = -300; x <= 300; x += 10) {
      float y = sin(x * 0.01 * freq + time + i) * 100 * amp;
      y *= mod;
      vertex(x, y);
    }
    endShape();
  }
}

void drawSelectionIndicator() {
  for (int i = 0; i < 3; i++) {
    float x = 50 + (i * 40);
    float y = height - 30;
    
    noStroke();
    if (i == selectedPattern) {
      fill(patternColors[i]);
      circle(x, y, 20);
    } else {
      fill(patternColors[i], 128);
      circle(x, y, 15);
    }
  }
}

void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/patternUpdate")) {
    int pattern = msg.get(0).intValue();
    int param = msg.get(1).intValue();
    float value = msg.get(2).floatValue();
    params[pattern][param] = value;
  }
  else if (msg.checkAddrPattern("/selectPattern")) {
    selectedPattern = msg.get(0).intValue();
    
    // Update alpha targets
    for (int i = 0; i < 3; i++) {
      targetAlphas[i] = (i == selectedPattern) ? 255 : 128;
    }
  }
}
