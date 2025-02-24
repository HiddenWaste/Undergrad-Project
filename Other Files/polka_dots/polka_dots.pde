import oscP5.*;
import netP5.*;

// Color Palette
color[] palette = {
  #e7e008, // Yellow
  #e97cf0, // Purple
  #e12c24, // Red
  #0edfb2  // Blue
};

// Background Colors
color[] bgPalette = {
  #FFFFFF, // White
  #000000  // Black
};
color currentBg = bgPalette[0];
float bgChangeInterval = 10000; // Time between background swaps in milliseconds
float nextBgChange;

// Cluster Parameters
float MIN_CLUSTER_RADIUS = 100;
float MAX_CLUSTER_RADIUS = 250;
float MIN_DOT_SIZE = 20;
float MAX_DOT_SIZE = 60;
int MIN_DOTS_PER_CLUSTER = 8;
int MAX_DOTS_PER_CLUSTER = 20;
float MIN_DOT_FADE_SPEED = 0.5;
float MAX_DOT_FADE_SPEED = 2.0;
float MIN_CLUSTER_INTERVAL = 1500;
float MAX_CLUSTER_INTERVAL = 3000;

// Spotlight Parameters
float SPOTLIGHT_MIN_SIZE = 400;
float SPOTLIGHT_MAX_SIZE = 600;
float SPOTLIGHT_ALPHA = 40; // Out of 255
float MIN_SPOTLIGHT_SPEED = 0.5;
float MAX_SPOTLIGHT_SPEED = 2.0;
float MIN_SPOTLIGHT_INTERVAL = 4000;
float MAX_SPOTLIGHT_INTERVAL = 8000;
float MIN_SPOTLIGHT_LIFETIME = 3000; // Minimum lifetime in milliseconds
float MAX_SPOTLIGHT_LIFETIME = 8000; // Maximum lifetime in milliseconds

// Runtime Variables
ArrayList<DotCluster> clusters;
ArrayList<Spotlight> spotlights;
OscP5 oscP5;
float nextClusterTime;
float nextSpotlightTime;

void setup() {
  size(1024, 768, P2D);
  clusters = new ArrayList<DotCluster>();
  spotlights = new ArrayList<Spotlight>();
  nextClusterTime = millis();
  nextSpotlightTime = millis() + random(MIN_SPOTLIGHT_INTERVAL, MAX_SPOTLIGHT_INTERVAL);
  nextBgChange = millis() + bgChangeInterval;
  
  // Initialize OSC
  try {
    oscP5 = new OscP5(this, 12000);
    println("OSC initialized on port 12000");
  } catch (Exception e) {
    println("Warning: Could not initialize OSC");
  }
}

void oscEvent(OscMessage theOscMessage) {
  if (theOscMessage.checkAddrPattern("/createCluster")) {
    createRandomCluster();
  } else if (theOscMessage.checkAddrPattern("/createSpotlight")) {
    createRandomSpotlight();
  }
}

void createRandomCluster() {
  float x = random(width);
  float y = random(height);
  clusters.add(new DotCluster(x, y));
}

void createRandomSpotlight() {
  // Random starting position around the edges or within the screen
  float x, y;
  float startPosition = random(1); // Determines starting position type
  
  if (startPosition < 0.7) { // 70% chance to start from edges
    if (random(1) < 0.5) { // Randomly choose horizontal or vertical edge
      x = random(1) < 0.5 ? -SPOTLIGHT_MAX_SIZE/2 : width + SPOTLIGHT_MAX_SIZE/2;
      y = random(-SPOTLIGHT_MAX_SIZE/2, height + SPOTLIGHT_MAX_SIZE/2);
    } else {
      x = random(-SPOTLIGHT_MAX_SIZE/2, width + SPOTLIGHT_MAX_SIZE/2);
      y = random(1) < 0.5 ? -SPOTLIGHT_MAX_SIZE/2 : height + SPOTLIGHT_MAX_SIZE/2;
    }
  } else { // 30% chance to start within screen
    x = random(width);
    y = random(height);
  }
  
  spotlights.add(new Spotlight(x, y));
}

void draw() {
  // Background color management
  if (millis() > nextBgChange) {
    currentBg = (currentBg == bgPalette[0]) ? bgPalette[1] : bgPalette[0];
    nextBgChange = millis() + bgChangeInterval;
  }
  background(currentBg);
  
  // Check if it's time to create a new cluster
  if (millis() > nextClusterTime) {
    createRandomCluster();
    nextClusterTime = millis() + random(MIN_CLUSTER_INTERVAL, MAX_CLUSTER_INTERVAL);
  }
  
  // Check if it's time to create a new spotlight
  if (millis() > nextSpotlightTime) {
    createRandomSpotlight();
    nextSpotlightTime = millis() + random(MIN_SPOTLIGHT_INTERVAL, MAX_SPOTLIGHT_INTERVAL);
  }
  
  // Draw clusters first
  for (int i = clusters.size() - 1; i >= 0; i--) {
    DotCluster cluster = clusters.get(i);
    cluster.update();
    cluster.display();
    
    if (cluster.isDead()) {
      clusters.remove(i);
    }
  }
  
  // Draw spotlights on top
  for (int i = spotlights.size() - 1; i >= 0; i--) {
    Spotlight spotlight = spotlights.get(i);
    spotlight.update();
    spotlight.display();
    
    if (spotlight.isDead()) {
      spotlights.remove(i);
    }
  }
}

class Spotlight {
  float x, y;
  float size;
  color col;
  float alpha;
  float fadeSpeed;
  float speedX, speedY;
  float creationTime;
  float lifetime;
  float centerForce = 0.15; // Force pulling towards center
  float edgeBuffer = 100;   // Distance from edge to start redirecting
  
  Spotlight(float x, float y) {
    this.x = x;
    this.y = y;
    this.size = random(SPOTLIGHT_MIN_SIZE, SPOTLIGHT_MAX_SIZE);
    this.col = palette[int(random(palette.length))];
    this.alpha = SPOTLIGHT_ALPHA;
    this.lifetime = random(MIN_SPOTLIGHT_LIFETIME, MAX_SPOTLIGHT_LIFETIME);
    this.creationTime = millis();
    
    // Calculate fade speed based on lifetime
    this.fadeSpeed = SPOTLIGHT_ALPHA / (lifetime / 16.67); // 16.67 ms per frame at 60 FPS
    
    // Random direction of movement
    float angle = random(TWO_PI);
    float speed = random(MIN_SPOTLIGHT_SPEED, MAX_SPOTLIGHT_SPEED);
    this.speedX = cos(angle) * speed;
    this.speedY = sin(angle) * speed;
  }
  
  void update() {
    // Calculate vector to center
    float centerX = width/2;
    float centerY = height/2;
    float towardsCenterX = centerX - x;
    float towardsCenterY = centerY - y;
    float distToCenter = sqrt(towardsCenterX * towardsCenterX + towardsCenterY * towardsCenterY);
    
    // Normalize the vector
    if (distToCenter > 0) {
      towardsCenterX /= distToCenter;
      towardsCenterY /= distToCenter;
    }
    
    // Check if near edges
    boolean nearEdge = (x < edgeBuffer || x > width - edgeBuffer || 
                       y < edgeBuffer || y > height - edgeBuffer);
    
    // Apply center force if near edges
    if (nearEdge) {
      speedX += towardsCenterX * centerForce;
      speedY += towardsCenterY * centerForce;
      
      // Dampen speed to prevent excessive acceleration
      float speedMagnitude = sqrt(speedX * speedX + speedY * speedY);
      if (speedMagnitude > MAX_SPOTLIGHT_SPEED) {
        speedX = (speedX / speedMagnitude) * MAX_SPOTLIGHT_SPEED;
        speedY = (speedY / speedMagnitude) * MAX_SPOTLIGHT_SPEED;
      }
    }
    
    // Move with current speed
    x += speedX;
    y += speedY;
    
    // Calculate alpha based on elapsed time
    float elapsedTime = millis() - creationTime;
    float lifeProgress = elapsedTime / lifetime;
    alpha = SPOTLIGHT_ALPHA * (1 - lifeProgress);
  }
  
  void display() {
    noStroke();
    color currentColor = color(red(col), green(col), blue(col), alpha);
    fill(currentColor);
    circle(x, y, size);
  }
  
  boolean isDead() {
    // Now only die if faded out or VERY far outside bounds
    float margin = size * 2;
    return alpha <= 0 || 
           x < -margin || x > width + margin || 
           y < -margin || y > height + margin;
  }
}

class DotCluster {
  ArrayList<Dot> dots;
  float x, y;
  float maxRadius;
  int numDots;
  
  DotCluster(float x, float y) {
    this.x = x;
    this.y = y;
    this.maxRadius = random(MIN_CLUSTER_RADIUS, MAX_CLUSTER_RADIUS);
    this.numDots = int(random(MIN_DOTS_PER_CLUSTER, MAX_DOTS_PER_CLUSTER));
    dots = new ArrayList<Dot>();
    
    for (int i = 0; i < numDots; i++) {
      float angle = random(TWO_PI);
      float radius = random(maxRadius);
      float dotX = x + cos(angle) * radius;
      float dotY = y + sin(angle) * radius;
      float size = random(MIN_DOT_SIZE, MAX_DOT_SIZE);
      color dotColor = palette[int(random(palette.length))];
      dots.add(new Dot(dotX, dotY, size, dotColor));
    }
  }
  
  void update() {
    for (Dot dot : dots) {
      dot.update();
    }
  }
  
  void display() {
    for (Dot dot : dots) {
      dot.display();
    }
  }
  
  boolean isDead() {
    for (Dot dot : dots) {
      if (dot.alpha > 0) {
        return false;
      }
    }
    return true;
  }
}

class Dot {
  float x, y;
  float size;
  color col;
  float alpha;
  float fadeSpeed;
  
  Dot(float x, float y, float size, color col) {
    this.x = x;
    this.y = y;
    this.size = size;
    this.col = col;
    this.alpha = 255;
    this.fadeSpeed = random(MIN_DOT_FADE_SPEED, MAX_DOT_FADE_SPEED);
  }
  
  void update() {
    alpha = max(0, alpha - fadeSpeed);
  }
  
  void display() {
    noStroke();
    color currentColor = color(red(col), green(col), blue(col), alpha);
    fill(currentColor);
    circle(x, y, size);
  }
}
