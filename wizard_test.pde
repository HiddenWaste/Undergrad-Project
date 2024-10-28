/*

  This program is for emulating Wizard behavior ^_^
  We have a wizard that appears to  produce Fireballs and Thunderbolts.
  
  Once this is more defined, we will eventually test triggering Firbolts
  and thunderbolts rather than a continuous stream of them!
  
  Final vision is a much cooler looking app that I can trigger Fireballs and
  Thunderbolts from SuperCollider based on OSC Messaging (Most likely x instrument
  triggers y spell)
  
  Many interesting routes this could go.
  
  Notes on SuperCollider Interaction:
      Use OSC, theres a way to transmit data like frequency and amp
      -> Trigger spells based on gates from specific instruments?
         -> Kick = Thunderbolt Hat = Fireball
       Breakcore will be insanely cool!
*/


// Wizard Location
int nFire = 15;
int wx = width/8;
int wy = height + 80;

// Class to handle Wizard data
class Wizard {
  PImage wizard;
  float wx, wy;
  
  Wizard(float xPos, float yPos) {
     wx = xPos;
     wy = yPos;
     wizard = loadImage("wizard.png");
  }
  
  void display() {
    pushMatrix(); // Save current transformation matrix
    translate(wx + wizard.width/2, wy + wizard.height/2); // Translate to center of wizard image
    scale(-1, 1); // Flip horizontally
    image(wizard, wx, wy, wizard.width/4, wizard.height/4); // Draw image
    popMatrix(); // Restore previous transformation matrix
  }
}

class Fireball {
  float x, y; // coordinates
  float speedX, speedY; // Velocity (speed and direction)
  PImage fireball = loadImage("Fireball.png");
  float sx, sy;
  
  Fireball(float xPos, float yPos) {
     x = xPos;
     y = yPos;
     sx = x;
     sy = y;
     speedX = random(4, 16);
     speedY = random(-16, 4);
  }
  
  void reset() {
     x = sx;
     y = sy;
  }
  
  void update() {
   x += speedX;
   y += speedY;
   
   if (x > width || x < 0 || y > height || y < 0) {
      reset(); // Reset if fireball goes off screen
    }
    
  }
  
  void display() {
    // Calculate the bottom left corner coordinates
    float bottomLeftX = x;
    float bottomLeftY = y + fireball.height; // Assuming fireball.height is the height of your fireball image
  
    // Draw the image flipped vertically
    pushMatrix(); // Save current transformation matrix
    translate(bottomLeftX, bottomLeftY); // Translate to bottom left corner
    scale(1, -1); // Flip vertically
    image(fireball, 150, 300, 100, 100); // Draw image at the translated position
    popMatrix(); // Restore previous transformation matrix
  }
}

/*
class Thunderbolt{
   float x, y;
   float ex, ey; // Ending position
  
}


*/

// Array to create fireballs
ArrayList<Fireball> fireballs = new ArrayList<Fireball>();


void setup() {
 size(1024, 768); // Sets the size of the window, unsure what P3D does
 background(255);    // set background color
 
 // Create a loop to make many Fireballs
 for (int i = 0; i < nFire; i++) {
    fireballs.add(new Fireball(wx+100, wy+350)); 
 }
 
}

void draw() {
  background(0);
  
  Wizard w = new Wizard(wx, wy);
  w.display();
  
  // Update and display each fireball in the ArrayList
  for (Fireball f : fireballs) {
    f.update();
    f.display();
  }
}
