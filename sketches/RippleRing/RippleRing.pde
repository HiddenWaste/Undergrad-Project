import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress myRemoteLocation;

// Synth parameters
float frequency = 440;
float volume = 50;
float param2 = 0;  // detune/modIndex/width depending on synth
float roomSize = 0;

// Mode tracking
boolean globalMode = false;
int currentSynth = 0;  // 0: sine, 1: FM, 2: PWM

// Visual parameters
ArrayList<SineRing> sineRings;
ArrayList<FMNode> fmNodes;
ArrayList<PWMBar> pwmBars;
float rotationAngle = 0;

void setup() {
  size(1280, 720, P2D);
  colorMode(RGB);
  background(0);
  
  // Initialize OSC communication
  oscP5 = new OscP5(this, 12000);
  
  // Initialize visual elements
  sineRings = new ArrayList<SineRing>();
  fmNodes = new ArrayList<FMNode>();
  pwmBars = new ArrayList<PWMBar>();
  
  // Create initial elements
  for (int i = 0; i < 5; i++) {
    sineRings.add(new SineRing(100 + i * 50));
  }
  
  for (int i = 0; i < 8; i++) {
    fmNodes.add(new FMNode(random(width), random(height)));
  }
  
  for (int i = 0; i < 20; i++) {
    pwmBars.add(new PWMBar(i * (width/20)));
  }
}

void draw() {
  // Fade background
  fill(0, 30);
  rect(0, 0, width, height);
  
  if (globalMode) {
    drawGlobalMode();
  } else {
    switch(currentSynth) {
      case 0: drawSineMode(); break;
      case 1: drawFMMode(); break;
      case 2: drawPWMMode(); break;
    }
  }
  
  rotationAngle += 0.01;
}

void drawSineMode() {
  // Concentric rings that oscillate based on frequency
  translate(width/2, height/2);
  rotate(rotationAngle);
  
  for (SineRing ring : sineRings) {
    ring.update();
    ring.display();
  }
}

void drawFMMode() {
  // Connected nodes with modulating connections
  for (FMNode node : fmNodes) {
    node.update();
    node.display();
  }
  
  // Draw connections between nodes
  stroke(0, 255, 100, 100);
  strokeWeight(1);
  for (int i = 0; i < fmNodes.size(); i++) {
    for (int j = i + 1; j < fmNodes.size(); j++) {
      FMNode n1 = fmNodes.get(i);
      FMNode n2 = fmNodes.get(j);
      float d = dist(n1.pos.x, n1.pos.y, n2.pos.x, n2.pos.y);
      if (d < 200) {
        stroke(0, 255, 100, map(d, 0, 200, 150, 0));
        line(n1.pos.x, n1.pos.y, n2.pos.x, n2.pos.y);
      }
    }
  }
}

void drawPWMMode() {
  // Vertical bars that respond to frequency and pulse width
  for (PWMBar bar : pwmBars) {
    bar.update();
    bar.display();
  }
}

void drawGlobalMode() {
  // Global volume visualization
  float centerSize = map(volume, 0, 100, 50, 200);
  float reverbSize = map(roomSize, 0, 1, 0, 100);
  
  translate(width/2, height/2);
  rotate(rotationAngle * 2);
  
  // Draw reverb circles
  noFill();
  for (int i = 0; i < 5; i++) {
    float alpha = map(i, 0, 5, 200, 50);
    stroke(255, 150, 0, alpha);
    strokeWeight(2);
    ellipse(0, 0, centerSize + reverbSize * i, centerSize + reverbSize * i);
  }
  
  // Draw center shape
  fill(255, 150, 0);
  noStroke();
  ellipse(0, 0, centerSize, centerSize);
}

// Classes for different visual elements
class SineRing {
  float baseRadius;
  float phase = 0;
  
  SineRing(float r) {
    baseRadius = r;
  }
  
  void update() {
    phase += frequency/1000.0;
  }
  
  void display() {
    noFill();
    strokeWeight(2);
    float alpha = map(volume, 0, 100, 50, 200);
    stroke(255, 100, 150, alpha);
    
    beginShape();
    for (float a = 0; a < TWO_PI; a += 0.1) {
      float r = baseRadius + sin(a * (param2 * 10) + phase) * 20;
      float x = r * cos(a);
      float y = r * sin(a);
      vertex(x, y);
    }
    endShape(CLOSE);
  }
}

class FMNode {
  PVector pos;
  PVector vel;
  float phase = 0;
  
  FMNode(float x, float y) {
    pos = new PVector(x, y);
    vel = PVector.random2D().mult(2);
  }
  
  void update() {
    pos.add(vel);
    phase += frequency/1000.0;
    
    // Bounce off edges
    if (pos.x < 0 || pos.x > width) vel.x *= -1;
    if (pos.y < 0 || pos.y > height) vel.y *= -1;
    
    // Add some modulation to movement
    vel.rotate(sin(phase * param2) * 0.1);
  }
  
  void display() {
    float size = map(volume, 0, 100, 5, 20);
    noStroke();
    fill(0, 255, 100);
    ellipse(pos.x, pos.y, size, size);
  }
}

class PWMBar {
  float x;
  float phase = 0;
  
  PWMBar(float xPos) {
    x = xPos;
  }
  
  void update() {
    phase += frequency/500.0;
  }
  
  void display() {
    float pulsePosition = (sin(phase) > param2 * 2 - 1) ? 1 : 0;
    float h = map(pulsePosition * volume, 0, 100, 0, height);
    noStroke();
    fill(100, 150, 255);
    rect(x, height - h, width/20, h);
  }
}

// OSC message handling
void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/synth/select")) {
    int direction = msg.get(0).intValue();
    currentSynth = (currentSynth + direction + 3) % 3;
  }
  else if (msg.checkAddrPattern("/mode/global")) {
    globalMode = msg.get(0).intValue() == 1;
  }
  else if (msg.checkAddrPattern("/pot/1")) {
    if (globalMode) {
      volume = msg.get(0).floatValue();
    } else {
      frequency = msg.get(0).floatValue();
    }
  }
  else if (msg.checkAddrPattern("/pot/2")) {
    if (!globalMode) {
      param2 = msg.get(0).floatValue();
    }
  }
  else if (msg.checkAddrPattern("/pot/3")) {
    if (!globalMode) {
      roomSize = msg.get(0).floatValue();
    }
  }
}
