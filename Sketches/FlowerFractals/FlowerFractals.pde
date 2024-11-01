ArrayList<FlowerPoint> points;
float maxSize;
float targetX, targetY;
color currentColor;
float hue;

void setup() {
  size(800, 600, P2D);  // You can adjust size as needed
  points = new ArrayList<FlowerPoint>();
  maxSize = 50;
  targetX = width/2;
  targetY = height/2;
  hue = 0;
  colorMode(HSB, 360, 100, 100);
  currentColor = color(hue, 80, 100);
  background(0, 0, 10);
}

void draw() {
  // Update
  // Smooth follow mouse
  targetX += (mouseX - targetX) * 0.1;
  targetY += (mouseY - targetY) * 0.1;
  
  // Update all points
  for (int i = points.size() - 1; i >= 0; i--) {
    FlowerPoint p = points.get(i);
    p.update();
    
    // Remove too small points
    if (p.size < 1) {
      points.remove(i);
    }
  }
  
  // Add new points on mouse press
  if (mousePressed && frameCount % 5 == 0) {
    hue = (hue + 0.5) % 360;
    currentColor = color(hue, 80, 100);
    points.add(new FlowerPoint(targetX, targetY, maxSize, currentColor));
    maxSize = min(maxSize + 1, 100);
  } else {
    maxSize = max(maxSize - 0.5, 50);
  }
  
  // Draw
  // Draw trailing effect
  fill(0, 0, 10, 10);
  rect(0, 0, width, height);
  
  // Draw all flower points
  for (FlowerPoint p : points) {
    p.draw();
  }
  
  // Draw current position
  noFill();
  stroke(currentColor);
  strokeWeight(2);
  ellipse(targetX, targetY, 10, 10);
}

class FlowerPoint {
  float x, y;
  float size;
  float angle;
  float speed;
  color c;
  
  FlowerPoint(float x, float y, float size, color c) {
    this.x = x;
    this.y = y;
    this.size = size;
    this.angle = random(TWO_PI);
    this.speed = random(0.02, 0.05);
    this.c = c;
  }
  
  void update() {
    angle += speed;
    size *= 0.99; // Slowly shrink
  }
  
  void draw() {
    pushMatrix();
    translate(x, y);
    rotate(angle);
    
    for (int i = 0; i < 5; i++) {
      float petal_angle = TWO_PI * i / 5;
      float px = cos(petal_angle) * size;
      float py = sin(petal_angle) * size;
      
      fill(c, 150);
      noStroke();
      ellipse(px, py, size * 0.5, size * 0.5);
    }
    
    popMatrix();
  }
}

// Optional: Add these functions if you want to handle program exit
void exit() {
  points.clear();
  super.exit();
}
