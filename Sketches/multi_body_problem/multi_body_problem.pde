// Class to represent a celestial body
class Body {
  PVector position;
  PVector velocity;
  PVector acceleration;
  float mass;
  float radius;
  color bodyColor;
  ArrayList<PVector> trail;
  
  Body(float x, float y, float m, color c) {
    position = new PVector(x, y);
    velocity = new PVector(0, 0);
    acceleration = new PVector(0, 0);
    mass = m;
    radius = sqrt(mass) * 4;
    bodyColor = c;
    trail = new ArrayList<PVector>();
  }
  
  Body(float x, float y, float m, color c, PVector initialVelocity) {
    this(x, y, m, c);
    velocity = initialVelocity;
  }
  
  void update() {
    velocity.add(acceleration);
    position.add(velocity);
    acceleration.mult(0);
    
    // Wrap around screen edges
    position.x = (position.x + width) % width;
    position.y = (position.y + height) % height;
    
    // Store position for trail, handling screen wrapping
    if (trail.size() > 0) {
      PVector lastPos = trail.get(trail.size() - 1);
      if (PVector.dist(lastPos, position) < 50) {
        trail.add(new PVector(position.x, position.y));
      } else {
        trail.add(null);
        trail.add(new PVector(position.x, position.y));
      }
    } else {
      trail.add(new PVector(position.x, position.y));
    }
    
    if (trail.size() > 100) {
      trail.remove(0);
    }
  }
  
  void applyForce(PVector force) {
    PVector f = PVector.div(force, mass);
    acceleration.add(f);
  }
  
  void display() {
    // Draw trail with breaks at screen edges
    noFill();
    beginShape();
    for (int i = 0; i < trail.size(); i++) {
      float alpha = map(i, 0, trail.size(), 0, 255);
      stroke(red(bodyColor), green(bodyColor), blue(bodyColor), alpha);
      
      PVector pos = trail.get(i);
      if (pos == null) {
        endShape();
        beginShape();
      } else {
        vertex(pos.x, pos.y);
      }
    }
    endShape();
    
    // Draw body
    noStroke();
    fill(bodyColor);
    circle(position.x, position.y, radius * 2);
    
    // Draw wrapped instances near edges
    float buffer = radius * 2;
    if (position.x < buffer) circle(position.x + width, position.y, radius * 2);
    if (position.x > width - buffer) circle(position.x - width, position.y, radius * 2);
    if (position.y < buffer) circle(position.x, position.y + height, radius * 2);
    if (position.y > height - buffer) circle(position.x, position.y - height, radius * 2);
  }
  
  PVector getShortestVector(PVector other) {
    float dx = other.x - position.x;
    float dy = other.y - position.y;
    
    if (abs(dx) > width/2) dx = dx - sign(dx) * width;
    if (abs(dy) > height/2) dy = dy - sign(dy) * height;
    
    return new PVector(dx, dy);
  }
}

class Star {
  float x, y;
  float brightness;
  float twinkleSpeed;
  
  Star() {
    x = random(width);
    y = random(height);
    brightness = random(100, 255);
    twinkleSpeed = random(0.02, 0.05);
  }
  
  void display() {
    float twinkle = sin(frameCount * twinkleSpeed) * 50;
    float currentBrightness = constrain(brightness + twinkle, 100, 255);
    stroke(currentBrightness);
    point(x, y);
  }
}

float sign(float x) {
  return x < 0 ? -1 : 1;
}

ArrayList<Body> bodies;
ArrayList<Star> stars;
float G = 1;
boolean showHelp = false;
color[] bodyColors = {
  color(255, 150, 0),   // Orange
  color(0, 150, 255),   // Blue
  color(255, 0, 150),   // Pink
  color(150, 255, 0),   // Lime
  color(255, 0, 0),     // Red
  color(0, 255, 255)    // Cyan
};

void createExplosion() {
  // Calculate center of mass
  PVector center = new PVector(0, 0);
  for (Body b : bodies) {
    center.add(b.position);
  }
  center.div(bodies.size()); // Average position
  
  // Apply outward force to each body
  for (Body b : bodies) {
    PVector explosionForce = PVector.sub(b.position, center);
    float distance = explosionForce.mag();
    if (distance < 1) distance = 1; // Avoid division by zero
    
    explosionForce.normalize();
    explosionForce.mult(20); // Explosion strength - adjust this value to change force
    
    b.velocity.add(explosionForce); // Add directly to velocity for immediate effect
  }
}

void setup() {
  size(1200, 800);
  setupSimulation();
}

void setupSimulation() {
  background(0);
  bodies = new ArrayList<Body>();
  
  // Initialize three bodies with different masses and colors
  bodies.add(new Body(width/2 - 100, height/2, 100, bodyColors[0]));
  bodies.add(new Body(width/2 + 100, height/2, 100, bodyColors[1]));
  bodies.add(new Body(width/2, height/2 - 100, 100, bodyColors[2]));
  
  // Give initial velocities
  bodies.get(0).velocity = new PVector(0, 1);
  bodies.get(1).velocity = new PVector(0, -1);
  bodies.get(2).velocity = new PVector(1, 0);
  
  // Initialize starry background
  stars = new ArrayList<Star>();
  for (int i = 0; i < 200; i++) {
    stars.add(new Star());
  }
}

void draw() {
  // Create fade effect
  fill(0, 20);
  rect(0, 0, width, height);
  
  // Draw stars
  for (Star star : stars) {
    star.display();
  }
  
  // Calculate gravitational forces
  for (int i = 0; i < bodies.size(); i++) {
    Body body1 = bodies.get(i);
    
    for (int j = 0; j < bodies.size(); j++) {
      if (i != j) {
        Body body2 = bodies.get(j);
        PVector forcePath = body1.getShortestVector(body2.position);
        float distance = forcePath.mag();
        distance = constrain(distance, 5, 25);
        float strength = (G * body1.mass * body2.mass) / (distance * distance);
        forcePath.normalize();
        forcePath.mult(strength);
        body1.applyForce(forcePath);
      }
    }
  }
  
  // Update and display bodies
  for (Body b : bodies) {
    b.update();
    b.display();
  }
  
  // Display help overlay
  if (showHelp) {
    displayHelp();
  }
}

void displayHelp() {
  fill(0, 180);
  rect(10, 10, 200, 165); // Made slightly taller
  fill(255);
  textAlign(LEFT);
  textSize(12);
  text("FPS: " + nf(frameRate, 0, 1), 20, 30);
  text("Bodies: " + bodies.size(), 20, 45);
  text("\nControls:", 20, 45);
  text("H - Toggle Help", 20, 75);
  text("1 - Reset Simulation", 20, 90);
  text("2 - Add Center Body", 20, 105);
  text("3 - Add Comet", 20, 120);
  text("4 - Remove Body", 20, 135);
  text("5 - Explosion Effect", 20, 150);
}

void keyPressed() {
  switch(key) {
    case 'h':
    case 'H':
      showHelp = !showHelp;
      break;
      
    case '1':
      setupSimulation();
      break;
      
    case '2':
      if (bodies.size() < bodyColors.length) {
        bodies.add(new Body(
          width/2, 
          height/2, 
          random(50, 150),
          bodyColors[bodies.size()],
          PVector.random2D().mult(random(0.5, 1.5))
        ));
      }
      break;
      
    case '3':
      if (bodies.size() < bodyColors.length) {
        // Create a fast-moving comet from the side
        float startX = random(1) < 0.5 ? 0 : width;
        float startY = random(height);
        PVector velocity = PVector.random2D().mult(3);
        if (startX == 0) velocity.x = abs(velocity.x);
        else velocity.x = -abs(velocity.x);
        
        bodies.add(new Body(
          startX,
          startY,
          random(30, 80),
          bodyColors[bodies.size()],
          velocity
        ));
      }
      break;
      
    case '4':
      if (bodies.size() > 1) {
        bodies.remove(bodies.size() - 1);
      }
      break;
      
    case '5':
      createExplosion();
      break;
  }
}
