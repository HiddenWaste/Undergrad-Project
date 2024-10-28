# P. I. M. P

Hello! This is my project in which I am building a (name may change) Programmable Instrument for Multi-Modal Performance, or PIMP for short.

This uses SuperCollider for audio synthesis, Processing4 for the visuals, Arduino for control input, and then Python as a communicator between everything.

## SuperCollider Portion

--- Needs Much Development ---


## Processing Portion

I'm Imagining to have 3 Different Sketches that I'll need to figure out how to switch between from the Arduino, but thats a later bridge!

1. Spellsinger Mode

This is more of a fun gimmic I wanted to do, certain samples will cast certain spells
-> Hats trigger Fireballs
-> Kicks trigger Thunderbolts

-> (NI) Magic Missiles for various glitch sounds?

I'm wanting this to be very fun with making breakcore type music.

2. (NI) Audio Reactive Multitude

-> This processing sketch would have multiple modes within itself

I'm thinking one minimal with a simple frequency reaction, one dreamy/vhs/colorful one, and a third.

3. -- NO CONCRETE IDEA YET --

## Data and Communication

Python is the controlling brain in this, not so much the arduino. Python is what reads the arduino data and then creates and sends OSC data based on that. 

I have a feeling that this is where I will see the main bottleneck for getting this to keep expanding. Trying to figure out the logic and button mapping in
python to get from the Arduino input to my desired output.


## Interactivity and Control Points

Right now, one button that triggers a synth and makes a fireball