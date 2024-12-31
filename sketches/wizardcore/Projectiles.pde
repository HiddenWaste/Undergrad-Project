// Projectiles.pde

class Projectile {
  PVector position;
  PVector velocity;
  boolean active;
  float hitboxRadius;
  
  boolean checkCollision(FlyingGoblin goblin) {
    return goblin.checkCollision(position, hitboxRadius);
  }
}

class Fireball extends Projectile {
  float baseSize;
  float size;
  color tint;
  
  Fireball(float x, float y) {
    position = new PVector(x, y);
    float angle = random(-PI/6, PI/6);
    velocity = new PVector(cos(angle), sin(angle));
    float baseSpeed = random(15, 25);
    velocity.mult(baseSpeed);
    baseSize = random(40, 60);
    size = baseSize * gameState.potSize;
    active = true;
    tint = color(255, random(180, 255), random(0, 100));
    hitboxRadius = size * 0.4;
  }
  
  void update() {
    if (!active) return;
    
    position.add(velocity);
    velocity.y += 0.1;
    
    // Update size based on current potSize
    size = baseSize * gameState.potSize;
    hitboxRadius = size * 0.4;
    
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
    
    if (debugMode) {
      noFill();
      stroke(255, 0, 0);
      ellipse(0, 0, hitboxRadius * 2, hitboxRadius * 2);
    }
    
    popMatrix();
  }
}

class MagicMissile extends Projectile {
  float angle;
  float baseLength;
  float length;
  color missileColor;
  
  MagicMissile(float x, float y) {
    position = new PVector(x, y);
    angle = random(-PI/8, PI/8);
    velocity = new PVector(cos(angle), sin(angle));
    float baseSpeed = random(18, 28);
    velocity.mult(baseSpeed);
    baseLength = random(30, 45);
    length = baseLength * gameState.potSize;
    active = true;
    missileColor = color(random(200, 255), 100, random(200, 255));
    hitboxRadius = length * 0.25;
  }
  
  void update() {
    if (!active) return;
    
    position.add(velocity);
    
    // Gentle wave motion
    velocity.y = sin(frameCount * 0.1) * 2;
    
    // Update length based on current potSize
    length = baseLength * gameState.potSize;
    hitboxRadius = length * 0.25;
    
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
    
    if (debugMode) {
      noFill();
      stroke(255, 0, 0);
      ellipse(0, 0, hitboxRadius * 2, hitboxRadius * 2);
    }
    
    popMatrix();
  }
}
