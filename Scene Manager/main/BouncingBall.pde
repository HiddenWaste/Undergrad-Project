// scenes/BouncingBall.pde
class BouncingBall extends Scene {
  private float x, y;
  private float speedX, speedY;
  private color ballColor;
  private float ballSize;
  
  void setup() {
    x = width/2;
    y = height/2;
    speedX = random(3, 6);
    speedY = random(3, 6);
    ballColor = color(255, 0, 0);
    ballSize = 30;
  }
  
  void update() {
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
  }
  
  void draw() {
    buffer.beginDraw();
    buffer.background(0);
    buffer.noStroke();
    
    // Add a glow effect
    for(int i = 5; i > 0; i--) {
      buffer.fill(red(ballColor), green(ballColor), blue(ballColor), 50);
      buffer.ellipse(x, y, ballSize + i*5, ballSize + i*5);
    }
    
    buffer.fill(ballColor);
    buffer.ellipse(x, y, ballSize, ballSize);
    buffer.endDraw();
  }
  
  void cleanup() {
    // Nothing to cleanup
  }
}