import oscP5.*;
import netP5.*;

// Constants
final int WINDOW_WIDTH = 1024;
final int WINDOW_HEIGHT = 768;
final color BG_COLOR = color(0, 0, 30);
final int MAX_PARTICLES = 50;
final PVector FIREBALL_SPAWN_OFFSET = new PVector(80, -50);

// Cache for images to prevent multiple loading
PImage fireballImg;
PImage wizardImg;

// OSC Setup
OscP5 oscP5;
NetAddress myRemoteLocation;

// Game objects
Wizard wizard;
ArrayList<Fireball> fireballs;
ParticleSystem particleSystem;

// Debug mode
boolean debugMode = false;

void setup() {
  size(1024, 768, P2D);
  imageMode(CENTER);
  
  // Load images once
  try {
    fireballImg = loadImage("Fireball.png");
    wizardImg = loadImage("wizard.png");
    wizardImg.resize(0, 200);
  } catch (Exception e) {
    println("Could not load images");
  }
  
  // Initialize game objects
  wizard = new Wizard(width/8, height - 200);
  fireballs = new ArrayList<Fireball>();
  particleSystem = new ParticleSystem();
  
  // Initialize OSC
  oscP5 = new OscP5(this, 12000);
  println("OSC initialized on port 12000");
}

// [OSC Event and createFireball methods remain the same]
void oscEvent(OscMessage theOscMessage) {
  if (theOscMessage.checkAddrPattern("/fireball")) {
    int numFireballs = theOscMessage.get(0).intValue();
    for (int i = 0; i < numFireballs; i++) {
      createFireball();
    }
  }
}

void createFireball() {
  PVector spawnPos = new PVector(
    wizard.position.x + FIREBALL_SPAWN_OFFSET.x,
    wizard.position.y + FIREBALL_SPAWN_OFFSET.y
  );
  fireballs.add(new Fireball(spawnPos.x, spawnPos.y));
  particleSystem.addEmitter(spawnPos.x, spawnPos.y);
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
    position.add(velocity);
    velocity.y += 0.1;
    
    // More comprehensive off-screen check
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
      fill(tint);
      noStroke();
      ellipse(0, 0, size, size);
    }
    
    popMatrix();
  }
}

class Particle {
  PVector position;
  PVector velocity;
  float life;
  float maxLife;
  color col;
  boolean active;
  
  Particle(float x, float y, color c) {
    position = new PVector(x, y);
    velocity = PVector.random2D();
    velocity.mult(random(2, 5));
    maxLife = random(20, 40);
    life = maxLife;
    col = c;
    active = true;
  }
  
  void update() {
    if (!active) return;
    
    position.add(velocity);
    velocity.mult(0.95);
    life--;
    
    if (life < 0) {
      active = false;
    }
  }
  
  void display() {
    if (!active) return;
    
    float alpha = map(life, 0, maxLife, 0, 255);
    fill(red(col), green(col), blue(col), alpha);
    noStroke();
    ellipse(position.x, position.y, 4, 4);
  }
}

class ParticleSystem {
  ArrayList<ArrayList<Particle>> systems;
  ArrayList<ArrayList<Particle>> recycleBin;
  final int MAX_SYSTEMS = 50; // Limit concurrent particle systems
  
  ParticleSystem() {
    systems = new ArrayList<ArrayList<Particle>>();
    recycleBin = new ArrayList<ArrayList<Particle>>();
  }
  
  void addEmitter(float x, float y) {
    // Limit the number of active particle systems
    if (systems.size() >= MAX_SYSTEMS) {
      return;
    }
    
    ArrayList<Particle> particles;
    if (recycleBin.size() > 0) {
      particles = recycleBin.remove(0);
      // Reset particles
      for (Particle p : particles) {
        p.position.set(x, y);
        p.velocity = PVector.random2D().mult(random(2, 5));
        p.life = p.maxLife;
        p.active = true;
      }
    } else {
      particles = new ArrayList<Particle>();
      color particleColor = color(255, random(100, 200), 0);
      for (int i = 0; i < MAX_PARTICLES; i++) {
        particles.add(new Particle(x, y, particleColor));
      }
    }
    systems.add(particles);
  }
  
  void update() {
    for (int i = systems.size() - 1; i >= 0; i--) {
      ArrayList<Particle> particles = systems.get(i);
      boolean allDead = true;
      
      for (Particle p : particles) {
        p.update();
        if (p.active) {
          allDead = false;
        }
      }
      
      if (allDead) {
        // Recycle the particle system instead of removing it
        recycleBin.add(systems.remove(i));
      }
    }
    
    // Limit recycle bin size
    while (recycleBin.size() > MAX_SYSTEMS) {
      recycleBin.remove(0);
    }
  }
  
  void display() {
    for (ArrayList<Particle> particles : systems) {
      for (Particle p : particles) {
        p.display();
      }
    }
  }
  
  void cleanup() {
    systems.clear();
    recycleBin.clear();
  }
}

void draw() {
  background(BG_COLOR);
  
  wizard.display();
  
  particleSystem.update();
  particleSystem.display();
  
  // Update and display fireballs
  for (int i = fireballs.size() - 1; i >= 0; i--) {
    Fireball f = fireballs.get(i);
    f.update();
    
    if (!f.active) {
      fireballs.remove(i);
    } else {
      f.display();
    }
  }
  
  if (debugMode) {
    displayDebugInfo();
    if (frameRate < 30) {
      println("Warning: Low framerate detected: " + frameRate);
    }
  }
}

void displayDebugInfo() {
  fill(255);
  textAlign(LEFT, TOP);
  textSize(12);
  text("FPS: " + nf(frameRate, 0, 1), 10, 10);
  text("Active fireballs: " + fireballs.size(), 10, 30);
  text("Particle systems: " + particleSystem.systems.size(), 10, 50);
  text("Recycled systems: " + particleSystem.recycleBin.size(), 10, 70);
}

void keyPressed() {
  if (key == 'd' || key == 'D') {
    debugMode = !debugMode;
  }
  // Emergency cleanup
  if (key == 'c' || key == 'C') {
    fireballs.clear();
    particleSystem.cleanup();
  }
}

void mousePressed() {
  createFireball();
}
