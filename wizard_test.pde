import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress myRemoteLocation;

// Wizard Location
int nFire = 15;
int wx = 0;
int wy = 0;

// Array to create fireballs
ArrayList<Fireball> fireballs = new ArrayList<Fireball>();

void setup() {
  size(1024, 768);
  background(255);
  
  // Set wizard position based on window size
  wx = width/8;
  wy = height - 200; // Adjusted to be visible
  
  // Initialize OSC
  oscP5 = new OscP5(this, 12000);
  println("OSC initialized on port 12000");
}

// OSC receive event
void oscEvent(OscMessage theOscMessage) {
  if (theOscMessage.checkAddrPattern("/fireball")) {
    // Create a new fireball when message received
    fireballs.add(new Fireball(wx+100, wy-50)); // Adjusted position
    println("New fireball created! Total fireballs: " + fireballs.size());
  }
}

class Wizard {
  PImage wizard;
  float wx, wy;
  boolean imageLoaded;
  
  Wizard(float xPos, float yPos) {
    wx = xPos;
    wy = yPos;
    try {
      wizard = loadImage("wizard.png");
      imageLoaded = true;
    } catch (Exception e) {
      println("Could not load wizard image");
      imageLoaded = false;
    }
  }
  
  void display() {
    if (imageLoaded) {
      pushMatrix();
      translate(wx, wy);
      scale(-1, 1);
      image(wizard, -wizard.width/4, -wizard.height/4, wizard.width/4, wizard.height/4);
      popMatrix();
    } else {
      // Draw placeholder if image not loaded
      fill(255);
      stroke(0);
      rect(wx, wy, 50, 100);
      println("Drawing placeholder wizard at: " + wx + ", " + wy);
    }
  }
}

class Fireball {
  float x, y;
  float speedX, speedY;
  PImage fireball;
  float sx, sy;
  boolean active;
  boolean imageLoaded;
  
  Fireball(float xPos, float yPos) {
    x = xPos;
    y = yPos;
    sx = x;
    sy = y;
    speedX = random(4, 16);
    speedY = random(-16, 4);
    try {
      fireball = loadImage("Fireball.png");
      imageLoaded = true;
    } catch (Exception e) {
      println("Could not load fireball image");
      imageLoaded = false;
    }
    active = true;
    println("Created fireball at: " + x + ", " + y);
  }
  
  boolean isActive() {
    return active;
  }
  
  void update() {
    if (!active) return;
    
    x += speedX;
    y += speedY;
    
    // Debug position
    println("Fireball position: " + x + ", " + y);
    
    // Instead of resetting, deactivate if off screen
    if (x > width || x < 0 || y > height || y < 0) {
      active = false;
      println("Fireball deactivated");
    }
  }
  
  void display() {
    if (!active) return;
    
    if (imageLoaded) {
      pushMatrix();
      translate(x, y);
      scale(0.5);  // Scaled down
      image(fireball, 0, 0);
      popMatrix();
    } else {
      // Draw placeholder if image not loaded
      fill(255, 100, 0);
      noStroke();
      ellipse(x, y, 30, 30);
    }
  }
}

void draw() {
  background(0);
  
  // Draw debug info
  fill(255);
  textSize(12);
  text("Active fireballs: " + fireballs.size(), 10, 20);
  text("Wizard position: " + wx + ", " + wy, 10, 40);
  
  Wizard w = new Wizard(wx, wy);
  w.display();
  
  // Update and display active fireballs, remove inactive ones
  for (int i = fireballs.size() - 1; i >= 0; i--) {
    Fireball f = fireballs.get(i);
    f.update();
    f.display();
    
    if (!f.isActive()) {
      fireballs.remove(i);
    }
  }
}

// Debug: Mouse click to manually create fireball
void mousePressed() {
  fireballs.add(new Fireball(wx+100, wy-50));
  println("Manual fireball created");
}