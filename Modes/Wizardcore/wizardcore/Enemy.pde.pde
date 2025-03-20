// Enemy.pde

// Base class for all enemies
abstract class Enemy {
  PVector position;
  PVector velocity;
  float size;
  int health;
  int maxHealth;
  float hitboxRadius;
  boolean alive;
  PImage sprite;
  String type;
  
  Enemy(float x, float y, String type, int health, float size, float speed) {
    this.position = new PVector(x, y);
    this.type = type;
    this.health = health;
    this.maxHealth = health;
    this.size = size;
    this.alive = true;
    this.sprite = loadImage(type + ".png");
    if (this.sprite != null) {
      this.sprite.resize(0, (int)size);
    }
    setupMovement(speed);
  }
  
  abstract void setupMovement(float speed);
  abstract void updateMovement();
  
  void update() {
    if (!alive) return;
    updateMovement();
    checkBounds();
  }
  
  void checkBounds() {
    if (position.x < -size || position.x > width + size || 
        position.y < -size || position.y > height + size) {
      alive = false;
    }
  }
  
  void display() {
    if (!alive) return;
    
    pushMatrix();
    translate(position.x, position.y);
    
    if (sprite != null) {
      image(sprite, 0, 0);
    } else {
      // Fallback shape
      fill(255, 0, 0);
      ellipse(0, 0, size, size);
    }
    
    // Health bar
    displayHealthBar();
    
    // Debug hitbox
    if (debugMode) {
      noFill();
      stroke(255, 0, 0);
      ellipse(0, 0, hitboxRadius * 2, hitboxRadius * 2);
    }
    
    popMatrix();
  }
  
  void displayHealthBar() {
    float healthBarWidth = size;
    float healthBarHeight = 5;
    float healthPercentage = (float)health / maxHealth;
    
    stroke(0);
    fill(255, 0, 0);
    rect(-healthBarWidth/2, -size/2 - 10, healthBarWidth, healthBarHeight);
    fill(0, 255, 0);
    rect(-healthBarWidth/2, -size/2 - 10, healthBarWidth * healthPercentage, healthBarHeight);
  }
  
  void takeDamage(int amount) {
    health -= amount;
    if (health <= 0) {
      die();
    }
  }
  
  void die() {
    alive = false;
    // Send OSC message for death sound
    oscP5.send(new OscMessage("/" + type + "/death"), new NetAddress("127.0.0.1", 57120));
  }
  
  boolean checkCollision(PVector point, float radius) {
    return PVector.dist(position, point) < (hitboxRadius + radius);
  }
  
  boolean isAlive() {
    return alive;
  }
}
