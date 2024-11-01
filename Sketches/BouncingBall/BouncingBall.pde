float x, y;
float speedX, speedY;
color ballColor;
float ballSize;

void setup() {
  size(800, 600, P2D);  // Adjust size as needed
  
  // Initialize ball properties
  x = width/2;
  y = height/2;
  speedX = random(3, 6);
  speedY = random(3, 6);
  ballColor = color(255, 0, 0);
  ballSize = 30;
  
  // Enable smooth rendering for better glow effect
  smooth();
}

void draw() {
  // Update ball position
  x += speedX;
  y += speedY;
  
  // Boundary collision with color change
  if (x > width - ballSize/2 || x < ballSize/2) {
    speedX *= -1;
    ballColor = color(random(255), random(255), random(255));
  }
  if (y > height - ballSize/2 || y < ballSize/2) {
    speedY *= -1;
    ballColor = color(random(255), random(255), random(255));
  }
  
  // Draw
  background(0);
  noStroke();
  
  // Add a glow effect
  for(int i = 5; i > 0; i--) {
    fill(red(ballColor), green(ballColor), blue(ballColor), 50);
    ellipse(x, y, ballSize + i*5, ballSize + i*5);
  }
  
  // Draw the main ball
  fill(ballColor);
  ellipse(x, y, ballSize, ballSize);
}

// Optional: Add mouse interaction
void mousePressed() {
  // Reset ball to mouse position with new random speed
  x = mouseX;
  y = mouseY;
  speedX = random(3, 6) * (random(1) < 0.5 ? 1 : -1);
  speedY = random(3, 6) * (random(1) < 0.5 ? 1 : -1);
  ballColor = color(random(255), random(255), random(255));
}
