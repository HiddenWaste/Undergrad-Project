import oscP5.*;
import netP5.*;

// Constants
final color BG_COLOR = color(0, 0, 30);
final int MAX_FIREBALLS = 20;  // Reduced maximum
final PVector FIREBALL_SPAWN_OFFSET = new PVector(80, -50);

// Game objects
PImage fireballImg;
PImage wizardImg;
OscP5 oscP5;
Wizard wizard;
ArrayList<Fireball> fireballs;
boolean debugMode = false;

void setup() {
  size(1024, 768, P2D);
  imageMode(CENTER);
  frameRate(60);
  
  // Initialize collections first
  fireballs = new ArrayList<Fireball>();
  
  // Load images with error handling
  try {
    fireballImg = loadImage("Fireball.png");
    wizardImg = loadImage("wizard.png");
    if (wizardImg != null) {
      wizardImg.resize(0, 200);
    }
  } catch (Exception e) {
    println("Warning: Could not load images - using fallback shapes");
  }
  
  // Initialize game objects
  wizard = new Wizard(width/8, height - 200);
  
  // Initialize OSC last
  try {
    oscP5 = new OscP5(this, 12000);
    println("OSC initialized on port 12000");
  } catch (Exception e) {
    println("Warning: Could not initialize OSC");
  }
}

void oscEvent(OscMessage theOscMessage) {
  if (theOscMessage.checkAddrPattern("/fireball")) {
    int numFireballs = min(theOscMessage.get(0).intValue(), 3); // Maximum 3 at once
    for (int i = 0; i < numFireballs && fireballs.size() < MAX_FIREBALLS; i++) {
      createFireball();
    }
  }
}

void createFireball() {
  if (fireballs.size() >= MAX_FIREBALLS) return;
  
  float x = wizard.position.x + FIREBALL_SPAWN_OFFSET.x;
  float y = wizard.position.y + FIREBALL_SPAWN_OFFSET.y;
  fireballs.add(new Fireball(x, y));
}

class Wizard {
  PVector position;
  
  Wizard(float x, float y) {
    position = new PVector(x, y);
  }
  
  void display() {
    pushMatrix();
    translate(position.x, position.y);
    scale(-1, 1);
    
    if (wizardImg != null) {
      image(wizardImg, 0, 0);
    } else {
      // Fallback shape
      fill(100);
      noStroke();
      ellipse(0, 0, 50, 100);
    }
    
    popMatrix();
  }
}

class Fireball {
  PVector position;
  PVector velocity;
  float size;
  boolean active;
  color tint;
  
  Fireball(float x, float y) {
    position = new PVector(x, y);
    float angle = random(-PI/6, PI/6);
    velocity = new PVector(cos(angle), sin(angle));
    velocity.mult(random(15, 25));
    size = random(40, 60);
    active = true;
    tint = color(255, random(180, 255), random(0, 100));
  }
  
  void update() {
    if (!active) return;
    
    position.add(velocity);
    velocity.y += 0.1;
    
    // Check if off screen
    if (position.x < -size || position.x > width + size || 
        position.y < -size || position.y > height + size) {
      active = false;
    }
  }
  
  void display() {
    if (!active) return;
    
    pushMatrix();
    translate(position.x, position.y);
    
    if (fireballImg != null) {
      tint(tint);
      image(fireballImg, 0, 0, size, size);
      noTint();
    } else {
      // Fallback shape
      fill(tint);
      noStroke();
      ellipse(0, 0, size, size);
    }
    
    popMatrix();
  }
}

void draw() {
  background(BG_COLOR);
  
  // Update and draw fireballs
  for (int i = fireballs.size() - 1; i >= 0; i--) {
    Fireball f = fireballs.get(i);
    f.update();
    
    if (!f.active) {
      fireballs.remove(i);
    } else {
      f.display();
    }
  }
  
  // Draw wizard
  wizard.display();
  
  // Debug info
  if (debugMode) {
    fill(255);
    textAlign(LEFT, TOP);
    textSize(12);
    text("FPS: " + nf(frameRate, 0, 1), 10, 10);
    text("Active fireballs: " + fireballs.size(), 10, 30);
  }
}

void keyPressed() {
  if (key == 'd' || key == 'D') {
    debugMode = !debugMode;
  }
  // Emergency cleanup
  if (key == 'c' || key == 'C') {
    fireballs.clear();
  }
}

void mousePressed() {
  createFireball();
}
