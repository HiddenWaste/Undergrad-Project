// Wizard.pde
class Wizard {
  PVector position;
  
  Wizard(float x, float y) {
    position = new PVector(x, y);
  }
  
  void update() {
    // Map expanded range to full screen height
    float targetY = map(gameState.potWizardY, -1, 2, 0, height);
    position.y = constrain(targetY, 20, height - 20); // Light padding to keep sprite visible
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
