import oscP5.*;
import netP5.*;
// Constants
final color BG_COLOR = color(0, 0, 30);
final int MAX_FIREBALLS = 20;  // Reduced maximum
final int MAX_MISSILES = 15;   // Maximum magic missiles
final PVector FIREBALL_SPAWN_OFFSET = new PVector(80, -50);
final PVector MISSILE_SPAWN_OFFSET = new PVector(100, -30);

// Game objects
PImage fireballImg;
PImage wizardImg;
OscP5 oscP5;
Wizard wizard;
ArrayList<Fireball> fireballs;
ArrayList<MagicMissile> missiles;
boolean debugMode = false;

void setup() {
  size(1024, 768, P2D);
  imageMode(CENTER);
  frameRate(60);
  
  // Initialize collections first
  fireballs = new ArrayList<Fireball>();
  missiles = new ArrayList<MagicMissile>();
  
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
  else if (theOscMessage.checkAddrPattern("/missile")) {
    int numMissiles = min(theOscMessage.get(0).intValue(), 6); // Maximum 6 at once
    for (int i = 0; i < numMissiles && missiles.size() < MAX_MISSILES; i++) {
      createMissile();
    }
  }
}

void createFireball() {
  if (fireballs.size() >= MAX_FIREBALLS) return;
  
  float x = wizard.position.x + FIREBALL_SPAWN_OFFSET.x;
  float y = wizard.position.y + FIREBALL_SPAWN_OFFSET.y;
  fireballs.add(new Fireball(x, y));
}

void createMissile() {
  if (missiles.size() >= MAX_MISSILES) return;
  
  float x = wizard.position.x + MISSILE_SPAWN_OFFSET.x;
  float y = wizard.position.y + MISSILE_SPAWN_OFFSET.y;
  missiles.add(new MagicMissile(x, y));
}

class MagicMissile {
  PVector position;
  PVector velocity;
  float angle;
  float length;
  boolean active;
  color missileColor;
  
  MagicMissile(float x, float y) {
    position = new PVector(x, y);
    angle = random(-PI/8, PI/8); // Slightly narrower angle than fireballs
    velocity = new PVector(cos(angle), sin(angle));
    velocity.mult(random(18, 28)); // Slightly faster than fireballs
    length = random(30, 45);
    active = true;
    missileColor = color(random(200, 255), 100, random(200, 255)); // Purple-ish color
  }
  
  void update() {
    if (!active) return;
    
    position.add(velocity);
    
    // Gentle wave motion
    velocity.y = sin(frameCount * 0.1) * 2;
    
    // Check if off screen
    if (position.x < -length || position.x > width + length || 
        position.y < -length || position.y > height + length) {
      active = false;
    }
  }
  
  void display() {
    if (!active) return;
    
    pushMatrix();
    translate(position.x, position.y);
    rotate(atan2(velocity.y, velocity.x));
    
    // Draw the magic missile shape
    noStroke();
    // Main body
    fill(missileColor);
    beginShape();
    vertex(-length/2, -length/6);
    vertex(length/2, 0);
    vertex(-length/2, length/6);
    endShape(CLOSE);
    
    // Glowing trail
    for (int i = 0; i < 3; i++) {
      float alpha = map(i, 0, 3, 200, 0);
      fill(missileColor, alpha);
      float offset = map(i, 0, 3, 0, -length/2);
      beginShape();
      vertex(-length/2 + offset, -length/8);
      vertex(-length/4 + offset, 0);
      vertex(-length/2 + offset, length/8);
      endShape(CLOSE);
    }
    
    popMatrix();
  }
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
  
  // Update and draw magic missiles
  for (int i = missiles.size() - 1; i >= 0; i--) {
    MagicMissile m = missiles.get(i);
    m.update();
    
    if (!m.active) {
      missiles.remove(i);
    } else {
      m.display();
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
    text("Active missiles: " + missiles.size(), 10, 50);
  }
}

void keyPressed() {
  if (key == 'd' || key == 'D') {
    debugMode = !debugMode;
  }
  // Emergency cleanup
  if (key == 'c' || key == 'C') {
    fireballs.clear();
    missiles.clear();
  }
}

void mousePressed() {
  if (mouseButton == LEFT) {
    createFireball();
  } else if (mouseButton == RIGHT) {
    createMissile();
  }
}
