import gifAnimation.*;

Gif animation;
ArrayList<PVector> positions;
float scrollSpeed = 4; // Adjust this to change scroll speed
int numCols; // Store the number of columns as a global variable

void setup() {
  size(1000, 800);  // You can adjust this to match your screen size
  
  // Load the animated GIF
  animation = new Gif(this, "C:\\Users\\carte\\Pictures\\gif-test.gif");
  animation.play();
  
  // Initialize the positions ArrayList
  positions = new ArrayList<PVector>();
  
  // Wait a brief moment for the GIF to load and get its dimensions
  delay(100);
  
  // Calculate how many copies we need horizontally and vertically
  // Add extra row above and below for smooth scrolling
  numCols = ceil(width / (float)animation.width);
  int numRows = ceil(height / (float)animation.height) + 2;
  
  // Create initial positions for all GIFs
  for (int row = -1; row < numRows - 1; row++) {
    for (int col = 0; col < numCols; col++) {
      positions.add(new PVector(col * animation.width, row * animation.height));
    }
  }
}

void draw() {
  background(#E97CF0);  // Pink background
  
  // Update positions and draw all GIFs
  for (int i = 0; i < positions.size(); i++) {
    PVector pos = positions.get(i);
    
    // Move down
    pos.y += scrollSpeed;
    
    // If GIF has moved completely below the screen, wrap it to the top
    if (pos.y > height) {
      // Calculate the column number for this position
      int col = floor(pos.x / animation.width);
      
      // Find the highest position for GIFs in the same column
      float minY = height;
      for (PVector p : positions) {
        if (floor(p.x / animation.width) == col) {
          minY = min(minY, p.y);
        }
      }
      
      // Place this GIF above the highest one in its column
      pos.y = minY - animation.height;
      
      // Ensure x position stays exactly aligned with grid
      pos.x = col * animation.width;
    }
    
    // Draw the animated GIF
    image(animation, pos.x, pos.y);
  }
}
