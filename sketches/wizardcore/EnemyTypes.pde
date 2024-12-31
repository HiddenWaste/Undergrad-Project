// EnemyTypes.pde

class FlyingGoblin extends Enemy {
  float bobTimer;
  
  FlyingGoblin(float x, float y) {
    super(x, y, "flying-goblin", 3, 60, 1.0);
    hitboxRadius = size * 0.4;
    bobTimer = random(TWO_PI);
  }
  
  void setupMovement(float speed) {
    velocity = new PVector(-speed, 0);
  }
  
  void updateMovement() {
    position.add(velocity);
    bobTimer += 0.05;
    position.y += sin(bobTimer) * 0.5;
  }
}

class RedDragon extends Enemy {
  float phaseTimer;
  float verticalSpeed;
  
  RedDragon(float x, float y) {
    super(x, y, "red-dragon", 50, 120, 0.5);
    hitboxRadius = size * 0.6;
    phaseTimer = random(TWO_PI);
    verticalSpeed = 0.3;
  }
  
  void setupMovement(float speed) {
    velocity = new PVector(-speed, 0);
  }
  
  void updateMovement() {
    position.add(velocity);
    // Slow sinusoidal vertical movement
    phaseTimer += 0.02;
    position.y += sin(phaseTimer) * verticalSpeed;
  }
}

class BatSwarm extends Enemy {
  float spreadFactor;
  float swarmAngle;
  
  BatSwarm(float x, float y) {
    super(x, y, "bat-swarm", 5, 80, 1.5);
    hitboxRadius = size * 0.5;
    spreadFactor = random(20, 30);
    swarmAngle = 0;
  }
  
  void setupMovement(float speed) {
    velocity = new PVector(-speed, 0);
  }
  
  void updateMovement() {
    position.add(velocity);
    // Create swarm-like movement pattern
    swarmAngle += 0.1;
    position.y += sin(swarmAngle) * spreadFactor * 0.1;
    position.x += cos(swarmAngle * 0.5) * spreadFactor * 0.05;
  }
}
