// Wizard.pde
class Wizard {
  PVector position;
  
  Wizard(float x, float y) {
    position = new PVector(x, y);
  }
  
  void update() {
    float targetY = map(gameState.potWizardY, -1, 2, 0, height);
    position.y = constrain(targetY, 20, height - 20); // Light padding to keep sprite visible
  }
  
  void display() {
  pushMatrix();
  translate(position.x, position.y);
  scale(-1, 1);
  
  if (wizardImg != null) {
    // Add a visual effect when power mode is active
    if (gameState.powerModeActive) {
      // Add a glowing effect around the wizard
      noStroke();
      fill(255, 150, 0, 150); // Orange glow
      ellipse(0, 0, 250, 250); // Larger than the wizard image
      
      // Could change to a different image here when available
      // For now, just change the tint
      tint(255, 220, 100); // Yellow tint
    }
    
    image(wizardImg, 0, 0);
    noTint(); // Reset tint
  } else {
    // Fallback shape
    fill(100);
    if (gameState.powerModeActive) {
      fill(255, 150, 0); // Orange for power mode
    }
    noStroke();
    ellipse(0, 0, 50, 100);
  }
}
